import SwiftUI
import Charts
import AuraCore

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            DashboardGrid().padding(20)
        }
        .onAppear { model.telemetry.beginObserving() }
        .onDisappear { model.telemetry.endObserving() }
    }
}

struct DashboardGrid: View {
    var body: some View {
        // Grid sizes each row to its tallest card; cards stretch to fill, so rows line up.
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                ProcessorCard()
                MemoryCard()
            }
            GridRow {
                ThermalCard()
                BatteryCard()
            }
            GridRow {
                KeyboardCard()
                SystemCard()
            }
        }
    }
}

// MARK: - Cards

private struct ProcessorCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.telemetry
        Card(title: "Processor", symbol: "cpu") {
            HStack(alignment: .firstTextBaseline) {
                BigValue(value: Format.percent(t.cpu.total), caption: t.info.cpuName)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("User \(Format.percent(t.cpu.user))")
                    Text("System \(Format.percent(t.cpu.system))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Chart(t.cpuHistory) { sample in
                AreaMark(x: .value("Time", sample.id), y: .value("CPU", sample.value))
                    .foregroundStyle(.linearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", sample.id), y: .value("CPU", sample.value))
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { _ in AxisGridLine() }
            }
            .frame(height: 64)
            .accessibilityLabel("CPU usage over the last two minutes")
        }
    }
}

private struct MemoryCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let m = model.telemetry.memory
        Card(title: "Memory", symbol: "memorychip") {
            BigValue(value: Format.percent(m.usedFraction * 100),
                     caption: "\(Format.gb(m.usedGB)) of \(Format.gb(m.totalGB)) in use")
            Gauge(value: m.usedFraction) { EmptyView() }
                .gaugeStyle(.linearCapacity)
                .tint(m.usedFraction > 0.85 ? .orange : .accentColor)
            StatRow("Available", Format.gb(max(0, m.totalGB - m.usedGB)))
            StatRow("Compressed", Format.gb(m.compressedGB))
        }
    }
}

private struct ThermalCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let fans = model.telemetry.thermal.fanRPMs
        Card(title: "Thermals", symbol: "thermometer.medium") {
            if let temp = model.telemetry.thermal.cpuCelsius {
                let level = Self.level(for: temp)
                BigValue(value: "\(temp)°C", caption: "CPU temperature")
                Gauge(value: Double(min(temp, 100)), in: 0...100) { EmptyView() }
                    .gaugeStyle(.linearCapacity)
                    .tint(level.color)
                    .accessibilityLabel("CPU temperature")
                HStack(alignment: .firstTextBaseline) {
                    Text("Status").foregroundStyle(.secondary)
                    Spacer()
                    Label(level.title, systemImage: "circle.fill")
                        .labelStyle(StatusLabelStyle(color: level.color))
                }
                .font(.callout)
                StatRow("Limit", "100°C")
            } else {
                BigValue(value: "—", caption: "CPU temperature")
                Text("Not available on this Mac.").font(.callout).foregroundStyle(.secondary)
            }
            // Only shown when the SMC actually publishes fan speeds.
            ForEach(Array(fans.enumerated()), id: \.offset) { index, rpm in
                StatRow(fans.count > 1 ? "Fan \(index + 1)" : "Fan", rpm > 0 ? "\(rpm) RPM" : "Stopped")
            }
        }
    }

    private static func level(for temp: Int) -> (title: String, color: Color) {
        switch temp {
        case ..<60: return ("Cool", .green)
        case ..<75: return ("Warm", .yellow)
        case ..<88: return ("Hot", .orange)
        default: return ("Very hot", .red)
        }
    }
}

private struct StatusLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 7)).foregroundStyle(color)
            configuration.title
        }
    }
}

private struct BatteryCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let b = model.telemetry.battery
        Card(title: "Battery", symbol: batterySymbol(b)) {
            if !b.isPresent {
                Text("No battery detected").font(.title3.weight(.medium))
                Text("Running on external power.").font(.callout).foregroundStyle(.secondary)
            } else {
                BigValue(value: "\(b.percent)%", caption: stateText(b))
                if let d = b.details {
                    StatRow("Health", "\(d.healthPercent)% · \(d.condition)")
                    StatRow("Cycle count", "\(d.cycleCount)")
                    if d.watts > 0.1 {
                        StatRow(b.isOnAC ? "Charging power" : "Power draw", String(format: "%.1f W", d.watts))
                    }
                }
            }
        }
        .font(.callout)
    }

    private func stateText(_ b: BatteryStatus) -> String {
        if b.isCharging {
            return b.timeRemainingMinutes.map { "Charging · \(Format.minutes($0)) to full" } ?? "Charging"
        }
        if b.isOnAC { return "On power adapter" }
        return b.timeRemainingMinutes.map { "\(Format.minutes($0)) remaining" } ?? "On battery"
    }

    private func batterySymbol(_ b: BatteryStatus) -> String {
        guard b.isPresent else { return "powerplug" }
        if b.isCharging { return "battery.100.bolt" }
        switch b.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

private struct KeyboardCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lighting = model.lighting
        let status = ConnectionStatus(model: model)
        Card(title: "Keyboard", symbol: "keyboard") {
            HStack(spacing: 6) {
                StatusDot(color: status.color)
                Text(status.title).foregroundStyle(.secondary)
                Spacer()
                if model.hidAccess != .granted {
                    Button("Allow…") { model.isPermissionSheetPresented = true }
                        .controlSize(.small)
                }
            }
            .font(.callout)

            ControlRow("Backlight") {
                Toggle("Backlight", isOn: Binding(get: { lighting.state.isOn }, set: { lighting.setOn($0) }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            ControlRow("Brightness") {
                Picker("Brightness", selection: Binding(get: { lighting.state.brightness }, set: { lighting.setLevel($0) })) {
                    Text("Low").tag(1)
                    Text("Medium").tag(2)
                    Text("High").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: controlRowWidth)
                .disabled(!lighting.state.isOn)
            }

            ControlRow("Preset") {
                Picker("Preset", selection: Binding(
                    get: { lighting.state.presetID ?? "" },
                    set: { id in lighting.allPresets.first { $0.id == id }.map(lighting.apply) }
                )) {
                    if lighting.activePreset == nil {
                        Text("Custom").tag("")
                    }
                    ForEach(lighting.allPresets) { Text($0.name).tag($0.id) }
                }
                .labelsHidden()
                .frame(width: controlRowWidth)
            }

            Spacer(minLength: 0)

            Button {
                model.selection = .lighting
            } label: {
                Label("Customize Lighting", systemImage: "arrow.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .font(.callout)
        }
        .focusEffectDisabled()
    }
}

/// Title on the left, control right-aligned; keeps a card's controls in one column.
private let controlRowWidth: CGFloat = 200

private struct ControlRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            control
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.caption)
        }
    }
}

private struct SystemCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let info = model.telemetry.info
        Card(title: "System", symbol: "laptopcomputer") {
            BigValue(
                value: info.osName.isEmpty ? "macOS \(info.osVersion)" : "macOS \(info.osName)",
                caption: "Version \(info.osVersion)" + (info.osBuild.isEmpty ? "" : " (\(info.osBuild))")
            )
            StatRow("Model", info.model)
            StatRow("Cores", "\(info.physicalCores) cores · \(info.logicalCores) threads")
            StatRow("Memory", "\(info.memoryGB) GB")
            StatRow("Uptime", Format.duration(model.telemetry.uptime))
        }
    }
}
