import Foundation
import Cocoa
import IOKit.ps

public final class AuraService: ObservableObject {
    public static let shared = AuraService()

    private let defaults = UserDefaults.standard
    private let driver = AuraDriver.shared
    public let telemetry = TelemetryService.shared

    // Published App State for SwiftUI Views
    @Published public var currentMode: AuraMode = .colorCycle(.medium)
    @Published public var currentBrightness: Int = 3
    @Published public var savedACBrightness: Int = 3
    @Published public var currentSpeed: AuraSpeed = .medium
    @Published public var activePresetId: String = "color_cycle"
    @Published public var zoneColors: [RGBColor] = [
        RGBColor(red: 255, green: 0, blue: 127),   // WASD / Left
        RGBColor(red: 128, green: 0, blue: 255),   // Center-Left
        RGBColor(red: 0, green: 255, blue: 255),   // Center-Right
        RGBColor(red: 0, green: 127, blue: 255)    // Numpad
    ]
    @Published public var customPresets: [AuraPreset] = []
    @Published public var isBatterySaverEnabled: Bool = true
    @Published public var isLaunchAtLoginEnabled: Bool = false
    @Published public var isCloseToTrayEnabled: Bool = true
    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = "ASUS ROG Keyboard"
    @Published public var statusMessage: String = "● Connecting..."
    /// True when macOS's Input Monitoring privacy check is blocking HID access.
    /// This is what actually distinguishes "app not working" from "keyboard unplugged".
    @Published public var permissionDenied: Bool = false
    @Published public var lastResyncTime: String = "Never"
    @Published public var isPoweredOn: Bool = true
    @Published public var activeEditingZoneIndex: Int = 0 // 0 = Zone 1 (WASD), 1 = Zone 2, etc.

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var sleepWakeDebounceTimer: Timer?

