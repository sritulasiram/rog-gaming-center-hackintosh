import Foundation
import Cocoa
import IOKit.ps
import ServiceManagement

public enum ROGKeyAction: String, CaseIterable, Identifiable, Codable {
    case toggleMainWindow = "toggle_main_window"
    case togglePopover = "toggle_popover"
    case cyclePresets = "cycle_presets"
    case toggleBacklightPower = "toggle_backlight_power"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .toggleMainWindow: return "Toggle Main Window (Show / Hide)"
        case .togglePopover: return "Toggle Menu Bar HUD Popover"
        case .cyclePresets: return "Cycle Aura RGB Presets"
        case .toggleBacklightPower: return "Toggle Backlight (On / Off)"
        }
    }

    public var icon: String {
        switch self {
        case .toggleMainWindow: return "macwindow"
        case .togglePopover: return "menubar.arrow.down.rectangle"
        case .cyclePresets: return "sparkles"
        case .toggleBacklightPower: return "power"
        }
    }
}

public struct WatchdogAuditEvent: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: Date
    public let icon: String
    public let iconColor: String
    public let title: String
    public let detail: String

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

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
    @Published public var isROGKeyEnabled: Bool = true
    @Published public var rogKeyAction: ROGKeyAction = .toggleMainWindow
    @Published public var lastROGKeyPressTime: String? = nil
    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = "ASUS ROG Keyboard"
    @Published public var statusMessage: String = "● Connecting..."
    /// True when macOS's Input Monitoring privacy check is blocking HID access.
    /// This is what actually distinguishes "app not working" from "keyboard unplugged".
    @Published public var permissionDenied: Bool = false
    @Published public var lastResyncTime: String = "Never"
    @Published public var isPoweredOn: Bool = true
    @Published public var activeEditingZoneIndex: Int = 0 // 0 = Zone 1 (WASD), 1 = Zone 2, etc.
    @Published public var watchdogAuditLog: [WatchdogAuditEvent] = []

    public var onROGKeyActionTriggered: ((ROGKeyAction) -> Void)?

    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var sleepWakeDebounceTimer: Timer?
    private var globalHotKeyMonitor: Any?
    private var localHotKeyMonitor: Any?

    private init() {
        loadSettings()
        setupDriverObservers()
        setupSystemWakeObservers()
        setupPowerSourceMonitoring()
        setupGlobalHotkeys()

        logWatchdogEvent(
            icon: "bolt.fill",
            iconColor: "blue",
            title: "AuraService Online",
            detail: "IOKit USB HID matching registered. Watchdog daemon active."
        )

        // Initial device scan & wake handshake
        driver.refreshDevices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.driver.initializeKeyboard { _ in
                self?.reapplyCurrentLighting()
            }
        }
    }

    deinit {
        if let m = globalHotKeyMonitor { NSEvent.removeMonitor(m) }
        if let m = localHotKeyMonitor { NSEvent.removeMonitor(m) }
    }

    public func logWatchdogEvent(icon: String, iconColor: String, title: String, detail: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let event = WatchdogAuditEvent(
                timestamp: Date(),
                icon: icon,
                iconColor: iconColor,
                title: title,
                detail: detail
            )
            self.watchdogAuditLog.append(event)
            if self.watchdogAuditLog.count > 40 {
                self.watchdogAuditLog.removeFirst()
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

        driver.onROGKeyPressed = { [weak self] in
            guard let self = self, self.isROGKeyEnabled else { return }
            let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            DispatchQueue.main.async {
                self.lastROGKeyPressTime = now
                self.handleROGKeyTrigger()
            }
        }
    }

    // MARK: - Dedicated Hardware ROG Key Dispatcher

    public func handleROGKeyTrigger() {
        NSLog("[ROGAuraService] 🕹️ Executing ROG Key Action: \(rogKeyAction.rawValue)")
        switch rogKeyAction {
        case .toggleMainWindow, .togglePopover:
            onROGKeyActionTriggered?(rogKeyAction)
        case .cyclePresets:
            cycleToNextPreset()
        case .toggleBacklightPower:
            togglePower()
        }
    }

    public func cycleToNextPreset() {
        let all = AuraPreset.builtInPresets
        guard !all.isEmpty else { return }
        if let idx = all.firstIndex(where: { $0.id == activePresetId }) {
            let nextIdx = (idx + 1) % all.count
            applyPreset(all[nextIdx])
            HUDService.shared.showAuraModeHUD(modeName: all[nextIdx].name)
        } else {
            applyPreset(all[0])
            HUDService.shared.showAuraModeHUD(modeName: all[0].name)
        }
    }

    public func cycleToPreviousPreset() {
        let all = AuraPreset.builtInPresets
        guard !all.isEmpty else { return }
        if let idx = all.firstIndex(where: { $0.id == activePresetId }) {
            let prevIdx = (idx - 1 + all.count) % all.count
            applyPreset(all[prevIdx])
            HUDService.shared.showAuraModeHUD(modeName: all[prevIdx].name)
        } else {
            applyPreset(all[0])
            HUDService.shared.showAuraModeHUD(modeName: all[0].name)
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
        center.addObserver(self, selector: #selector(handleSystemSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(handleScreensSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
    }

    @objc private func handleSystemSleep() {
        logWatchdogEvent(
            icon: "moon.fill",
            iconColor: "purple",
            title: "System Sleep Triggered",
            detail: "Received NSWorkspace.willSleepNotification. Suspending packet pipeline."
        )
    }

    @objc private func handleScreensSleep() {
        logWatchdogEvent(
            icon: "display",
            iconColor: "secondary",
            title: "Display Sleep Event",
            detail: "Received NSWorkspace.screensDidSleepNotification."
        )
    }

    @objc private func handleSystemWake() {
        logWatchdogEvent(
            icon: "sun.max.fill",
            iconColor: "orange",
            title: "System Wake Event",
            detail: "Received didWakeNotification. Queuing 600ms latch recovery debounce."
        )
        sleepWakeDebounceTimer?.invalidate()
        sleepWakeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.forceHardwareResync()
        }
    }

    // MARK: - Global Keyboard Hotkeys

    private func setupGlobalHotkeys() {
        globalHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        localHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    @Published public var isTouchpadEnabled: Bool = true

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags
        // Matches pure Fn held down, OR Control+Option fallback
        let isFn = flags.contains(.function) || flags.intersection(.deviceIndependentFlagsMask).contains([.control, .option])
        guard isFn else { return false }

        switch event.keyCode {
        case 126, 116: // Up Arrow or Page Up -> Brightness Up
            DispatchQueue.main.async { [weak self] in self?.stepBrightnessUp() }
            return true

        case 125, 121: // Down Arrow or Page Down -> Brightness Down
            DispatchQueue.main.async { [weak self] in self?.stepBrightnessDown() }
            return true

        case 100: // F8 -> Brightness Up
            DispatchQueue.main.async { [weak self] in self?.stepBrightnessUp() }
            return true

        case 98: // F7 -> Brightness Down
            DispatchQueue.main.async { [weak self] in self?.stepBrightnessDown() }
            return true

        case 124, 119: // Right Arrow or End -> Next Aura Mode
            DispatchQueue.main.async { [weak self] in self?.cycleToNextPreset() }
            return true

        case 123, 115: // Left Arrow or Home -> Previous Aura Mode
            DispatchQueue.main.async { [weak self] in self?.cycleToPreviousPreset() }
            return true

        case 49: // Space -> Power Toggle
            DispatchQueue.main.async { [weak self] in self?.togglePower() }
            return true

        case 97: // F6 -> Touchpad Toggle
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isTouchpadEnabled.toggle()
                HUDService.shared.showTouchpadHUD(isEnabled: self.isTouchpadEnabled)
            }
            return true

        case 122: // F1 -> Audio Mute
            DispatchQueue.main.async {
                let script = "set volume output muted (not (output muted of (get volume settings)))"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
                let checkScript = "output muted of (get volume settings)"
                let isMuted = NSAppleScript(source: checkScript)?.executeAndReturnError(nil).booleanValue ?? true
                HUDService.shared.showVolumeHUD(percent: 0, isMuted: isMuted)
            }
            return true

        case 120: // F2 -> Volume Down
            DispatchQueue.main.async {
                let script = "set volume output volume ((output volume of (get volume settings)) - 6)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
                let checkScript = "output volume of (get volume settings)"
                let val = Int(NSAppleScript(source: checkScript)?.executeAndReturnError(nil).stringValue ?? "50") ?? 50
                HUDService.shared.showVolumeHUD(percent: val, isMuted: false)
            }
            return true

        case 99: // F3 -> Volume Up
            DispatchQueue.main.async {
                let script = "set volume output volume ((output volume of (get volume settings)) + 6)"
                NSAppleScript(source: script)?.executeAndReturnError(nil)
                let checkScript = "output volume of (get volume settings)"
                let val = Int(NSAppleScript(source: checkScript)?.executeAndReturnError(nil).stringValue ?? "50") ?? 50
                HUDService.shared.showVolumeHUD(percent: val, isMuted: false)
            }
            return true

        case 118: // F4 -> Display Brightness Down
            DispatchQueue.main.async { [weak self] in
                self?.postBrightnessKey(down: true)
            }
            return true

        case 96: // F5 -> Display Brightness Up
            DispatchQueue.main.async { [weak self] in
                self?.postBrightnessKey(down: false)
            }
            return true

        case 101: // F9 -> Lock Screen
            DispatchQueue.main.async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
                proc.arguments = ["-suspend"]
                try? proc.run()
                HUDService.shared.showMessage(icon: "lock.fill", text: "Screen Locked", color: .blue)
            }
            return true

        case 103: // F11 -> System Sleep
            DispatchQueue.main.async {
                NSAppleScript(source: "tell application \"System Events\" to sleep")?.executeAndReturnError(nil)
            }
            return true

        default:
            return false
        }
    }

    private func postBrightnessKey(down: Bool) {
        let key: Int32 = down ? 3 : 2
        let downEvent = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: Int((key << 16) | (0xa << 8)), data2: -1)
        let upEvent = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: Int((key << 16) | (0xb << 8)), data2: -1)
        downEvent?.cgEvent?.post(tap: .cghidEventTap)
        upEvent?.cgEvent?.post(tap: .cghidEventTap)
    }

    public func stepBrightnessDown() {
        let newLevel = max(0, currentBrightness - 1)
        setBrightness(newLevel)
        HUDService.shared.showBacklightHUD(level: newLevel)
    }

    public func stepBrightnessUp() {
        let newLevel = min(3, currentBrightness + 1)
        setBrightness(newLevel)
        HUDService.shared.showBacklightHUD(level: newLevel)
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
        driver.initializeKeyboard { [weak self] success in
            guard let self = self else { return }
            self.reapplyCurrentLighting()
            DispatchQueue.main.async {
                let timeStr = Date().formatted(date: .omitted, time: .standard)
                self.lastResyncTime = timeStr
                self.statusMessage = "● Handshake Re-Synced (\(timeStr))"
                self.logWatchdogEvent(
                    icon: "arrow.clockwise.circle.fill",
                    iconColor: success ? "green" : "red",
                    title: success ? "ITE 8910 Handshake Latched" : "Handshake Failed",
                    detail: success ? "Handshake 'ASUS Tech.Inc.' acknowledged. Active mode restored." : "No response from USB controller."
                )
            }
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

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return
            } catch {
                NSLog("[ROGAuraService] SMAppService error: \(error.localizedDescription), falling back to LaunchAgent plist")
            }
        }

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
        defaults.set(isROGKeyEnabled, forKey: "Aura_ROGKeyEnabled")
        defaults.set(rogKeyAction.rawValue, forKey: "Aura_ROGKeyAction")
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
        if defaults.object(forKey: "Aura_ROGKeyEnabled") != nil {
            isROGKeyEnabled = defaults.bool(forKey: "Aura_ROGKeyEnabled")
        }
        if let rawAct = defaults.string(forKey: "Aura_ROGKeyAction"), let act = ROGKeyAction(rawValue: rawAct) {
            rogKeyAction = act
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
