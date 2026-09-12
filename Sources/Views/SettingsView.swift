import SwiftUI
import AppKit

// MARK: - Settings 2.0: Apple macOS System Settings Grouped Style

public struct SettingsView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared
    @State private var showShortcutsSheet: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Section: System Integration
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("System Integration", systemImage: "gearshape")

                    AppleGroupedBox {
                        // Open at Login
                        SettingsRowView(
                            icon: "arrow.up.right.square",
                            iconColor: ROGColor.info,
                            title: "Open at Login",
                            subtitle: "Launch background watchdog daemon automatically when your Mac boots."
                        ) {
                            Toggle("", isOn: Binding(
                                get: { service.isLaunchAtLoginEnabled },
                                set: { service.setLaunchAtLogin(enabled: $0) }
                            ))
                            .toggleStyle(SwitchToggleStyle())
                            .labelsHidden()
                            .focusable(false)
                        }

                        Divider()
                            .background(ROGColor.hairline)

                        // Keep Active in Menu Bar
                        SettingsRowView(
                            icon: "menubar.rectangle",
                            iconColor: ROGColor.good,
                            title: "Keep in Menu Bar on Window Close",
                            subtitle: "Maintains backlight controls and sleep watchdog in background."
                        ) {
                            Toggle("", isOn: $service.isCloseToTrayEnabled)
                                .toggleStyle(SwitchToggleStyle())
                                .labelsHidden()
                                .focusable(false)
                        }
                    }
                }

                // 3. Section: Aura Hardware & Key Interception
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Aura Hardware & Controller Behavior", systemImage: "sparkles")

                    AppleGroupedBox {
                        // Default Startup Lighting Preset
                        SettingsRowView(
                            icon: "sparkles",
                            iconColor: .purple,
                            title: "Default Startup Lighting Preset",
                            subtitle: "Active lighting profile applied when ROG Gaming Center launches."
                        ) {
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
                            .frame(width: 170)
                            .labelsHidden()
                        }

                        Divider()
                            .background(ROGColor.hairline)

                        // Hardware Handshake
                        SettingsRowView(
                            icon: "bolt.badge.automatic.fill",
                            iconColor: .indigo,
                            title: "Hardware Handshake on Launch",
                            subtitle: "Transmits initialization packet to ITE 8910 micro-controller on launch."
                        ) {
                            if service.permissionDenied {
                                AccentBadge("Access Denied", color: ROGColor.bad)
                            } else if service.isConnected {
                                AccentBadge("Connected (USB HID)", color: ROGColor.good)
                            } else {
                                AccentBadge("Disconnected", color: .secondary)
                            }
                        }

                        Divider()
                            .background(ROGColor.hairline)

                        // Physical ROG Key Interception
                        SettingsRowView(
                            icon: "bolt.fill",
                            iconColor: ROGColor.accent,
                            title: "Physical ROG Key Interception",
                            subtitle: "Intercepts hardware report 0x5A payload 0x38 directly from USB HID bus."
                        ) {
                            Toggle("", isOn: Binding(
                                get: { service.isROGKeyEnabled },
                                set: {
                                    service.isROGKeyEnabled = $0
                                    service.saveSettings()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle())
                            .labelsHidden()
                            .focusable(false)
                        }

                        if service.isROGKeyEnabled {
                            Divider()
                                .background(ROGColor.hairline)

                            // Key Press Action
                            SettingsRowView(
                                icon: service.rogKeyAction.icon,
                                iconColor: .purple,
                                title: "ROG Key Action",
                                subtitle: "Action executed when pressing the dedicated ROG key on keyboard."
                            ) {
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
                                .frame(width: 250)
                                .labelsHidden()
                            }

                            if let lastTime = service.lastROGKeyPressTime {
                                Divider()
                                    .background(ROGColor.hairline)

                                SettingsRowView(
                                    icon: "hand.tap.fill",
                                    iconColor: ROGColor.accent,
                                    title: "Last Physical Key Press",
                                    subtitle: "Hardware event detected at: \(lastTime)"
                                ) {
                                    AccentBadge("Handshake Live ⚡️", color: ROGColor.good)
                                }
                            }
                        }
                    }
                }

                // 4. Section: Battery Health & Power Management
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Battery Health & Power", systemImage: "battery.100.bolt")

                    AppleGroupedBox {
                        SettingsRowView(
                            icon: "battery.75",
                            iconColor: .green,
                            title: "Hardware Charging Threshold",
                            subtitle: "Limits maximum battery charge capacity to prolong Li-ion battery health."
                        ) {
                            HStack(spacing: 8) {
                                if telemetry.isAsusSMCChargeLimitSupported {
                                    AccentBadge("AsusSMC Active", color: ROGColor.good)
                                } else {
                                    AccentBadge("sysctl unavailable", color: .secondary)
                                }

                                Picker("", selection: Binding(
                                    get: { telemetry.batteryChargeLimit },
                                    set: { telemetry.setBatteryChargeLimit($0) }
                                )) {
                                    Text("60% (Max Lifespan)").tag(60)
                                    Text("80% (Balanced)").tag(80)
                                    Text("100% (Full Charge)").tag(100)
                                }
                                .frame(width: 155)
                                .labelsHidden()
                            }
                        }
                    }
                }

                // 5. Section: Hardware Reference & Shortcuts (Cheat Sheet Sheet)
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("Hardware Reference & Shortcuts", systemImage: "keyboard")

                    AppleGroupedBox {
                        SettingsRowView(
                            icon: "keyboard",
                            iconColor: .orange,
                            title: "ASUS ROG Built-in Function Keys",
                            subtitle: "View mapped Fn key combinations for backlight, volume, display, and sleep."
                        ) {
                            Button(action: { showShortcutsSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(.system(size: 11))
                                    Text("View Shortcuts")
                                        .font(ROGType.caption())
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Color(NSColor.controlColor).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                        .stroke(ROGColor.hairline, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .focusable(false)
                        }
                    }
                }

                // 5. Footer & App Quit
                HStack {
                    Text("Open Source under MIT License • ASUS ROG Strix GL503GE Hackintosh Driver")
                        .font(ROGType.footnote())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: { NSApp.terminate(nil) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Quit ROG Gaming Center")
                                .font(ROGType.caption())
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(ROGColor.bad)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(ROGColor.bad.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                .stroke(ROGColor.bad.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable(false)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .sheet(isPresented: $showShortcutsSheet) {
            ROGFunctionKeysSheet(isPresented: $showShortcutsSheet)
        }
    }
}

// MARK: - ROG Function Keys Sheet

struct ROGFunctionKeysSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sheet Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ROGColor.accent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("ASUS ROG Function Keys Suite")
                            .font(ROGType.title())
                            .foregroundStyle(.primary)

                        Text("Micro-controller hardware shortcuts active at firmware level.")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
            }

            Divider()
                .background(ROGColor.hairline)

            // Shortcut Rows
            VStack(spacing: 8) {
                ShortcutDetailRow(icon: "sun.max.fill", color: .yellow, title: "Keyboard Backlight Up / Down", keys: ["Fn", "↑ / ↓", "or", "F7 / F8"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "sparkles", color: .purple, title: "Cycle Aura RGB Modes (Rainbow, etc.)", keys: ["Fn", "← / →"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "power", color: .pink, title: "Toggle Backlight Power (Instant On / Off)", keys: ["Fn", "Space"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "speaker.wave.2.fill", color: .blue, title: "Audio Mute / Volume Down / Up", keys: ["Fn", "F1", "F2", "F3"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "display", color: .cyan, title: "Screen Display Brightness Down / Up", keys: ["Fn", "F4 / F5"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "rectangle.split.2x1.fill", color: .indigo, title: "Touchpad Hardware Toggle (VoodooI2C / ACPI)", keys: ["Fn", "F6"])
                Divider().background(ROGColor.hairline)
                ShortcutDetailRow(icon: "lock.fill", color: .green, title: "Screen Lock / System Sleep", keys: ["Fn", "F9 / F11"])
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                    .stroke(ROGColor.hairline, lineWidth: 0.5)
            )
        }
        .padding(22)
        .frame(width: 540)
    }
}

struct ShortcutDetailRow: View {
    let icon: String
    let color: Color
    let title: String
    let keys: [String]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)

            Text(title)
                .font(ROGType.body())
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    if k == "or" {
                        Text("or")
                            .font(ROGType.footnote())
                            .foregroundStyle(.secondary)
                    } else {
                        KeyCapBadge(k)
                    }
                }
            }
        }
        .padding(.vertical, 3)
    }
}
