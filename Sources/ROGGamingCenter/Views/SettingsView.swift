import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            KeyboardSettings()
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let login = model.loginItem
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(get: { login.isEnabled }, set: { login.setEnabled($0) }))
                if login.needsApproval {
                    LabeledContent("Needs approval in System Settings") {
                        Button("Open Login Items…") { login.openLoginItemsSettings() }
                    }
                    .foregroundStyle(.orange)
                }
                if let error = login.lastError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
                Toggle("Show icon in the Dock", isOn: $model.settings.showDockIcon)
                if model.settings.showDockIcon && model.settings.keepRunningInMenuBar {
                    Text("Shown while the window is open.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Toggle("Keep running in the menu bar when the window is closed",
                       isOn: $model.settings.keepRunningInMenuBar)
            } footer: {
                Text("Lighting is restored after sleep and the display profile stays applied only while the app is running.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct KeyboardSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("ROG Key") {
                Toggle("Respond to the ROG key", isOn: $model.settings.rogKeyEnabled)
                Picker("When pressed", selection: $model.settings.rogKeyAction) {
                    ForEach(ROGKeyAction.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!model.settings.rogKeyEnabled)
            }

            Section {
                Toggle("Show the brightness overlay", isOn: $model.settings.showBrightnessHUD)
            } header: {
                Text("Fn Keys")
            } footer: {
                Text("Fn+↑ and Fn+↓ change the backlight. Fn+F11 puts the Mac to sleep. The overlay needs Accessibility access to appear.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable keyboard shortcuts", isOn: $model.settings.globalShortcutsEnabled)
                ForEach(GlobalShortcuts.Action.allCases, id: \.self) { action in
                    LabeledContent(action.title) {
                        HStack(spacing: 8) {
                            if model.unavailableShortcuts.contains(action) {
                                Label("In use by another app", systemImage: "exclamationmark.triangle.fill")
                                    .font(.callout)
                                    .foregroundStyle(.orange)
                            }
                            Text(GlobalShortcuts.Action.modifierGlyphs + action.keyGlyph)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!model.settings.globalShortcutsEnabled)
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Work from any app and any keyboard, including external ones.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
