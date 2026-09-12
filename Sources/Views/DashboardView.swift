import SwiftUI
import AppKit

// MARK: - Dashboard 2.0: Apple macOS Bento Grid

public struct DashboardView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            // ROW 1: System Architecture & Silicon Vitality (Equal Height)
            HStack(spacing: 14) {
                SystemArchitectureBentoCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                SiliconVitalityBentoCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ROW 2: Silicon Thermals & Hardware Quick Controls (Equal Height)
            HStack(spacing: 14) {
                ThermalEngineBentoCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                QuickHardwareControlsBentoCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 1. Thermal Engine Bento Card (Top-Left)

struct ThermalEngineBentoCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    private var dieTempColor: Color {
        let temp = telemetry.fan.cpuTempCelsius
        if temp < 55 { return ROGColor.good }
        if temp < 75 { return ROGColor.warn }
        return ROGColor.bad
    }

    var body: some View {
        AppleBentoCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Section Header
                HStack {
                    SectionLabel("Silicon Thermal Engine", systemImage: "thermometer.sun.fill")
                    Spacer()
                    AccentBadge("Autonomous EC", color: ROGColor.info)
                }

                // Dual Hero Readout (Silicon Die & Thermal Headroom)
                HStack(spacing: 16) {
                    // Die Temperature
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Silicon Die Temperature")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(telemetry.fan.cpuTempCelsius)°C")
                                .font(ROGType.heroNumber())
                                .foregroundStyle(dieTempColor)

                            if telemetry.fan.isRealHardwareThermals {
                                AccentBadge("SMC", color: ROGColor.good)
                            }
                        }

                        Text("Coffee Lake DTS")
                            .font(ROGType.footnote())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Thermal Headroom
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Thermal Headroom")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)

                        Text("\(telemetry.fan.thermalHeadroomPercent)%")
                            .font(ROGType.heroNumber())
                            .foregroundStyle(ROGColor.info)

                        Text("Until 100°C Tjunction")
                            .font(ROGType.footnote())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                        .stroke(ROGColor.hairline, lineWidth: 0.5)
                )

                // Cooling Array Status Tile
                HStack(spacing: 10) {
                    Image(systemName: "fanblades.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(ROGColor.info)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dual Blower Cooling Array")
                            .font(ROGType.bodyEmphasized())
                            .foregroundStyle(.primary)

                        Text("Phase: \(telemetry.fan.coolingPhaseTitle)")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(telemetry.fan.isRealFanRPM ? "\(telemetry.fan.fanRPM) RPM" : "~\(telemetry.fan.fanRPM) RPM")
                            .font(ROGType.inlineNumber())
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        AccentBadge(telemetry.fan.isRealFanRPM ? "SMC" : "EST", color: telemetry.fan.isRealFanRPM ? ROGColor.good : .secondary)
                    }
                }
                .padding(11)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                        .stroke(ROGColor.hairline, lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - 2. System Architecture & Battery Bento Card (Bottom-Left)

struct SystemArchitectureBentoCard: View {
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
        AppleBentoCard(padding: 16) {
            VStack(alignment: .leading, spacing: 11) {
                // Section Header
                HStack {
                    SectionLabel("System Architecture & Battery", systemImage: "laptopcomputer")
                    Spacer()
                    AccentBadge("GL503GE", color: ROGColor.accent)
                }

                // Specification Rows
                VStack(spacing: 6) {
                    LabeledRow("Processor", cleanCPUName)
                    LabeledRow("Topology", "\(telemetry.specs.physicalCores) Cores · \(telemetry.specs.logicalThreads) Threads")
                    LabeledRow("Memory", "\(telemetry.specs.totalRAMGB) GB DDR4 · 2667 MHz")
                    LabeledRow("Operating System", telemetry.specs.osVersion)
                    LabeledRow("Kernel Uptime", telemetry.specs.uptimeString)
                }

                Divider()
                    .background(ROGColor.hairline)

                // Battery Telemetry
                VStack(spacing: 6) {
                    HStack {
                        Text("Battery Status")
                            .font(ROGType.body())
                            .foregroundStyle(.secondary)
                        Spacer()
                        AccentBadge(
                            "\(telemetry.battery.currentCapacity)% · " + (telemetry.battery.isCharging ? "Charging" : (telemetry.battery.isACConnected ? "AC Power" : "Battery")),
                            color: telemetry.battery.isCharging ? ROGColor.good : .secondary
                        )
                    }

                    LabeledRow("Live Power Draw", String(format: "%.1f W (%.2fV)", telemetry.battery.liveWatts, telemetry.battery.voltageVolts))
                    LabeledRow("Battery Health", "\(telemetry.battery.healthPercent)% · \(telemetry.battery.condition)")
                    LabeledRow("Cycle Count", "\(telemetry.battery.cycleCount)")
                }
            }
        }
    }
}

