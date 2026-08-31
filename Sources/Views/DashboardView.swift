import SwiftUI
import AppKit

public struct DashboardView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // 1. Top Hero: System Identity & Power Profile Switcher
                DashboardHeroBanner()

                // 2. Telemetry Bento Grid (3 Cards: CPU, Memory, Power)
                HStack(spacing: 12) {
                    CPUTelemetryCard()
                    MemoryTelemetryCard()
                    BatteryTelemetryCard()
                }

                // 3. Bottom Modules: Keyboard Lighting HUD & Hardware Specs
                HStack(spacing: 12) {
                    KeyboardBacklightHUDCard()
                    HardwareSpecsCard()
                }
            }
            .padding(18)
        }
    }
}

// MARK: - 1. Top Hero: System Identity & Power Profile Switcher

struct DashboardHeroBanner: View {
    @ObservedObject var telemetry = TelemetryService.shared
    @ObservedObject var service = AuraService.shared

    private var cleanCPUName: String {
        let raw = telemetry.specs.cpuBrand
        return raw.replacingOccurrences(of: "(R)", with: "")
                  .replacingOccurrences(of: "(TM)", with: "")
                  .replacingOccurrences(of: "CPU", with: "")
                  .components(separatedBy: "@").first?
                  .trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    ROGLogoView(size: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("ASUS ROG Strix GL503GE")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)

                            Circle()
                                .fill(service.isConnected ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)

                            Text(service.isConnected ? "Hardware Online" : "Controller Standby")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            Text("\(cleanCPUName) • \(telemetry.specs.totalRAMGB) GB RAM")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))

                            HStack(spacing: 3) {
                                Image(systemName: "fanblades.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue)
                                Text("\(telemetry.fan.cpuFanRPM) RPM")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }

                            HStack(spacing: 3) {
                                Image(systemName: "thermometer.medium")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text("\(telemetry.fan.cpuTempCelsius)°C")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                Spacer()

                // 3-Way Segmented Profile Control
                HStack(spacing: 2) {
                    ForEach(ROGPerformanceProfile.allCases) { profile in
                        ProfileSegmentButton(
                            profile: profile,
                            isSelected: (telemetry.activeProfile == profile)
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                telemetry.setPerformanceProfile(profile)
                            }
                        }
                    }
                }
                .padding(3)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                )
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct ProfileSegmentButton: View {
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
            HStack(spacing: 5) {
                Image(systemName: profile.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)

                Text(profile.title.components(separatedBy: " ").first ?? profile.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? activeColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 2. Telemetry Bento Cards

// CPU Card with Live Sparkline Waveform
struct CPUTelemetryCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("CPU Load", systemImage: "cpu")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                Text("\(telemetry.specs.physicalCores)C / \(telemetry.specs.logicalThreads)T")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Text(String(format: "%.1f%%", telemetry.cpuLoad.totalUsagePercent))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Sparkline Graph
            SparklineView(data: telemetry.cpuHistory, tintColor: .blue)
                .frame(height: 38)

            Text("System: \(Int(telemetry.cpuLoad.systemPercent))% • User: \(Int(telemetry.cpuLoad.userPercent))%")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// Memory Card with Segmented Pressure Bar
struct MemoryTelemetryCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)

                Spacer()

                Text(String(format: "%.0f GB Total", telemetry.memory.totalGB))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Text(String(format: "%.1f GB", telemetry.memory.activeGB + telemetry.memory.wiredGB + telemetry.memory.compressedGB))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Apple Activity Monitor style memory allocation bar
            GeometryReader { geo in
                let total = max(1.0, telemetry.memory.totalGB)
                let activeW = CGFloat(telemetry.memory.activeGB / total) * geo.size.width
                let wiredW = CGFloat(telemetry.memory.wiredGB / total) * geo.size.width
                let compW = CGFloat(telemetry.memory.compressedGB / total) * geo.size.width

                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: max(2, activeW))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.1, green: 0.75, blue: 0.85))
                        .frame(width: max(2, wiredW))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.orange)
                        .frame(width: max(2, compW))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                }
            }
            .frame(height: 8)
            .padding(.vertical, 8)

            HStack(spacing: 8) {
                Circle().fill(Color.blue).frame(width: 5, height: 5)
                Text("App").font(.system(size: 9)).foregroundColor(.secondary)

                Circle().fill(Color(red: 0.1, green: 0.75, blue: 0.85)).frame(width: 5, height: 5)
                Text("Wired").font(.system(size: 9)).foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.0f%% Used", telemetry.memory.usedPercent))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// Battery & Power Card
struct BatteryTelemetryCard: View {
    @ObservedObject var telemetry = TelemetryService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Battery & Power", systemImage: telemetry.battery.isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(telemetry.battery.isCharging ? .green : (telemetry.battery.isACConnected ? .blue : .orange))

                Spacer()

                Text(telemetry.battery.isACConnected ? "AC Adapter" : "Battery")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Text("\(telemetry.battery.currentCapacity)%")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(telemetry.battery.isCharging ? Color.green : (telemetry.battery.isACConnected ? Color.blue : (telemetry.battery.currentCapacity > 20 ? Color.blue : Color.red)))
                        .frame(width: max(4, geo.size.width * CGFloat(telemetry.battery.currentCapacity) / 100.0), height: 8)
                }
            }
            .frame(height: 8)
            .padding(.vertical, 8)

            HStack {
                Text(telemetry.battery.isCharging ? String(format: "+%.1f W (AC Charging)", telemetry.battery.liveWatts) : (telemetry.battery.isACConnected ? String(format: "%.1f W (AC Adapter)", telemetry.battery.liveWatts) : String(format: "%.1f W (Battery)", telemetry.battery.liveWatts)))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Spacer()

                Text("Health: \(telemetry.battery.healthPercent)% (\(telemetry.battery.wearPercent)% Wear)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

// Sparkline Mini Waveform View
struct SparklineView: View {
    let data: [Double]
    let tintColor: Color

    var body: some View {
        GeometryReader { geo in
            let points = data.isEmpty ? [0.0] : data
            let maxVal = max(100.0, (points.max() ?? 100.0))
            let stepX = geo.size.width / CGFloat(max(1, points.count - 1))

            Path { path in
                for (index, val) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height - (CGFloat(val / maxVal) * geo.size.height)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(tintColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            // Subtle gradient area fill
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height))
                for (index, val) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geo.size.height - (CGFloat(val / maxVal) * geo.size.height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                path.closeSubpath()
            }
            .fill(LinearGradient(
                colors: [tintColor.opacity(0.25), tintColor.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}

// MARK: - 3. Bottom Modules: Keyboard Lighting HUD & Hardware Specs

struct KeyboardBacklightHUDCard: View {
    @ObservedObject var service = AuraService.shared

    private var brightnessString: String {
        if !service.isPoweredOn || service.currentBrightness == 0 {
            return "Turned Off"
        }
        switch service.currentBrightness {
        case 3: return "Active (100%)"
        case 2: return "Active (66%)"
        case 1: return "Active (33%)"
        default: return "Active (\(service.currentBrightness * 33)%)"
        }
    }

    private let zoneNames = ["WASD", "Center-L", "Center-R", "Numpad"]
    private let defaultSpectrum = [
        Color(red: 1.0, green: 0.0, blue: 0.5),   // Neon Pink
        Color(red: 0.55, green: 0.1, blue: 1.0),  // Purple
        Color(red: 0.0, green: 0.95, blue: 1.0),  // Cyan
        Color(red: 0.0, green: 0.5, blue: 1.0)    // Blue
    ]

    private func displayColor(for idx: Int) -> Color {
        guard service.isPoweredOn else { return Color.gray.opacity(0.3) }
        switch service.currentMode {
        case .colorCycle, .rainbow:
            return defaultSpectrum[min(idx, 3)]
        case .singleStatic(let c):
            return Color(rgb: c)
        case .multiStatic(let zones):
            return idx < zones.count ? Color(rgb: zones[idx]) : defaultSpectrum[idx]
        default:
            return idx < service.zoneColors.count ? Color(rgb: service.zoneColors[idx]) : defaultSpectrum[idx]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Keyboard Backlight", systemImage: "keyboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text(brightnessString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(service.isPoweredOn ? .green : .secondary)
            }

            // 4-Zone Orb Row with live RGB colors
            HStack(spacing: 8) {
                ForEach(0..<4) { idx in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(displayColor(for: idx))
                            .frame(width: 9, height: 9)
                            .shadow(color: service.isPoweredOn ? displayColor(for: idx).opacity(0.65) : Color.clear, radius: 4)

                        Text(zoneNames[idx])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
                }
            }

            HStack(spacing: 6) {
                Button(action: { service.togglePower() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text(service.isPoweredOn ? "Turn Off" : "Turn On")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(service.isPoweredOn ? .red : .green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(NSColor.controlColor).opacity(0.8))
                .cornerRadius(6)

                Button(action: { service.forceHardwareResync() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Re-Sync")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color(NSColor.controlColor).opacity(0.8))
                .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct HardwareSpecsCard: View {
    @ObservedObject var telemetry = TelemetryService.shared
    @ObservedObject var service = AuraService.shared

    private var cleanCPU: String {
        let raw = telemetry.specs.cpuBrand
        return raw.replacingOccurrences(of: "(R)", with: "")
                  .replacingOccurrences(of: "(TM)", with: "")
                  .replacingOccurrences(of: "CPU", with: "")
                  .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Hardware Specifications", systemImage: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()
            }

            VStack(spacing: 6) {
                SpecRow(label: "Processor", value: cleanCPU)
                SpecRow(label: "Memory", value: "\(telemetry.specs.totalRAMGB) GB RAM")
                SpecRow(label: "OS Version", value: telemetry.specs.osVersion)
                SpecRow(label: "Keyboard Controller", value: service.deviceName)
                SpecRow(label: "System Uptime", value: telemetry.specs.uptimeString)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }
}

struct SpecRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

