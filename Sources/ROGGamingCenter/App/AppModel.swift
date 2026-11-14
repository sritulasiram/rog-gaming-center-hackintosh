import AppKit
import Observation
import AuraCore
import AuraHID

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, lighting, display, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .lighting: return "Lighting"
        case .display: return "Display"
        case .status: return "Status"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .lighting: return "keyboard"
        case .display: return "sun.max"
        case .status: return "waveform.path.ecg"
        }
    }
}

/// Root state object: owns every controller and routes hardware events to them.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            store.save(settings)
            settingsChanged(from: oldValue)
        }
    }

    var selection: SidebarItem = .dashboard
    var isPermissionSheetPresented = false
    private(set) var device: AuraDeviceInfo?
    private(set) var hidAccess: HIDAccess
    /// Global shortcuts macOS refused to register, usually because another app owns them.
    private(set) var unavailableShortcuts: [GlobalShortcuts.Action] = []

    let lighting: LightingController
    let telemetry = TelemetryMonitor()
    let display: DisplayController
    let loginItem = LoginItemController()
    let log = ActivityLog()

    @ObservationIgnored let transport: AuraHIDTransport
    @ObservationIgnored private let store = SettingsStore()
    @ObservationIgnored private let shortcuts = GlobalShortcuts()
    @ObservationIgnored private var wakeWork: DispatchWorkItem?
    /// Set by the first SwiftUI view that can open windows.
    @ObservationIgnored var openMainWindowAction: (() -> Void)?
    @ObservationIgnored weak var mainWindow: NSWindow?
    /// Set when macOS started the app as a login item: stay in the menu bar instead of opening the window.
    @ObservationIgnored var suppressInitialWindow = false
    @ObservationIgnored private var accessPoll: Timer?

    private init() {
        let settings = store.load()
        self.settings = settings
        transport = AuraHIDTransport()
        hidAccess = transport.access
        device = transport.device
        lighting = LightingController(state: settings.lighting, customPresets: settings.customPresets, transport: transport)
        display = DisplayController(profile: settings.displayProfile)

        wire()
        if settings.globalShortcutsEnabled { registerShortcuts() }
        isPermissionSheetPresented = hidAccess != .granted
        updateAccessPolling()

        log.add(.info, "Started", device.map { "Found \($0.name) (\($0.formattedPID))." } ?? "No Aura keyboard found.")
        // Without a keyboard or permission the write can only fail; the device and
        // access callbacks resync as soon as both are available.
        if device != nil, hidAccess == .granted { lighting.resync() }
    }

    // MARK: - Wiring

    private func wire() {
        lighting.onChange = { [weak self] in
            guard let self else { return }
            settings.lighting = lighting.state
            settings.customPresets = lighting.customPresets
        }
        lighting.onWriteFailure = { [weak self] result in
            self?.log.add(.error, "Keyboard write failed", Self.describe(result))
        }
        display.onChange = { [weak self] profile in
            self?.settings.displayProfile = profile
        }

        transport.onDeviceChange = { [weak self] info in
            guard let self else { return }
            device = info
            if let info {
                log.add(.success, "Keyboard connected", "\(info.name) (\(info.formattedPID))")
                if hidAccess == .granted { lighting.resync() }
            } else {
                log.add(.warning, "Keyboard disconnected")
            }
        }
        transport.onAccessChange = { [weak self] access in
            guard let self else { return }
            hidAccess = access
            updateAccessPolling()
            if access == .granted {
                isPermissionSheetPresented = false
                log.add(.success, "Input Monitoring granted")
                if device != nil { lighting.resync() }
            } else if access == .denied {
                log.add(.warning, "Input Monitoring denied", "Keyboard lighting and hotkeys are blocked by macOS.")
            }
        }
        transport.onKey = { [weak self] key in self?.handle(key) }
        shortcuts.onAction = { [weak self] action in self?.handle(action) }

        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.systemDidWake() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.transport.updateAccess()
                self?.loginItem.refresh()
            }
        }
    }

    /// The app only re-checks access when it becomes active, which never happens while it
    /// runs from the menu bar alone. Poll until access is granted so the change is noticed.
    private func updateAccessPolling() {
        if hidAccess == .granted {
            accessPoll?.invalidate()
            accessPoll = nil
        } else if accessPoll == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.transport.updateAccess() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            accessPoll = timer
        }
    }

    private func registerShortcuts() {
        shortcuts.register()
        unavailableShortcuts = shortcuts.failed
        if !unavailableShortcuts.isEmpty {
            let names = unavailableShortcuts.map { GlobalShortcuts.Action.modifierGlyphs + $0.keyGlyph }.joined(separator: ", ")
            log.add(.warning, "Shortcuts unavailable", "\(names) could not be registered; another app is probably using them.")
        }
    }

    private func settingsChanged(from old: AppSettings) {
        if settings.globalShortcutsEnabled != old.globalShortcutsEnabled {
            if settings.globalShortcutsEnabled {
                registerShortcuts()
            } else {
                shortcuts.unregister()
                unavailableShortcuts = []
            }
        }
        if settings.showDockIcon != old.showDockIcon {
            applyActivationPolicy()
        }
    }

    // MARK: - Events

    /// The controller forgets its state across sleep; the display drops gamma tables.
    private func systemDidWake() {
        wakeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            lighting.resync()
            display.scheduleReapply()
            log.add(.info, "Restored after wake")
        }
        wakeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func handle(_ key: HardwareKey) {
        switch key {
        case .rog:
            guard settings.rogKeyEnabled else { return }
            performROGKeyAction()
        case .backlightUp:
            lighting.stepLevel(by: 1)
            if settings.showBrightnessHUD { SystemActions.showKeyboardBrightnessHUD(up: true) }
        case .backlightDown:
            lighting.stepLevel(by: -1)
            if settings.showBrightnessHUD { SystemActions.showKeyboardBrightnessHUD(up: false) }
        case .sleep:
            SystemActions.sleep()
        case .fan, .touchpad:
            // Fan modes need EC access macOS does not offer; the touchpad is handled by its own driver.
            log.add(.info, "\(key == .fan ? "Fan" : "Touchpad") key pressed", "No action on macOS.")
        }
    }

    private func handle(_ action: GlobalShortcuts.Action) {
        switch action {
        case .backlightUp: lighting.stepLevel(by: 1)
        case .backlightDown: lighting.stepLevel(by: -1)
        case .nextPreset: lighting.cyclePreset(by: 1)
        case .previousPreset: lighting.cyclePreset(by: -1)
        case .toggleBacklight: lighting.toggle()
        }
    }

    func performROGKeyAction() {
        switch settings.rogKeyAction {
        case .toggleMainWindow: toggleMainWindow()
        case .cyclePresets: lighting.cyclePreset(by: 1)
        case .toggleBacklight: lighting.toggle()
        }
    }

    // MARK: - Windows

    /// The Dock icon follows the setting; with it on, the app also drops out of the Dock
    /// while only the menu bar item is running.
    func applyActivationPolicy() {
        let windowOpen = mainWindow != nil
        let showDock = settings.showDockIcon && (windowOpen || !settings.keepRunningInMenuBar)
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        if windowOpen { NSApp.activate() }
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        // Activate first: the menu bar panel and the ROG key don't make the app active,
        // so an existing window would otherwise only move to the front of our own windows.
        NSApp.activate()
        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            openMainWindowAction?()
        }
    }

    func toggleMainWindow() {
        if let window = mainWindow, window.isVisible, NSApp.isActive {
            window.performClose(nil)
        } else {
            showMainWindow()
        }
    }

    func mainWindowWillClose() {
        mainWindow = nil
        if settings.keepRunningInMenuBar || !settings.showDockIcon {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Permission

    func requestHIDAccess() {
        if !transport.requestAccess() {
            SystemActions.openInputMonitoringSettings()
        }
        hidAccess = transport.access
    }

    func prepareForTermination() {
        store.flush(settings)
        display.restoreSystemCalibration()
    }

    static func describe(_ result: AuraWriteResult) -> String {
        switch result {
        case .success: return "OK"
        case .noDevice: return "No Aura keyboard is connected."
        case .accessDenied: return "macOS blocked the write. Allow Input Monitoring for ROG Gaming Center."
        case .busy: return "Another app is holding the keyboard controller exclusively. Quit key remappers and re-sync."
        case .failed(let code): return String(format: "IOKit error 0x%08X", code)
        case .superseded: return "Replaced by a newer change."
        }
    }
}
