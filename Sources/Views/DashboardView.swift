import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            // 3-Column Command Stage (Homage to Windows ROG Gaming Center)
            HStack(alignment: .top, spacing: 14) {
                // LEFT COLUMN: Hardware Specification & Battery
                VStack(spacing: 12) {
                    SystemArchitectureCard()
                    BatteryTelemetryCard()
                }
                .frame(maxWidth: .infinity)

                // CENTER COLUMN: Silicon Thermal Stage (Hero die temp, headroom, EC phase, sparkline)
                SiliconThermalStageCard()
                    .frame(maxWidth: .infinity)

                // RIGHT COLUMN: Dual Glowing Circular Dials (CPU Load & RAM)
                CircularGaugesCard()
                    .frame(width: 240)
            }

            Spacer()

            // BOTTOM TRAY: Quick Hardware Controls (Windows Bottom Dock Homage - Real Controls Only)
            QuickHardwareDock()
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Column 1: System Architecture

struct SystemArchitectureCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    private var cleanCPUName: String {
        let raw = telemetry.specs.cpuBrand
        return raw.replacingOccurrences(of: "(R)", with: "")
                  .replacingOccurrences(of: "(TM)", with: "")
                  .replacingOccurrences(of: "CPU", with: "")
                  .components(separatedBy: "@").first?
                  .trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("SYSTEM ARCHITECTURE", systemImage: "cpu")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("GL503GE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.18))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                SpecRow(title: "Processor", value: cleanCPUName)
                SpecRow(title: "Topology", value: "\(telemetry.specs.physicalCores) Cores · \(telemetry.specs.logicalThreads) Threads")
                SpecRow(title: "Memory", value: "\(telemetry.specs.totalRAMGB) GB DDR4 · 2667 MHz")
                SpecRow(title: "Operating System", value: telemetry.specs.osVersion)
                SpecRow(title: "Kernel Uptime", value: telemetry.specs.uptimeString)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct SpecRow: View {
    let title: String
    let value: String

    init(title: String, value: String) {
        self.title = title
        self.value = value
    }

    init(label: String, value: String) {
        self.title = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Column 1: Battery Telemetry

struct BatteryTelemetryCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LITHIUM BATTERY", systemImage: "battery.100.bolt")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(telemetry.battery.isCharging ? "Charging" : (telemetry.battery.isACConnected ? "AC Power" : "Battery"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(telemetry.battery.isCharging ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                SpecRow(title: "Charge Level", value: "\(telemetry.battery.currentCapacity)%")
                SpecRow(title: "Live Draw", value: String(format: "%.1f W (%.2fV)", telemetry.battery.liveWatts, telemetry.battery.voltageVolts))
                SpecRow(title: "Battery Health", value: "\(telemetry.battery.healthPercent)% · \(telemetry.battery.condition)")
                SpecRow(title: "Cycle Count", value: "\(telemetry.battery.cycleCount)")
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - Column 2: Center Silicon Thermal Stage

struct SiliconThermalStageCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("SILICON THERMAL STAGE", systemImage: "thermometer.sun.fill")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Autonomous EC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
            }

            // Hero Dual Readout (Silicon Temp & Thermal Headroom)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SILICON DIE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(telemetry.fan.cpuTempCelsius)°C")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(tempColor(telemetry.fan.cpuTempCelsius))

                        if telemetry.fan.isRealHardwareThermals {
                            Text("SMC")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(3)
                        }
                    }
                    Text("Coffee Lake DTS")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("THERMAL HEADROOM")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("\(telemetry.fan.thermalHeadroomPercent)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)

                    Text("Until 100°C Tjunction")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.25))
            .cornerRadius(8)

            // Dual Blower Cooling Array Status
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "fanblades.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dual Blower Cooling Array")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Phase: \(telemetry.fan.coolingPhaseTitle)")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("~\(telemetry.fan.fanRPM) RPM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(10)
            .background(Color.black.opacity(0.18))
            .cornerRadius(8)

            // Rolling Mach Load Wave
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("LIVE SILICON LOAD (24-POINT)")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(telemetry.cpuLoad.totalUsagePercent))% Now")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }

                GeometryReader { geo in
                    let points = telemetry.cpuHistory
                    Path { path in
                        guard points.count > 1 else { return }
                        let step = geo.size.width / CGFloat(points.count - 1)
                        let height = geo.size.height

                        for (index, val) in points.enumerated() {
                            let norm = min(1.0, max(0.0, val / 100.0))
                            let y = height - (CGFloat(norm) * (height - 4)) - 2
                            let x = CGFloat(index) * step
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 38)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private func tempColor(_ temp: Int) -> Color {
        if temp < 55 { return .green }
        if temp < 75 { return .orange }
        return .red
    }
}

// MARK: - Column 3: Dual Circular Gauges (Homage to Windows Gauges)

struct CPUDialView: View {
    let usagePercent: Double

    var body: some View {
        VStack(spacing: 6) {
            Text("CPU LOAD")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, usagePercent / 100.0))))
                    .stroke(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(usagePercent))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Active")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 82, height: 82)

            Text("Mach Host Ticks")
                .font(.system(size: 8.5))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.22))
        .cornerRadius(8)
    }
}

