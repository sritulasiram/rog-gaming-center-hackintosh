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

                // 2. Performance & Power Modes
                PerformanceProfilesGroup()

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
                Label("Dual Fan Acoustics & Thermal Management", systemImage: "fanblades.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(telemetry.fan.acousticDecibels) dB (Acoustics)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Dual Fan Tachometers
            HStack(spacing: 12) {
                // CPU Fan Card
                FanTachometerTile(
                    title: "CPU Cooling Fan",
                    rpm: telemetry.fan.cpuFanRPM,
                    maxRPM: telemetry.fan.maxFanRPM,
                    tempCelsius: telemetry.fan.cpuTempCelsius,
                    tintColor: .blue
                )

                // GPU Fan Card
                FanTachometerTile(
                    title: "GPU Cooling Fan",
                    rpm: telemetry.fan.gpuFanRPM,
                    maxRPM: telemetry.fan.maxFanRPM,
                    tempCelsius: telemetry.fan.gpuTempCelsius,
                    tintColor: .purple
                )
            }

            Divider().opacity(0.4)

            // Fan Profile Mode Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Fan Overboost & Acoustic Profile")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    ForEach(ROGFanMode.allCases) { mode in
                        FanModePillButton(
                            mode: mode,
                            isSelected: telemetry.fan.fanMode == mode
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                telemetry.setFanMode(mode)
                            }
                        }
                    }
                }
            }

            // Manual Slider if in Manual Mode
            if telemetry.fan.fanMode == .manual {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Manual Fan Duty Cycle")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(telemetry.fan.manualSpeedPercent))% (\(telemetry.fan.cpuFanRPM) RPM)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }

                    Slider(
                        value: Binding(
                            get: { telemetry.fan.manualSpeedPercent },
                            set: { telemetry.setManualFanSpeed($0) }
                        ),
                        in: 20...100,
                        step: 5
                    )
                    .accentColor(.blue)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
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

struct FanTachometerTile: View {
    let title: String
    let rpm: Int
    let maxRPM: Int
    let tempCelsius: Int
    let tintColor: Color

    var progress: Double {
        max(0.0, min(1.0, Double(rpm) / Double(maxRPM)))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                    .frame(width: 44, height: 44)

                // Progress Fill
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "fanblades.fill")
                    .font(.system(size: 16))
                    .foregroundColor(tintColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Text("\(rpm)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("RPM")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 10))
                        Text("\(tempCelsius)°C")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(tempCelsius > 75 ? .red : (tempCelsius > 60 ? .orange : .green))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }
}

struct FanModePillButton: View {
    let mode: ROGFanMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(mode.title.components(separatedBy: " ").first ?? mode.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 2. Performance Profiles Group

struct PerformanceProfilesGroup: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Power & Performance Profiles", systemImage: "flame")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)

            VStack(spacing: 6) {
                ForEach(ROGPerformanceProfile.allCases) { profile in
                    ProfileSelectionRow(
                        profile: profile,
                        isSelected: (telemetry.activeProfile == profile)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            telemetry.setPerformanceProfile(profile)
                        }
                    }
                }
            }

            Divider().opacity(0.4)

            // Active Behavior Explainer Footnote
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(activeDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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

    private var activeDescription: String {
        switch telemetry.activeProfile {
        case .silent:
            return "Silent Mode limits CPU thermal targets and lowers fan RPM for whisper-quiet acoustics."
        case .balanced:
            return "Balanced Mode dynamically balances CPU clock frequencies and acoustic fan curves."
        case .turbo:
            return "Turbo Mode uncaps power limits (PL1/PL2) for maximum sustained compute performance and aggressive cooling."
        }
    }
}

struct ProfileSelectionRow: View {
    let profile: ROGPerformanceProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.8))
                        .frame(width: 32, height: 32)

                    Image(systemName: profile.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)

                    Text(profile.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .blue : .secondary.opacity(0.3))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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

                // Battery Care Mode (Charge Limit)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Maximum Battery Charge Limit (Care Mode)")
                                .font(.system(size: 12, weight: .medium))
                            Text("Limits maximum charging level on AC power to prolong lithium-ion battery lifespan.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 8) {
                        ChargeLimitPillButton(title: "60% (Max Lifespan)", limit: 60, current: telemetry.batteryChargeLimit) {
                            telemetry.setBatteryChargeLimit(60)
                        }
                        ChargeLimitPillButton(title: "80% (Balanced)", limit: 80, current: telemetry.batteryChargeLimit) {
                            telemetry.setBatteryChargeLimit(80)
                        }
                        ChargeLimitPillButton(title: "100% (Full Capacity)", limit: 100, current: telemetry.batteryChargeLimit) {
                            telemetry.setBatteryChargeLimit(100)
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

struct ChargeLimitPillButton: View {
    let title: String
    let limit: Int
    let current: Int
    let action: () -> Void

    var isSelected: Bool { limit == current }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(limit)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)

                Text(title.components(separatedBy: " ").dropFirst().joined(separator: " "))
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.green : Color(NSColor.controlColor).opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
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
