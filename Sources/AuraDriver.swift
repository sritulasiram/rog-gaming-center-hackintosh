import Foundation
import IOKit
import IOKit.hid

public struct AuraDeviceInfo: Equatable {
    public let name: String
    public let vendorID: Int
    public let productID: Int
    public let serialNumber: String?
    public let transport: String
    public let usagePage: Int
    public let usage: Int

    public var formattedVID: String { String(format: "0x%04X", vendorID) }
    public var formattedPID: String { String(format: "0x%04X", productID) }

    public var summary: String {
        return "\(name) (\(formattedPID))"
    }
}

/// Authorization state of the process's IOHIDManager session.
/// macOS gates HID device access (including vendor feature-report writes to
/// keyboard-class devices) behind the "Input Monitoring" TCC privacy check.
/// A CLI launched from Terminal inherits Terminal's grant; a standalone,
/// unsigned .app bundle has its own, separate, and usually *ungranted* identity.
public enum AuraPermissionStatus {
    case unknown
    case authorized
    case denied
}

public final class AuraDriver {
    public static let shared = AuraDriver()

    public static let ASUS_VENDOR_ID: Int = 0x0B05
    public static let KNOWN_PRODUCT_IDS: Set<Int> = [
        0x1869, // GL503, GL703, FX503
        0x1854, // GL553, GL753
        0x1866, // GL504, GX501, GM501
        0x19B6, // GA503, G533, G733
        0x184A, 0x1837, 0x1822, 0x18CF, 0x18C6, 0x1A30
    ]

    private let queue = DispatchQueue(label: "com.asus.rogauracore.driver", qos: .userInitiated)
    private var hidManager: IOHIDManager?

    public var onDeviceStateChanged: ((Bool, AuraDeviceInfo?) -> Void)?

    /// Fires whenever the app's ability to actually talk to the HID device changes.
    /// This is the signal the UI should use to tell "device unplugged" apart from
    /// "device present but macOS is blocking us" — the two look identical if you
    /// only watch `isConnected`.
    public var onPermissionStatusChanged: ((AuraPermissionStatus) -> Void)?
    public private(set) var permissionStatus: AuraPermissionStatus = .unknown

