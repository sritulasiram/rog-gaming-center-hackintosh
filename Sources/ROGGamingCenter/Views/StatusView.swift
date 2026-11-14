import SwiftUI
import AuraHID

struct StatusView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let status = ConnectionStatus(model: model)
        Form {
            Section("Keyboard") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        StatusDot(color: status.color)
                        Text(status.title)
                    }
                }
                if let d = model.device {
                    LabeledContent("Controller", value: d.name)
                    LabeledContent("Product ID", value: d.formattedPID)
                    LabeledContent("HID usage", value: d.formattedUsage)
                    LabeledContent("Transport", value: d.transport)
                }
                if let date = model.lighting.lastSuccessfulSync {
                    LabeledContent("Last update", value: date.formatted(date: .omitted, time: .standard))
                }
                if let result = model.lighting.lastResult, !result.isSuccess {
                    Label(AppModel.describe(result), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Button("Re-sync Keyboard") { model.lighting.resync() }
            }

            Section("Permissions") {
                LabeledContent("Input Monitoring") {
                    switch model.hidAccess {
                    case .granted:
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .denied:
                        Button("Open System Settings…") { SystemActions.openInputMonitoringSettings() }
                    case .undetermined:
                        Button("Allow…") { model.requestHIDAccess() }
                    }
                }
            }

            Section("Sensors") {
                LabeledContent("SMC", value: SMCReader.shared.isAvailable ? "Available" : "Unavailable")
                LabeledContent("CPU temperature", value: model.telemetry.thermal.cpuCelsius == nil ? "Not reported" : "Reported")
                LabeledContent("Fan speed", value: model.telemetry.thermal.fanRPMs.isEmpty ? "Not reported" : "Reported")
            }

            Section("Events") {
                if model.log.entries.isEmpty {
                    Text("No events yet.").foregroundStyle(.secondary)
                }
                ForEach(model.log.entries) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: icon(entry.kind))
                            .foregroundStyle(color(entry.kind))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                            if !entry.detail.isEmpty {
                                Text(entry.detail).font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(entry.date.formatted(date: .omitted, time: .standard))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem {
                Button { model.log.clear() } label: { Label("Clear Events", systemImage: "trash") }
                    .disabled(model.log.entries.isEmpty)
            }
        }
        .onAppear { model.telemetry.beginObserving() }
        .onDisappear { model.telemetry.endObserving() }
    }

    private func icon(_ kind: ActivityLog.Entry.Kind) -> String {
        switch kind {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }

    private func color(_ kind: ActivityLog.Entry.Kind) -> Color {
        switch kind {
        case .info: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
