import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var service = AuraService.shared

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // 1. App Identity & Service Status Hero Card
                AppIdentityHeroCard()

                // 2. System Integration & Startup Preferences
                SystemIntegrationCard()

                // 3. Aura Hardware Startup Defaults
                AuraHardwareDefaultsCard()

                // 4. Dedicated ROG Hardware Key Launcher
                ROGHardwareKeyCard()

                // 5. Global Keyboard Shortcuts
                GlobalKeyboardShortcutsCard()

                // 6. Maintenance & App Quit
                MaintenanceCard()
            }
            .padding(18)
        }
    }
}

// MARK: - 1. App Identity Hero Card

struct AppIdentityHeroCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ROGLogoView(size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("ROG Gaming Center for macOS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("v1.0.0")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                Text("Native Swift IOKit USB HID Driver for ASUS ITE 8910 Controllers")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                if let url = URL(string: "https://github.com/wroberts/rog-aura-core") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "safari")
                    Text("GitHub")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlColor).opacity(0.8))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
            )
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - 2. System Integration Card

struct SystemIntegrationCard: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("System Integration & Startup", systemImage: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)

            VStack(spacing: 10) {
                // Open at Login
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "arrow.up.right.square.fill", color: .blue)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open at Login")
                            .font(.system(size: 12, weight: .medium))
                        Text("Launch the background watchdog daemon automatically when your Mac boots.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { service.isLaunchAtLoginEnabled },
                        set: { service.setLaunchAtLogin(enabled: $0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                }

                Divider().opacity(0.4)

                // Keep in Menu Bar
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "menubar.rectangle", color: .green)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Keep Active in Menu Bar on Window Close")
                            .font(.system(size: 12, weight: .medium))
                        Text("Closing the main window keeps backlight controls and the sleep watchdog active.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $service.isCloseToTrayEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - 3. Aura Hardware Defaults Card

struct AuraHardwareDefaultsCard: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Aura Hardware & Startup Preferences", systemImage: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.purple)

            VStack(spacing: 10) {
                // Startup Preset Picker
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "sparkles", color: .purple)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Default Startup Lighting Preset")
                            .font(.system(size: 12, weight: .medium))
                        Text("The active lighting profile applied when ROG Gaming Center launches.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: Binding(
                        get: { service.activePresetId },
                        set: { newId in
                            if let matched = (AuraPreset.builtInPresets + service.customPresets).first(where: { $0.id == newId }) {
                                service.applyPreset(matched)
                            }
                        }
                    )) {
                        ForEach(AuraPreset.builtInPresets + service.customPresets) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .frame(width: 150)
                }

                Divider().opacity(0.4)

                // Boot Handshake
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "bolt.badge.automatic.fill", color: .indigo)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Hardware Handshake on App Launch")
                            .font(.system(size: 12, weight: .medium))
                        Text("Sends the ITE 8910 controller initialization packet immediately on boot.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Automatic (Active 🟢)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - 4. Dedicated ROG Hardware Key Card

struct ROGHardwareKeyCard: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dedicated ROG Hardware Key Launcher", systemImage: "sparkle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(service.isConnected ? "ITE 8910 (0xFF31 / 0x0038) Active" : "Waiting for Controller")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(service.isConnected ? .green : .secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((service.isConnected ? Color.green : Color.orange).opacity(0.12))
                .cornerRadius(6)
            }

            VStack(spacing: 10) {
                // Enable/Disable Toggle
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "bolt.fill", color: .red)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Enable Physical ROG Key Interception")
                            .font(.system(size: 12, weight: .medium))
                        Text("Intercepts hardware input report 0x5A payload 0x38 directly from the internal USB HID bus.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { service.isROGKeyEnabled },
                        set: {
                            service.isROGKeyEnabled = $0
                            service.saveSettings()
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                }

                if service.isROGKeyEnabled {
                    Divider().opacity(0.4)

                    // Action Selector
                    HStack(spacing: 12) {
                        SettingsBadgeIcon(icon: service.rogKeyAction.icon, color: .purple)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Key Press Action")
                                .font(.system(size: 12, weight: .medium))
                            Text("Action triggered when pressing the physical ROG key on your keyboard.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { service.rogKeyAction },
                            set: {
                                service.rogKeyAction = $0
                                service.saveSettings()
                            }
                        )) {
                            ForEach(ROGKeyAction.allCases) { action in
                                HStack {
                                    Image(systemName: action.icon)
                                    Text(action.displayName)
                                }.tag(action)
                            }
                        }
                        .frame(width: 270)
                    }

                    if let lastTime = service.lastROGKeyPressTime {
                        Divider().opacity(0.4)

                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)

                            Text("Last Physical Press Detected at: \(lastTime)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            Text("Hardware Handshake Live ⚡️")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - 5. Global Keyboard Shortcuts Card

struct GlobalKeyboardShortcutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ASUS ROG Function Keys Suite (Active in Background)", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)

                Spacer()

                Text("Pure Fn Keys")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }

            VStack(spacing: 8) {
                ShortcutRow(icon: "sun.max.fill", color: .yellow, title: "Keyboard Backlight Up / Down", keys: ["Fn", "↑ / ↓", "or", "F7 / F8"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "sparkles", color: .purple, title: "Cycle Aura RGB Modes (Rainbow, etc.)", keys: ["Fn", "← / →"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "power", color: .pink, title: "Toggle Backlight Power (Instant On / Off)", keys: ["Fn", "Space"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "speaker.wave.2.fill", color: .blue, title: "Audio Mute / Volume Down / Volume Up", keys: ["Fn", "F1", "F2", "F3"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "display", color: .cyan, title: "Screen Display Brightness Down / Up", keys: ["Fn", "F4 / F5"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "rectangle.split.2x1.fill", color: .indigo, title: "Touchpad Toggle (On / Off)", keys: ["Fn", "F6"])
                Divider().opacity(0.4)
                ShortcutRow(icon: "lock.fill", color: .green, title: "Screen Lock / System Sleep", keys: ["Fn", "F9 / F11"])
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct ShortcutRow: View {
    let icon: String
    let color: Color
    let title: String
    let keys: [String]

    var body: some View {
        HStack(spacing: 12) {
            SettingsBadgeIcon(icon: icon, color: color)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))

            Spacer()

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    if k == "or" {
                        Text("or")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    } else {
                        KeyCapBadge(label: k)
                    }
                }
            }
        }
    }
}

struct KeyCapBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlColor).opacity(0.9))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
            )
    }
}

// MARK: - 5. Maintenance Card

struct MaintenanceCard: View {
    var body: some View {
        HStack {
            Text("Open Source under MIT License • Copyright © 2026")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button("Quit ROG Gaming Center") {
                NSApp.terminate(nil)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.red)
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct SettingsBadgeIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 24, height: 24)

            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}
