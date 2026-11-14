import Foundation
import AuraCore

enum ROGKeyAction: String, CaseIterable, Identifiable, Codable {
    case toggleMainWindow = "toggle_main_window"
    case cyclePresets = "cycle_presets"
    case toggleBacklight = "toggle_backlight_power"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleMainWindow: return "Show or hide ROG Gaming Center"
        case .cyclePresets: return "Switch to the next lighting preset"
        case .toggleBacklight: return "Turn the backlight on or off"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var lighting: LightingState = .default
    var customPresets: [AuraPreset] = []
    var displayProfile: DisplayProfile = .standard
    var keepRunningInMenuBar = true
    var showDockIcon = true
    var rogKeyEnabled = true
    var rogKeyAction: ROGKeyAction = .toggleMainWindow
    var globalShortcutsEnabled = true
    var showBrightnessHUD = true

    init() {}

    // Every field decodes on its own: a missing or unreadable value falls back to its
    // default instead of failing the whole load, so new settings need no migration and
    // one bad value (say, a preset saved by a newer version) never costs the rest.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        lighting = value(.lighting, d.lighting)
        customPresets = (try? c.decodeIfPresent(LossyArray<AuraPreset>.self, forKey: .customPresets))?.elements ?? d.customPresets
        displayProfile = value(.displayProfile, d.displayProfile)
        keepRunningInMenuBar = value(.keepRunningInMenuBar, d.keepRunningInMenuBar)
        showDockIcon = value(.showDockIcon, d.showDockIcon)
        rogKeyEnabled = value(.rogKeyEnabled, d.rogKeyEnabled)
        rogKeyAction = value(.rogKeyAction, d.rogKeyAction)
        globalShortcutsEnabled = value(.globalShortcutsEnabled, d.globalShortcutsEnabled)
        showBrightnessHUD = value(.showBrightnessHUD, d.showBrightnessHUD)
    }
}

/// Persists `AppSettings` as one JSON value. Writes are debounced so dragging a
/// color picker does not hammer UserDefaults.
@MainActor
final class SettingsStore {
    private static let key = "AppSettings.v1"
    /// Holds the previous value when it couldn't be read, so it is never silently destroyed.
    private static let backupKey = "AppSettings.v1.unreadable"
    private let defaults: UserDefaults
    private var pendingSave: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        if let data = defaults.data(forKey: Self.key) {
            if let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                return settings
            }
            defaults.set(data, forKey: Self.backupKey)
        }
        let migrated = migrateLegacy()
        saveNow(migrated)
        return migrated
    }

    func save(_ settings: AppSettings) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow(settings) }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func flush(_ settings: AppSettings) {
        pendingSave?.cancel()
        saveNow(settings)
    }

    private func saveNow(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Reads the pre-2.0 `Aura_*` keys once.
    private func migrateLegacy() -> AppSettings {
        var s = AppSettings()
        let d = defaults

        if let data = d.data(forKey: "Aura_CustomPresets"),
           let presets = try? JSONDecoder().decode([AuraPreset].self, from: data) {
            s.customPresets = presets
        }
        if d.object(forKey: "Aura_CloseToTray") != nil { s.keepRunningInMenuBar = d.bool(forKey: "Aura_CloseToTray") }
        if d.object(forKey: "Aura_ROGKeyEnabled") != nil { s.rogKeyEnabled = d.bool(forKey: "Aura_ROGKeyEnabled") }
        if let raw = d.string(forKey: "Aura_ROGKeyAction") {
            s.rogKeyAction = ROGKeyAction(rawValue: raw) ?? .toggleMainWindow // "toggle_popover" maps to the window
        }

        var lighting = LightingState.default
        if d.object(forKey: "Aura_Brightness") != nil {
            let level = d.integer(forKey: "Aura_Brightness")
            if level > 0 { lighting.brightness = min(3, level) }
        }
        if d.object(forKey: "Aura_IsPoweredOn") != nil { lighting.isOn = d.bool(forKey: "Aura_IsPoweredOn") }
        let zones = (d.stringArray(forKey: "Aura_ZoneColors") ?? []).compactMap(AuraColor.init(hex:))
        let speed = AuraSpeed(rawValue: d.integer(forKey: "Aura_Speed")) ?? .medium

        if let id = d.string(forKey: "Aura_ActivePresetId") {
            if let preset = (AuraPreset.builtInPresets + s.customPresets).first(where: { $0.id == id }) {
                lighting.mode = preset.mode
                lighting.presetID = preset.id
            } else if id == "custom_4zone", zones.count == 4 {
                lighting.mode = .multiStatic(zones)
                lighting.presetID = nil
            } else if id == "custom_single", let first = zones.first {
                lighting.mode = .singleStatic(first)
                lighting.presetID = nil
            }
        }
        lighting.mode = lighting.mode.withSpeed(speed)
        s.lighting = lighting
        return s
    }
}
