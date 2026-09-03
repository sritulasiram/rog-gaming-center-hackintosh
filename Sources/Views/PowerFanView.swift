import SwiftUI

public struct PowerFanView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // 1. Dual Fan Acoustic & Thermal HUD
                DualFanThermalHUD()

                // 2. Autonomous Hardware Thermal Management
                AutonomousThermalManagementGroup()

                // 3. Battery Health & Power Conservation (macOS Battery Style)
                BatteryHealthCareGroup()

                // 4. GameVisual Display Calibration
                GameVisualDisplayGroup()
            }
            .padding(18)
        }
    }
}

// MARK: - 1. Dual Fan Acoustic & Thermal HUD

struct DualFanThermalHUD: View {
    @ObservedObject var telemetry = TelemetryService.shared
    @State private var spinRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Dual Fan Thermal & Acoustic Architecture", systemImage: "fanblades.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Thermal Headroom: \(telemetry.fan.thermalHeadroomPercent)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Unified Dual Blower Cooling Array
            UnifiedCoolingTile(
                rpm: telemetry.fan.fanRPM,
                maxRPM: telemetry.fan.maxFanRPM,
                tempCelsius: telemetry.fan.cpuTempCelsius,
                headroomPercent: telemetry.fan.thermalHeadroomPercent,
                coolingPhase: telemetry.fan.coolingPhaseTitle
            )

            Divider().opacity(0.4)

            // Autonomous Hardware EC Management Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Autonomous Hardware Thermal Management (ITE IT8987 EC)", systemImage: "cpu.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Text(telemetry.fan.coolingPhaseTitle)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            telemetry.fan.coolingPhaseTitle == "Thermal Turbo" ? Color.red.opacity(0.15) :
                            (telemetry.fan.coolingPhaseTitle == "Active Cooling" ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                        )
                        .foregroundColor(
                            telemetry.fan.coolingPhaseTitle == "Thermal Turbo" ? .red :
                            (telemetry.fan.coolingPhaseTitle == "Active Cooling" ? .orange : .green)
                        )
                        .cornerRadius(4)
                }

                Text("Cooling fans are governed directly at the silicon level by the ITE IT8987 Embedded Controller on hardware ports 0x62/0x66. Operates autonomously according to Intel Coffee Lake DTS junction curves, ensuring continuous protection under all workloads.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("Quiet (< 52°C): ~1,800 RPM")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Active (52–75°C): ~2,400 RPM")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("Turbo (> 75°C): 3,315 RPM Max")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(8)
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

struct UnifiedCoolingTile: View {
    @ObservedObject var telemetry = TelemetryService.shared
    let rpm: Int
    let maxRPM: Int
    let tempCelsius: Int
    let headroomPercent: Int
    let coolingPhase: String

    var progress: Double {
        max(0.0, min(1.0, Double(rpm) / Double(maxRPM)))
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        tempCelsius > 75 ? Color.red : (tempCelsius > 52 ? Color.blue : Color.green),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "fanblades.fill")
                    .font(.system(size: 18))
                    .foregroundColor(tempCelsius > 75 ? .red : (tempCelsius > 52 ? .blue : .green))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Dual Blower Cooling Array")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    if telemetry.fan.isRealFanRPM {
                        Text("Live Tach")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                    } else {
                        Text("EC Active")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(3)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10))
                        Text("\(tempCelsius)°C")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                        if telemetry.fan.isRealHardwareThermals {
                            Text("SMC")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(3)
                        }
                    }
                    .foregroundColor(tempCelsius > 75 ? .red : (tempCelsius > 60 ? .orange : .green))
                }

                HStack(spacing: 8) {
                    Text("\(rpm)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("RPM (Shared Thermal Plate)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Thermal Headroom: \(headroomPercent)%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
    }
}

// MARK: - 2. Performance Profiles Group

