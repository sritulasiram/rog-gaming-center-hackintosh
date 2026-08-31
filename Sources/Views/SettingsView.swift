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

                // 4. Global Keyboard Shortcuts
                GlobalKeyboardShortcutsCard()

                // 5. Maintenance & App Quit
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

// MARK: - 4. Global Keyboard Shortcuts Card

struct GlobalKeyboardShortcutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Global Keyboard Shortcuts", systemImage: "command")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "sun.max.fill", color: .yellow)

                    Text("Keyboard Brightness Step Up / Down")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    HStack(spacing: 4) {
                        KeyCapBadge(label: "⌃")
                        KeyCapBadge(label: "⌥")
                        KeyCapBadge(label: "F7 / F8")
                    }
                }

                Divider().opacity(0.4)

                HStack(spacing: 12) {
                    SettingsBadgeIcon(icon: "power", color: .pink)

                    Text("Toggle Keyboard Backlight Power")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    HStack(spacing: 4) {
                        KeyCapBadge(label: "⌃")
                        KeyCapBadge(label: "⌥")
                        KeyCapBadge(label: "Space")
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