    private init() {
        loadSettings()
        setupDriverObservers()
        setupSystemWakeObservers()
        setupPowerSourceMonitoring()

        // Initial device scan & wake handshake
        driver.refreshDevices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.driver.initializeKeyboard { _ in
                self?.reapplyCurrentLighting()
            }
        }
    }

    // MARK: - Driver Callbacks

    private func setupDriverObservers() {
        driver.onDeviceStateChanged = { [weak self] isConnected, info in
            guard let self = self else { return }
            self.isConnected = isConnected
            if self.permissionDenied {
                // Don't let a device-enumeration update stomp on the permission banner —
                // the device can enumerate fine while writes are still blocked.
                return
            }
            if isConnected, let info = info {
                self.deviceName = "\(info.name) (\(info.formattedPID))"
                self.statusMessage = "● Connected (\(info.transport))"
            } else {
                self.deviceName = "ASUS ROG Keyboard"
                self.statusMessage = "○ Controller Disconnected"
            }
        }

        driver.onPermissionStatusChanged = { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .denied:
                self.permissionDenied = true
                self.statusMessage = "⚠️ Blocked by macOS — grant Input Monitoring access"
            case .authorized:
                self.permissionDenied = false
            case .unknown:
                break
            }
        }
    }

    /// Opens System Settings directly to the Input Monitoring pane so the user
    /// can add/enable ROG Gaming Center without hunting for it.
    public func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - System Lifecycle (Sleep & Wake Auto-Watchdog)

    private func setupSystemWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(handleSystemWake), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleSystemWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleSystemWake), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func handleSystemWake() {
        sleepWakeDebounceTimer?.invalidate()
        sleepWakeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.forceHardwareResync()
        }
    }

    // MARK: - Native Power Source (Battery Saver Auto-Dimming)

    private func setupPowerSourceMonitoring() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        powerSourceRunLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let service = Unmanaged<AuraService>.fromOpaque(context).takeUnretainedValue()
            service.checkPowerSourceState()
        }, context)?.takeRetainedValue()

        if let source = powerSourceRunLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        checkPowerSourceState()
    }

    private func checkPowerSourceState() {
        guard isBatterySaverEnabled else { return }

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() else {
            return
        }

        let count = CFArrayGetCount(sources)
        var isRunningOnBattery = false

        for i in 0..<count {
            guard let source = CFArrayGetValueAtIndex(sources, i) else { continue }
            let sourceRef = unsafeBitCast(source, to: CFTypeRef.self)
            guard let desc = IOPSGetPowerSourceDescription(snapshot, sourceRef)?.takeUnretainedValue() as NSDictionary? else { continue }

            if let state = desc[kIOPSPowerSourceStateKey as String] as? String, state == kIOPSBatteryPowerValue {
                isRunningOnBattery = true
                break
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if isRunningOnBattery && self.currentBrightness > 1 {
                self.savedACBrightness = self.currentBrightness
                self.setBrightness(1) // Auto-dim to 33% on battery
            } else if !isRunningOnBattery && self.currentBrightness == 1 && self.savedACBrightness > 1 {
                self.setBrightness(self.savedACBrightness) // Restore AC level
            }
        }
    }

    // MARK: - Public Lighting Controls

    public func reapplyCurrentLighting() {
        if !isPoweredOn {
            driver.turnOff()
        } else {
            driver.applyMode(currentMode, brightness: currentBrightness)
        }
    }

    public func togglePower() {
        isPoweredOn.toggle()
        if !isPoweredOn {
            driver.turnOff()
        } else {
            if currentBrightness == 0 { currentBrightness = 3 }
            reapplyCurrentLighting()
        }
        saveSettings()
    }

    public func setBrightness(_ level: Int) {
        let clamped = max(0, min(3, level))
        currentBrightness = clamped
        if clamped == 0 {
            isPoweredOn = false
            driver.turnOff()
        } else {
            isPoweredOn = true
            savedACBrightness = clamped
            reapplyCurrentLighting()
        }
        saveSettings()
    }

    public func setSpeed(_ speed: AuraSpeed) {
        currentSpeed = speed
        switch currentMode {
        case .colorCycle:
            currentMode = .colorCycle(speed)
        case .rainbow:
            currentMode = .rainbow(speed)
        case .singleBreathing(let c1, let c2, _):
            currentMode = .singleBreathing(c1, c2, speed)
        case .multiBreathing(let zones, _):
            currentMode = .multiBreathing(zones, speed)
        case .strobing(let col, _):
            currentMode = .strobing(col, speed)
        default:
            break
        }
        if isPoweredOn {
            reapplyCurrentLighting()
        }
        saveSettings()
    }

    public func applyPreset(_ preset: AuraPreset) {
        activePresetId = preset.id
        isPoweredOn = true
        if currentBrightness == 0 { currentBrightness = 3 }

        // If preset defines speed, update currentSpeed
        switch preset.mode {
        case .colorCycle(let sp), .rainbow(let sp), .singleBreathing(_, _, let sp), .multiBreathing(_, let sp), .strobing(_, let sp):
            currentSpeed = sp
        case .multiStatic(let zones):
            if zones.count == 4 {
                self.zoneColors = zones
            }
        default:
            break
        }

        currentMode = preset.mode
        reapplyCurrentLighting()
        saveSettings()
    }

    public func applySingleColor(_ color: RGBColor) {
        activePresetId = "custom_single"
        isPoweredOn = true
        if currentBrightness == 0 { currentBrightness = 3 }
        currentMode = .singleStatic(color)
        zoneColors = [color, color, color, color]
        reapplyCurrentLighting()
        saveSettings()
    }

    public func setZoneColor(zoneIndex: Int, color: RGBColor) {
        guard (0..<4).contains(zoneIndex) else { return }
        zoneColors[zoneIndex] = color
        activePresetId = "custom_4zone"
        isPoweredOn = true
        if currentBrightness == 0 { currentBrightness = 3 }
        currentMode = .multiStatic(zoneColors)
        reapplyCurrentLighting()
        saveSettings()
    }

    public func forceHardwareResync() {
        driver.initializeKeyboard { [weak self] _ in
            guard let self = self else { return }
            self.reapplyCurrentLighting()
            DispatchQueue.main.async {
                let timeStr = Date().formatted(date: .omitted, time: .standard)
                self.lastResyncTime = timeStr
                self.statusMessage = "● Handshake Re-Synced (\(timeStr))"
            }
        }
    }

    public func applyPerformanceProfile(_ profile: ROGPerformanceProfile) {
        switch profile {
        case .silent:
            setBrightness(1)
        case .balanced:
            setBrightness(2)
        case .turbo:
            setBrightness(3)
        }
    }

    // MARK: - Custom Preset Management

    public func saveCustomPreset(name: String, icon: String = "paintpalette.fill") {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "Custom \(customPresets.count + 1)" : cleanName
        let newPreset = AuraPreset(
            id: UUID().uuidString,
            name: finalName,
            icon: icon,
            mode: .multiStatic(zoneColors),
            previewColors: zoneColors,
            isCustom: true
        )
        customPresets.append(newPreset)
        activePresetId = newPreset.id
        saveSettings()
    }

    public func deleteCustomPreset(id: String) {
        customPresets.removeAll { $0.id == id }
        if activePresetId == id {
            activePresetId = "color_cycle"
            if let defaultPreset = AuraPreset.builtInPresets.first {
                applyPreset(defaultPreset)
            }
        }
        saveSettings()
    }

    // MARK: - Launch at Login (LaunchAgent)

    public func setLaunchAtLogin(enabled: Bool) {
        isLaunchAtLoginEnabled = enabled
        saveSettings()

        let appPath = Bundle.main.bundlePath
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.asus.roggamingcenter.plist")

        if enabled {
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.asus.roggamingcenter</string>
                <key>ProgramArguments</key>
                <array>
                    <string>/usr/bin/open</string>
                    <string>-a</string>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>ProcessType</key>
                <string>Interactive</string>
            </dict>
            </plist>
            """
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? plistContent.write(to: plistURL, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: plistURL)
        }
    }

    // MARK: - Settings Persistence

    public func saveSettings() {
        defaults.set(currentBrightness, forKey: "Aura_Brightness")
        defaults.set(savedACBrightness, forKey: "Aura_SavedACBrightness")
        defaults.set(currentSpeed.rawValue, forKey: "Aura_Speed")
        defaults.set(activePresetId, forKey: "Aura_ActivePresetId")
        defaults.set(isBatterySaverEnabled, forKey: "Aura_BatterySaver")
        defaults.set(isLaunchAtLoginEnabled, forKey: "Aura_LaunchAtLogin")
        defaults.set(isCloseToTrayEnabled, forKey: "Aura_CloseToTray")
        defaults.set(isPoweredOn, forKey: "Aura_IsPoweredOn")

        // Save Zone Colors
        let zHexStrings = zoneColors.map { $0.hexString }
        defaults.set(zHexStrings, forKey: "Aura_ZoneColors")

        // Save Custom Presets
        if let encoded = try? JSONEncoder().encode(customPresets) {
            defaults.set(encoded, forKey: "Aura_CustomPresets")
        }
    }

    private func loadSettings() {
        if defaults.object(forKey: "Aura_Brightness") != nil {
            currentBrightness = defaults.integer(forKey: "Aura_Brightness")
        }
        if defaults.object(forKey: "Aura_SavedACBrightness") != nil {
            savedACBrightness = defaults.integer(forKey: "Aura_SavedACBrightness")
        }
        if let spVal = defaults.object(forKey: "Aura_Speed") as? Int, let sp = AuraSpeed(rawValue: spVal) {
            currentSpeed = sp
        }
        if let presetId = defaults.string(forKey: "Aura_ActivePresetId") {
            activePresetId = presetId
        }
        if defaults.object(forKey: "Aura_BatterySaver") != nil {
            isBatterySaverEnabled = defaults.bool(forKey: "Aura_BatterySaver")
        }
        if defaults.object(forKey: "Aura_LaunchAtLogin") != nil {
            isLaunchAtLoginEnabled = defaults.bool(forKey: "Aura_LaunchAtLogin")
        }
        if defaults.object(forKey: "Aura_CloseToTray") != nil {
            isCloseToTrayEnabled = defaults.bool(forKey: "Aura_CloseToTray")
        }
        if defaults.object(forKey: "Aura_IsPoweredOn") != nil {
            isPoweredOn = defaults.bool(forKey: "Aura_IsPoweredOn")
        }

        if let zHex = defaults.stringArray(forKey: "Aura_ZoneColors"), zHex.count == 4 {
            let parsed = zHex.compactMap { RGBColor(hex: $0) }
            if parsed.count == 4 {
                self.zoneColors = parsed
            }
        }

        if let data = defaults.data(forKey: "Aura_CustomPresets"),
           let decoded = try? JSONDecoder().decode([AuraPreset].self, from: data) {
            self.customPresets = decoded
        }

        // Match initial mode from active preset
        let allPresets = AuraPreset.builtInPresets + customPresets
        if let matched = allPresets.first(where: { $0.id == activePresetId }) {
            currentMode = matched.mode
        } else if activePresetId == "custom_4zone" {
            currentMode = .multiStatic(zoneColors)
        } else if activePresetId == "custom_single" {
            currentMode = .singleStatic(zoneColors.first ?? .white)
        }
    }
}
