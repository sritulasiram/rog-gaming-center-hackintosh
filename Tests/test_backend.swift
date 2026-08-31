import Foundation
import IOKit
import IOKit.hid

print("==========================================================")
print("  ROG Gaming Center - Backend & Hardware Test Suite       ")
print("==========================================================")

var passedCount = 0
var failedCount = 0

func assertTest(_ name: String, _ condition: Bool, _ details: String = "") {
    if condition {
        print("  ✅ [PASS] \(name)")
        passedCount += 1
    } else {
        print("  ❌ [FAIL] \(name) \(details.isEmpty ? "" : "- " + details)")
        failedCount += 1
    }
}

// -----------------------------------------------------------------------------
// TEST POINT 1: IOKit HID Device Discovery & Topology Inspection
// -----------------------------------------------------------------------------
print("\n[Test Point 1: IOKit HID Discovery & Topology]")
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x0B05] as CFDictionary)
let openRes = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
assertTest("IOHIDManager Open", openRes == kIOReturnSuccess, "res = \(openRes)")

var targetDevice: IOHIDDevice?
if let devs = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devs.isEmpty {
    assertTest("ASUS Controller Enumeration", true, "Found \(devs.count) matching interface(s)")
    for dev in devs {
        let name = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "ASUS Device"
        let pid = IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let page = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let usage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        let maxFeat = IOHIDDeviceGetProperty(dev, kIOHIDMaxFeatureReportSizeKey as CFString) as? Int ?? 0
        print("    -> Interface: '\(name)' PID: 0x\(String(format: "%04X", pid)), Page: 0x\(String(format: "%04X", page)), Usage: 0x\(String(format: "%04X", usage)), MaxFeat: \(maxFeat) bytes")
        if targetDevice == nil && (page >= 0xFF00 || maxFeat >= 17) {
            targetDevice = dev
        }
    }
} else {
    assertTest("ASUS Controller Enumeration", false, "No matching ASUS devices found")
}

guard let dev = targetDevice else {
    print("\n❌ Fatal: No valid ASUS Aura HID controller found. Cannot proceed with hardware tests.")
    exit(1)
}

func sendRawPacket(_ pkt: [UInt8], delayMs: UInt32 = 10) -> IOReturn {
    var buf = pkt
    let repID = CFIndex(buf[0])
    let res = IOHIDDeviceSetReport(dev, kIOHIDReportTypeFeature, repID, &buf, buf.count)
    usleep(delayMs * 1000)
    return res
}

// -----------------------------------------------------------------------------
// TEST POINT 2: Handshake & Brightness Register
// -----------------------------------------------------------------------------
print("\n[Test Point 2: Initialization Handshake & Brightness Register]")
var handshake = [UInt8](repeating: 0, count: 17)
handshake[0] = 0x5a
for (i, b) in "ASUS Tech.Inc.".utf8.enumerated() { handshake[1+i] = b }
let hRes = sendRawPacket(handshake, delayMs: 20)
assertTest("Handshake ('ASUS Tech.Inc.')", hRes == kIOReturnSuccess, "res = \(hRes)")

var brPkt = [UInt8](repeating: 0, count: 17)
brPkt[0] = 0x5a; brPkt[1] = 0xba; brPkt[2] = 0xc5; brPkt[3] = 0xc4; brPkt[4] = 0x03
let brRes = sendRawPacket(brPkt, delayMs: 10)
assertTest("Brightness Register (Level 3 / 100%)", brRes == kIOReturnSuccess, "res = \(brRes)")

// -----------------------------------------------------------------------------
// TEST POINT 3: RGB Static Color & Commit Latch
// -----------------------------------------------------------------------------
print("\n[Test Point 3: RGB Color Payload & Latch Commits]")
var redPkt = [UInt8](repeating: 0, count: 17)
redPkt[0] = 0x5d; redPkt[1] = 0xb3; redPkt[2] = 0x00; redPkt[3] = 0x00
redPkt[4] = 0xff; redPkt[5] = 0x00; redPkt[6] = 0x33; redPkt[7] = 0xeb
let redRes = sendRawPacket(redPkt, delayMs: 10)
assertTest("Zone 0 (All) Static RGB Payload", redRes == kIOReturnSuccess, "res = \(redRes)")

var setPkt = [UInt8](repeating: 0, count: 17)
setPkt[0] = 0x5d; setPkt[1] = 0xb5
let setRes = sendRawPacket(setPkt, delayMs: 15)
assertTest("Hardware SET Commit (0x5D 0xB5)", setRes == kIOReturnSuccess, "res = \(setRes)")

var applyPkt = [UInt8](repeating: 0, count: 17)
applyPkt[0] = 0x5d; applyPkt[1] = 0xb4
let applyRes = sendRawPacket(applyPkt, delayMs: 20)
assertTest("Hardware APPLY Latch (0x5D 0xB4)", applyRes == kIOReturnSuccess, "res = \(applyRes)")

// -----------------------------------------------------------------------------
// TEST POINT 4: Dynamic Animation Modes (Spectrum & Breathing)
// -----------------------------------------------------------------------------
print("\n[Test Point 4: Dynamic Animation Hardware Dispatch]")
var cyclePkt = [UInt8](repeating: 0, count: 17)
cyclePkt[0] = 0x5d; cyclePkt[1] = 0xb3; cyclePkt[2] = 0x00; cyclePkt[3] = 0x02
cyclePkt[4] = 0xff; cyclePkt[7] = 0xeb
let cycleRes = sendRawPacket(cyclePkt, delayMs: 10)
_ = sendRawPacket(setPkt, delayMs: 15)
_ = sendRawPacket(applyPkt, delayMs: 20)
assertTest("Spectrum Color Cycle Mode (0x02)", cycleRes == kIOReturnSuccess, "res = \(cycleRes)")

// -----------------------------------------------------------------------------
// TEST POINT 5: Telemetry Subsystem Verification
// -----------------------------------------------------------------------------
print("\n[Test Point 5: Telemetry Engine Verification]")
var bootTime = timeval()
var size = MemoryLayout<timeval>.size
var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
let uptimeRes = sysctl(&mib, 2, &bootTime, &size, nil, 0)
assertTest("Host Kernel Telemetry (sysctl)", uptimeRes == 0)

print("\n----------------------------------------------------------")
print("  Test Results: \(passedCount) Passed, \(failedCount) Failed")
print("==========================================================\n")

if failedCount > 0 {
    exit(1)
}
