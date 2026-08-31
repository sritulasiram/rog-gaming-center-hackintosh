import SwiftUI
import Cocoa

// MARK: - macOS Tahoe Liquid Glass Menu Bar Companion

public struct AuraPopoverView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared
    @State private var isSpinning: Bool = false

    public init() {}

    private var brightnessString: String {
        if !service.isPoweredOn || service.currentBrightness == 0 {
            return "Off"
        }
        switch service.currentBrightness {
        case 3: return "100%"
        case 2: return "66%"
        case 1: return "33%"
        default: return "\(service.currentBrightness * 33)%"
        }
    }

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow, state: .active)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {
                // 1. Header: Liquid Glass App Title & Power Orb
                HStack(spacing: 8) {
                    ROGLogoView(size: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("ROG Gaming Center")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(service.isConnected ? Color.green : Color.orange)
                                .frame(width: 5, height: 5)

                            Text(service.isConnected ? "Hardware Online • ITE 8910" : "Controller Standby")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Sleek Circular Liquid Power Orb (No Clunky Box)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            service.togglePower()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(service.isPoweredOn ? Color(red: 0.1, green: 0.8, blue: 0.4).opacity(0.18) : Color.secondary.opacity(0.12))
                                .frame(width: 26, height: 26)

                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(service.isPoweredOn ? Color(red: 0.1, green: 0.85, blue: 0.45) : .secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Toggle Backlight Power")
                }

                // 2. Dual-Vitals Bento Grid (Fans + Battery)
                HStack(spacing: 8) {
                    // Fan & Thermal Bento Card
                    HStack(spacing: 8) {
                        Image(systemName: "fanblades.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(telemetry.fan.cpuFanRPM) RPM")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)

                            Text("CPU \(telemetry.fan.cpuTempCelsius)°C • GPU \(telemetry.fan.gpuTempCelsius)°C")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                    )

                    // Battery & Power Bento Card
                    HStack(spacing: 8) {
                        Image(systemName: telemetry.battery.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 14))
                            .foregroundColor(telemetry.battery.isCharging ? .green : .blue)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(telemetry.battery.currentCapacity)%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)

                            Text(telemetry.battery.isACConnected ? "AC Adapter • \(Int(telemetry.battery.liveWatts))W" : "Battery Mode")
                                .font(.system(size: 8.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                    )
                }

                // 3. Control Center Keyboard Brightness Capsule Slider
                VStack(spacing: 5) {
                    HStack {
                        Text("KEYBOARD ILLUMINATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))

                        Spacer()

                        Text(brightnessString)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(service.isPoweredOn ? .primary : .secondary)
                    }

                    // Interactive Capsule Slider Track
                    HStack(spacing: 8) {
                        Image(systemName: service.isPoweredOn ? "sun.max.fill" : "sun.min")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(service.isPoweredOn ? .primary : .secondary)
                            .frame(width: 14)

                        Slider(
                            value: Binding(
                                get: { Double(service.isPoweredOn ? service.currentBrightness : 0) },
                                set: { val in service.setBrightness(Int(val.rounded())) }
                            ),
                            in: 0...3,
                            step: 1
                        )
                        .accentColor(.blue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                    )
                }

                // 4. Performance Profile 3-Way Segmented Control
                VStack(alignment: .leading, spacing: 4) {
                    Text("PERFORMANCE PROFILE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))

                    HStack(spacing: 2) {
                        ForEach(ROGPerformanceProfile.allCases) { profile in
                            PopoverProfileButton(
                                profile: profile,
                                isSelected: telemetry.activeProfile == profile
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    telemetry.setPerformanceProfile(profile)
                                }
                            }
                        }
                    }
                    .padding(2)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
                    )
                }

                // 5. Aura RGB Presets Row (Clean Chips, Zero Color Code Strings)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("AURA RGB PRESETS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))

                        Spacer()

                        Text(service.activePresetId.capitalized.replacingOccurrences(of: "_", with: " "))
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        ForEach(AuraPreset.builtInPresets.prefix(4)) { preset in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    service.applyPreset(preset)
                                }
                            }) {
                                Text(preset.name.components(separatedBy: " ").first ?? preset.name)
                                    .font(.system(size: 9.5, weight: service.activePresetId == preset.id ? .semibold : .regular))
                                    .foregroundColor(service.activePresetId == preset.id ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(service.activePresetId == preset.id ? Color.blue : Color(NSColor.controlColor).opacity(0.5))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                Divider()
                    .background(Color(NSColor.separatorColor).opacity(0.3))

                // 6. Footer Actions: Re-Sync & Open Full Center
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) { isSpinning = true }
                        service.forceHardwareResync()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isSpinning = false }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                            Text("Re-Sync")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        AppDelegate.shared?.showMainWindow()
                    }) {
                        HStack(spacing: 4) {
                            Text("Open Center")
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(12)
            .frame(width: 290)
        }
    }
}

// MARK: - Popover Profile Button

struct PopoverProfileButton: View {
    let profile: ROGPerformanceProfile
    let isSelected: Bool
    let action: () -> Void

    private var activeColor: Color {
        switch profile {
        case .silent: return Color(red: 0.08, green: 0.72, blue: 0.45)
        case .balanced: return Color.blue
        case .turbo: return Color(red: 0.92, green: 0.08, blue: 0.18)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(profile.title.components(separatedBy: " ").first ?? profile.title)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? activeColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

