import AppKit
import Carbon.HIToolbox
import Observation
import ServiceManagement

// MARK: - Launch at Login

@MainActor
@Observable
final class LoginItemController {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval
    private(set) var lastError: String?

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

// MARK: - System Actions

enum SystemActions {
    static func sleep() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["sleepnow"]
        try? task.run()
    }

    /// Shows the system keyboard-brightness HUD by posting the media key macOS
    /// itself uses. Needs no backlight hardware of its own; the HUD only appears
    /// if the app is allowed to post events (Accessibility).
    static func showKeyboardBrightnessHUD(up: Bool) {
        let key = up ? NX_KEYTYPE_ILLUMINATION_UP : NX_KEYTYPE_ILLUMINATION_DOWN
        for (flags, state) in [(0xa00, 0xa), (0xb00, 0xb)] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                data1: Int((key << 16) | (Int32(state) << 8)), data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Global Shortcuts

/// System-wide shortcuts registered with `RegisterEventHotKey`. Unlike event
/// monitors these need no permission, only fire for the exact combination, and
/// are consumed so other apps never see them.
@MainActor
final class GlobalShortcuts {
    enum Action: UInt32, CaseIterable {
        case backlightUp = 1, backlightDown, nextPreset, previousPreset, toggleBacklight

        var title: String {
            switch self {
            case .backlightUp: return "Backlight brighter"
            case .backlightDown: return "Backlight dimmer"
            case .nextPreset: return "Next preset"
            case .previousPreset: return "Previous preset"
            case .toggleBacklight: return "Backlight on / off"
            }
        }

        var keyCode: Int {
            switch self {
            case .backlightUp: return kVK_UpArrow
            case .backlightDown: return kVK_DownArrow
            case .nextPreset: return kVK_RightArrow
            case .previousPreset: return kVK_LeftArrow
            case .toggleBacklight: return kVK_ANSI_L
            }
        }

        var keyGlyph: String {
            switch self {
            case .backlightUp: return "↑"
            case .backlightDown: return "↓"
            case .nextPreset: return "→"
            case .previousPreset: return "←"
            case .toggleBacklight: return "L"
            }
        }

        static let modifierGlyphs = "⌃⌥⌘"
        static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    }

    var onAction: ((Action) -> Void)?
    private var hotKeys: [EventHotKeyRef] = []
    /// Actions whose key combination could not be registered on the last `register()`.
    private(set) var failed: [Action] = []
    private var handler: EventHandlerRef?

    var isRegistered: Bool { !hotKeys.isEmpty }

    func register() {
        guard hotKeys.isEmpty else { return }
        failed = []
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard let context, let action = Action(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
                let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(context).takeUnretainedValue()
                MainActor.assumeIsolated { shortcuts.onAction?(action) }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        for action in Action.allCases {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x524F_4743), id: action.rawValue) // 'ROGC'
            if RegisterEventHotKey(UInt32(action.keyCode), Action.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref {
                hotKeys.append(ref)
            } else {
                failed.append(action)
            }
        }
    }

    func unregister() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys.removeAll()
        failed = []
    }
}

// MARK: - Activity Log

@MainActor
@Observable
final class ActivityLog {
    struct Entry: Identifiable {
        enum Kind { case info, success, warning, error }
        let id = UUID()
        let date = Date()
        let kind: Kind
        let title: String
        let detail: String
    }

    private(set) var entries: [Entry] = []
    private let limit = 200

    func add(_ kind: Entry.Kind, _ title: String, _ detail: String = "") {
        entries.insert(Entry(kind: kind, title: title, detail: detail), at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
    }

    func clear() { entries.removeAll() }
}