struct RAMDialView: View {
    let usedPercent: Double
    let usedGB: Double
    let totalGB: Double

    var body: some View {
        VStack(spacing: 6) {
            Text("RAM UTILIZATION")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, usedPercent / 100.0))))
                    .stroke(
                        LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(usedPercent))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(String(format: "%.1fG", usedGB))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 82, height: 82)

            Text("\(String(format: "%.1f", usedGB)) / \(String(format: "%.1f", totalGB)) GB")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.22))
        .cornerRadius(8)
    }
}

struct CircularGaugesCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(spacing: 12) {
            CPUDialView(usagePercent: telemetry.cpuLoad.totalUsagePercent)
            RAMDialView(usedPercent: telemetry.memory.usedPercent, usedGB: telemetry.memory.usedGB, totalGB: telemetry.memory.totalGB)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// MARK: - Bottom Tray: Quick Hardware Controls Dock (Windows Bottom Dock Homage)

struct QuickHardwareDock: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        HStack(spacing: 12) {
            // Card 1: Backlight Power Toggle
            DockCard(title: "BACKLIGHT POWER", icon: service.isPoweredOn ? "power.circle.fill" : "power.circle") {
                Button(action: {
                    service.togglePower()
                }) {
                    Text(service.isPoweredOn ? "ON" : "OFF")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(service.isPoweredOn ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(service.isPoweredOn ? Color.green : Color(NSColor.controlColor).opacity(0.6))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Card 2: Brightness Selector
            DockCard(title: "BRIGHTNESS", icon: "sun.max.fill") {
                HStack(spacing: 4) {
                    DockMiniButton(title: "0", isSelected: !service.isPoweredOn || service.currentBrightness == 0) {
                        service.setBrightness(0)
                        HUDService.shared.showBacklightHUD(level: 0)
                    }
                    DockMiniButton(title: "33", isSelected: service.isPoweredOn && service.currentBrightness == 1) {
                        service.setBrightness(1)
                        HUDService.shared.showBacklightHUD(level: 1)
                    }
                    DockMiniButton(title: "66", isSelected: service.isPoweredOn && service.currentBrightness == 2) {
                        service.setBrightness(2)
                        HUDService.shared.showBacklightHUD(level: 2)
                    }
                    DockMiniButton(title: "100", isSelected: service.isPoweredOn && service.currentBrightness == 3) {
                        service.setBrightness(3)
                        HUDService.shared.showBacklightHUD(level: 3)
                    }
                }
            }

            // Card 3: Active Aura Core Mode
            DockCard(title: "AURA CORE", icon: "sparkles") {
                HStack {
                    Text(service.activePresetId.capitalized.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Button(action: {
                        service.cycleToNextPreset()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(5)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Card 4: GameVisual Display Gamma
            DockCard(title: "GAMEVISUAL", icon: "eye.fill") {
                HStack(spacing: 4) {
                    ForEach(ROGDisplayProfile.allCases) { profile in
                        Button(action: {
                            telemetry.setDisplayProfile(profile)
                            HUDService.shared.showMessage(icon: "eye.fill", text: profile.title, color: .blue)
                        }) {
                            Text(profileShortName(profile))
                                .font(.system(size: 9.5, weight: telemetry.activeDisplayProfile == profile ? .bold : .regular))
                                .foregroundColor(telemetry.activeDisplayProfile == profile ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(telemetry.activeDisplayProfile == profile ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private func profileShortName(_ profile: ROGDisplayProfile) -> String {
        switch profile {
        case .standard: return "Def"
        case .vividGaming: return "Vivid"
        case .eyeCare: return "Eye"
        case .cinema: return "Film"
        }
    }
}

struct DockCard<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content

    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity)
    }
}

struct DockMiniButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