struct AutonomousThermalManagementGroup: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Autonomous Hardware Thermal Management", systemImage: "cpu.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(phaseColor)
                        .frame(width: 7, height: 7)

                    Text(telemetry.fan.coolingPhaseTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Fans are managed in hardware by the motherboard Embedded Controller (ITE IT8987 on ports 0x62/0x66). The EC autonomously modulates blower speeds according to Intel Coffee Lake DTS silicon junction curves.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().opacity(0.4)

                HStack(spacing: 10) {
                    PhaseChip(title: "Quiet Airflow", threshold: "< 52°C", rpm: "~1,800 RPM", isActive: telemetry.fan.coolingPhaseTitle == "Quiet Airflow", color: .green)
                    PhaseChip(title: "Active Cooling", threshold: "52–75°C", rpm: "~2,400 RPM", isActive: telemetry.fan.coolingPhaseTitle == "Active Cooling", color: .orange)
                    PhaseChip(title: "Thermal Turbo", threshold: "> 75°C", rpm: "Up to 3,315 RPM", isActive: telemetry.fan.coolingPhaseTitle == "Thermal Turbo", color: .red)
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

    private var phaseColor: Color {
        switch telemetry.fan.coolingPhaseTitle {
        case "Quiet Airflow": return .green
        case "Active Cooling": return .orange
        default: return .red
        }
    }
}

struct PhaseChip: View {
    let title: String
    let threshold: String
    let rpm: String
    let isActive: Bool
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(isActive ? color : Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
            }
            Text(threshold)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
            Text(rpm)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(isActive ? color : .secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? color.opacity(0.12) : Color.black.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? color.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 3. Battery Health & Power Conservation

struct BatteryHealthCareGroup: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Battery Health, Wear & Power Conservation", systemImage: "battery.100.bolt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(telemetry.battery.healthPercent >= 80 ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)

                    Text("Condition: \(telemetry.battery.condition)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(telemetry.battery.healthPercent >= 80 ? .green : .orange)
                }
            }

            // Battery Health & Wear Visual Gauge Row
            HStack(spacing: 16) {
                // Health Ring Gauge
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                            .frame(width: 52, height: 52)

                        Circle()
                            .trim(from: 0, to: CGFloat(Double(telemetry.battery.healthPercent) / 100.0))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))

                        Text("\(telemetry.battery.healthPercent)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maximum Capacity")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("\(telemetry.battery.wearPercent)% Chemical Wear")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)

                // Battery Specs Grid
                VStack(spacing: 4) {
                    HStack {
                        Text("Full Charge Capacity")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(telemetry.battery.maxCapacityMAh) mAh")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }

                    HStack {
                        Text("Factory Design Capacity")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(telemetry.battery.designCapacityMAh) mAh")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }

                    HStack {
                        Text("Battery Cycle Count")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(telemetry.battery.cycleCount) Cycles")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            }

            // Power Flow & Voltage Strip
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                    Text(String(format: "Power Flow: %.1f Watts", telemetry.battery.liveWatts))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)

                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(String(format: "Voltage: %.2f V", telemetry.battery.voltageVolts))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)

                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text(String(format: "Temp: %.1f °C", telemetry.battery.temperatureCelsius))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)

                Spacer()
            }

            Divider().opacity(0.4)

            VStack(spacing: 10) {
                // Auto-dimming Toggle
                Toggle(isOn: $service.isBatterySaverEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto-Dim Keyboard on Battery Power")
                            .font(.system(size: 12, weight: .medium))
                        Text("Automatically reduces keyboard lighting to 33% when unplugged from AC adapter.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))

                Divider().opacity(0.4)

                // Battery Charging & Health Policy
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Autonomous Power Management")
                            .font(.system(size: 12, weight: .medium))
                        Text("Lithium-ion charging curves and trickle thresholds are managed directly by hardware ACPI battery firmware.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Hardware ACPI Active")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
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

// MARK: - 4. GameVisual Display Calibration

struct GameVisualDisplayGroup: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Display Calibration & GameVisual", systemImage: "display")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.cyan)

            HStack(spacing: 8) {
                ForEach(ROGDisplayProfile.allCases) { profile in
                    DisplayProfileTile(
                        profile: profile,
                        isSelected: (telemetry.activeDisplayProfile == profile)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            telemetry.setDisplayProfile(profile)
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

struct DisplayProfileTile: View {
    let profile: ROGDisplayProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.cyan : Color(NSColor.controlColor).opacity(0.8))
                        .frame(width: 32, height: 32)

                    Image(systemName: profile.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }

                Text(profile.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan.opacity(0.8) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