    private init() {
        setupHIDManager()
    }

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = hidManager else { return }

        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey: Self.ASUS_VENDOR_ID
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let driver = Unmanaged<AuraDriver>.fromOpaque(context).takeUnretainedValue()
            driver.notifyDeviceChange()
        }

        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let driver = Unmanaged<AuraDriver>.fromOpaque(context).takeUnretainedValue()
            driver.notifyDeviceChange()
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, matchingCallback, selfPtr)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removalCallback, selfPtr)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // THE FIX: this return code was previously discarded (`_ = ...`).
        // kIOReturnNotPermitted here means macOS refused to hand this process
        // HID access at all — every subsequent SetReport will silently no-op.
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        updatePermissionStatus(from: openResult)
    }

    private func updatePermissionStatus(from ioReturn: IOReturn) {
        let newStatus: AuraPermissionStatus
        switch ioReturn {
        case kIOReturnSuccess:
            newStatus = .authorized
        case kIOReturnNotPermitted, kIOReturnExclusiveAccess:
            newStatus = .denied
        default:
            newStatus = .unknown
        }
        guard newStatus != permissionStatus else { return }
        permissionStatus = newStatus
        DispatchQueue.main.async { [weak self] in
            self?.onPermissionStatusChanged?(newStatus)
        }
    }

    public var isConnected: Bool {
        return !getMatchingDevices().isEmpty
    }

    public var connectedDeviceInfo: AuraDeviceInfo? {
        if let dev = getMatchingDevices().first {
            let name = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "ASUS ROG Keyboard"
            let vid = IOHIDDeviceGetProperty(dev, kIOHIDVendorIDKey as CFString) as? Int ?? Self.ASUS_VENDOR_ID
            let pid = IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int ?? 0
            let serial = IOHIDDeviceGetProperty(dev, kIOHIDSerialNumberKey as CFString) as? String
            let transport = IOHIDDeviceGetProperty(dev, kIOHIDTransportKey as CFString) as? String ?? "USB"
            let usagePage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            let usage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
            return AuraDeviceInfo(
                name: name,
                vendorID: vid,
                productID: pid,
                serialNumber: serial,
                transport: transport,
                usagePage: usagePage,
                usage: usage
            )
        }
        return nil
    }

    public func refreshDevices() {
        notifyDeviceChange()
    }

    public func notifyDeviceChange() {
        let connected = self.isConnected
        let info = self.connectedDeviceInfo
        DispatchQueue.main.async { [weak self] in
            self?.onDeviceStateChanged?(connected, info)
        }
    }

    /// Returns matching ASUS IOHIDDevice instances, prioritizing vendor-specific Aura feature interfaces
    public func getMatchingDevices() -> [IOHIDDevice] {
        guard let manager = hidManager,
              let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              !deviceSet.isEmpty else {
            return []
        }

        var candidates = [IOHIDDevice]()
        for dev in deviceSet {
            let vid = IOHIDDeviceGetProperty(dev, kIOHIDVendorIDKey as CFString) as? Int ?? 0
            let pid = IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int ?? 0
            if vid == Self.ASUS_VENDOR_ID && (Self.KNOWN_PRODUCT_IDS.contains(pid) || pid != 0) {
                candidates.append(dev)
            }
        }

        // Sort to prioritize devices with vendor-specific usage pages (e.g. 0xFF89, 0xFFA9, 0xFF00) and feature report capacity
        candidates.sort { a, b in
            let aMaxFeat = IOHIDDeviceGetProperty(a, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int ?? 0
            let bMaxFeat = IOHIDDeviceGetProperty(b, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int ?? 0
            let aPage = IOHIDDeviceGetProperty(a, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            let bPage = IOHIDDeviceGetProperty(b, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            
            let aIsVendor = (aPage >= 0xFF00)
            let bIsVendor = (bPage >= 0xFF00)

            if aIsVendor != bIsVendor { return aIsVendor }
            return aMaxFeat > bMaxFeat
        }

        return candidates
    }

    // MARK: - Transaction Dispatch Engine

    /// Sends a sequence of 17-byte HID Feature Reports with guaranteed FIFO micro-delays
    public func sendPackets(_ packets: [[UInt8]], completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            let devices = self.getMatchingDevices()
            guard !devices.isEmpty else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            var allSucceeded = true
            var sawPermissionDenial = false
            for dev in devices {
                for pkt in packets {
                    var buffer = pkt
                    let repID = CFIndex(buffer[0])
                    let res = IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, repID, &buffer, buffer.count)
                    if res != kIOReturnSuccess {
                        allSucceeded = false
                        if res == kIOReturnNotPermitted || res == kIOReturnExclusiveAccess {
                            sawPermissionDenial = true
                        }
                    }
                    // Crucial 10ms micro-delay to ensure ITE 8910 PWM register latching
                    usleep(10000)
                }
            }

            if sawPermissionDenial {
                self.updatePermissionStatus(from: kIOReturnNotPermitted)
            }

            DispatchQueue.main.async {
                completion?(allSucceeded)
            }
        }
    }

    // MARK: - High-Level Driver Commands

    /// Initializes keyboard controller handshake
    public func initializeKeyboard(completion: ((Bool) -> Void)? = nil) {
        let handshake = AuraPacketBuilder.buildHandshakePacket()
        sendPackets([handshake], completion: completion)
    }

    /// Sets hardware brightness (0-3)
    public func setBrightness(_ level: Int, completion: ((Bool) -> Void)? = nil) {
        let bPkt = AuraPacketBuilder.buildBrightnessPacket(level: level)
        sendPackets([bPkt], completion: completion)
    }

    /// Applies a lighting mode transaction (Handshake -> Brightness -> Mode -> Set -> Apply)
    public func applyMode(_ mode: AuraMode, brightness: Int = 3, completion: ((Bool) -> Void)? = nil) {
        let packets = AuraPacketBuilder.buildModeTransaction(mode: mode, brightness: brightness)
        sendPackets(packets, completion: completion)
    }

    /// Turns off lighting
    public func turnOff(completion: ((Bool) -> Void)? = nil) {
        let packets = AuraPacketBuilder.buildModeTransaction(mode: .off, brightness: 0)
        sendPackets(packets, completion: completion)
    }

    /// Full re-sync: Handshake + restore current state
    public func resync(currentMode: AuraMode, brightness: Int, completion: ((Bool) -> Void)? = nil) {
        applyMode(currentMode, brightness: brightness, completion: completion)
    }
}