// MARK: - 3. Silicon Vitality & Memory Bento Card (Top-Right)

struct SiliconVitalityBentoCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        AppleBentoCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    SectionLabel("Silicon Vitality & Memory", systemImage: "cpu")
                    Spacer()
                    AccentBadge("Mach Telemetry", color: .purple)
                }

                // Dual Activity Rings (CPU & RAM)
                HStack(spacing: 16) {
                    // CPU Ring
                    HStack(spacing: 12) {
                        ZStack {
                            ActivityRing(
                                progress: telemetry.cpuLoad.totalUsagePercent / 100.0,
                                ringWidth: 7,
                                gradientColors: [Color.cyan, Color.blue]
                            )
                            .frame(width: 58, height: 58)

                            VStack(spacing: 0) {
                                Text("\(Int(telemetry.cpuLoad.totalUsagePercent))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU Load")
                                .font(ROGType.bodyEmphasized())
                                .foregroundStyle(.primary)

                            Text("\(Int(telemetry.cpuLoad.totalUsagePercent))% Active")
                                .font(ROGType.caption())
                                .foregroundStyle(.secondary)

                            Text("Mach Host Ticks")
                                .font(ROGType.footnote())
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                            .stroke(ROGColor.hairline, lineWidth: 0.5)
                    )

                    // RAM Ring
                    HStack(spacing: 12) {
                        ZStack {
                            ActivityRing(
                                progress: telemetry.memory.usedPercent / 100.0,
                                ringWidth: 7,
                                gradientColors: [Color.purple, Color.pink]
                            )
                            .frame(width: 58, height: 58)

                            VStack(spacing: 0) {
                                Text("\(Int(telemetry.memory.usedPercent))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("RAM Usage")
                                .font(ROGType.bodyEmphasized())
                                .foregroundStyle(.primary)

                            Text(String(format: "%.1f / %.1f GB", telemetry.memory.usedGB, telemetry.memory.totalGB))
                                .font(ROGType.caption())
                                .foregroundStyle(.secondary)

                            Text("\(Int(telemetry.memory.usedPercent))% Allocated")
                                .font(ROGType.footnote())
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                            .stroke(ROGColor.hairline, lineWidth: 0.5)
                    )
                }

                // Rolling Sparkline History
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Active Silicon Load History (24-Point)")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(telemetry.cpuLoad.totalUsagePercent))% Current")
                            .font(ROGType.caption())
                            .foregroundStyle(ROGColor.info)
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        let points = telemetry.cpuHistory
                        let step = points.count > 1 ? geo.size.width / CGFloat(points.count - 1) : 0
                        let height = geo.size.height

                        // Gradient Fill Path
                        Path { path in
                            guard points.count > 1 else { return }
                            path.move(to: CGPoint(x: 0, y: height))
                            for (index, val) in points.enumerated() {
                                let norm = min(1.0, max(0.0, val / 100.0))
                                let y = height - (CGFloat(norm) * (height - 4)) - 2
                                let x = CGFloat(index) * step
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: geo.size.width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.25), Color.blue.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        // Stroke Path
                        Path { path in
                            guard points.count > 1 else { return }
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
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                        .stroke(ROGColor.hairline, lineWidth: 0.5)
                )
            }
        }
    }
}

// MARK: - 4. Hardware Quick Controls Bento Card (Bottom-Right)

struct QuickHardwareControlsBentoCard: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        AppleBentoCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    SectionLabel("Hardware Quick Controls", systemImage: "slider.horizontal.3")
                    Spacer()
                }

                // 1. Backlight Power & Brightness
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Keyboard Backlight")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        // Power Button
                        Button(action: { service.togglePower() }) {
                            HStack(spacing: 6) {
                                Image(systemName: service.isPoweredOn ? "power.circle.fill" : "power.circle")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(service.isPoweredOn ? "Power On" : "Power Off")
                                    .font(ROGType.caption())
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(service.isPoweredOn ? ROGColor.good : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                    .fill(service.isPoweredOn ? ROGColor.good.opacity(0.15) : Color(NSColor.controlColor).opacity(0.4))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                    .stroke(service.isPoweredOn ? ROGColor.good.opacity(0.3) : ROGColor.hairline, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)

                        // Segmented Brightness (0, 33%, 66%, 100%)
                        HStack(spacing: 3) {
                            BrightnessSegmentButton(title: "Off", isSelected: !service.isPoweredOn || service.currentBrightness == 0) {
                                service.setBrightness(0)
                            }
                            BrightnessSegmentButton(title: "33%", isSelected: service.isPoweredOn && service.currentBrightness == 1) {
                                service.setBrightness(1)
                            }
                            BrightnessSegmentButton(title: "66%", isSelected: service.isPoweredOn && service.currentBrightness == 2) {
                                service.setBrightness(2)
                            }
                            BrightnessSegmentButton(title: "100%", isSelected: service.isPoweredOn && service.currentBrightness == 3) {
                                service.setBrightness(3)
                            }
                        }
                        .padding(2)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
                    }
                }

                Divider()
                    .background(ROGColor.hairline)

                // 2. Aura Core Preset Mode
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("Aura RGB Lighting Mode")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ROGColor.accent)
                                .frame(width: 8, height: 8)
                            Text(service.activePresetName)
                                .font(ROGType.bodyEmphasized())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                .stroke(ROGColor.hairline, lineWidth: 0.5)
                        )

                        Spacer()

                        Button(action: { service.cycleToNextPreset() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Next Preset")
                                    .font(ROGType.caption())
                            }
                            .foregroundStyle(ROGColor.info)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ROGColor.info.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                    .stroke(ROGColor.info.opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)
                    }
                }

                Divider()
                    .background(ROGColor.hairline)

                // 3. GameVisual Display Profile
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("GameVisual Display Profile")
                            .font(ROGType.caption())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        ForEach(ROGDisplayProfile.allCases) { profile in
                            let isSelected = telemetry.activeDisplayProfile == profile
                            Button(action: { telemetry.setDisplayProfile(profile) }) {
                                Text(profileShortName(profile))
                                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                            .fill(isSelected ? ROGColor.info : Color(NSColor.controlColor).opacity(0.35))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                                            .stroke(isSelected ? Color.clear : ROGColor.hairline, lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .focusable(false)
                        }
                    }
                }
            }
        }
    }

    private func profileShortName(_ profile: ROGDisplayProfile) -> String {
        switch profile {
        case .standard: return "Standard"
        case .vividGaming: return "Vivid"
        case .eyeCare: return "Eye Care"
        case .cinema: return "Cinema"
        case .fps: return "FPS"
        case .rts: return "RTS"
        }
    }
}

// MARK: - Subcomponents

struct BrightnessSegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: ROGRadius.control - 2, style: .continuous)
                        .fill(isSelected ? ROGColor.info : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
    }
}
