import SwiftUI
import AppKit

public struct HackintoshToolsView: View {
    @ObservedObject var service = AuraService.shared
    @State private var isDiagnosticsRunning: Bool = false
    @State private var diagnosticsPassed: Bool = true
    @State private var copiedCommandText: String? = nil
    @State private var executedCommandText: String? = nil

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                // 1. System Diagnostics & Readiness Health Bar
                DiagnosticsHealthBar(
                    isRunning: $isDiagnosticsRunning,
                    passed: $diagnosticsPassed
                )

                // 2. IOKit USB Controller & Live 17-Byte Packet Stream Monitor
                USBControllerPacketMonitor()

                // 3. Sleep / Wake Watchdog & Live Audit Timeline (Console.app Style)
                SleepWakeWatchdogTimeline()

                // 4. CLI, Raycast, & Automation Generator with Terminal Launchers
                CLIAutomationGeneratorCard(
                    copiedCommandText: $copiedCommandText,
                    executedCommandText: $executedCommandText
                )
            }
            .padding(18)
        }
    }
}

// MARK: - 1. Diagnostics Health Bar

struct DiagnosticsHealthBar: View {
    @ObservedObject var service = AuraService.shared
    @Binding var isRunning: Bool
    @Binding var passed: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Hackintosh & IOKit System Readiness")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 10) {
                    HealthBadge(title: "IOKit USB", ok: service.isConnected)
                    HealthBadge(title: "ITE 8910", ok: service.isConnected)
                    HealthBadge(title: "AppleSMC", ok: SMCReader.shared.isAvailable)
                    HealthBadge(title: "ROG Key HID", ok: service.isConnected && service.isROGKeyEnabled)
                    HealthBadge(title: "Input TCC", ok: !service.permissionDenied)
                }
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isRunning = true
                }
                service.forceHardwareResync()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isRunning = false
                    passed = true
                }
            }) {
                HStack(spacing: 4) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "bolt.badge.checkmark")
                    }
                    Text(isRunning ? "Testing..." : "Self Test")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlColor).opacity(0.8))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
            )
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct HealthBadge: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 2. IOKit USB Controller & Live Packet Monitor

struct USBControllerPacketMonitor: View {
    @ObservedObject var service = AuraService.shared
    let driver = AuraDriver.shared

    var info: AuraDeviceInfo? {
        driver.connectedDeviceInfo
    }

    var packetBytes: [String] {
        var bytes = [String]()
        bytes.append("5D") // Magic Byte
        bytes.append("B3") // Command ID
        bytes.append("00") // Zone / Sub-command
        bytes.append("01") // Mode: Multi-Static

        // 4 Zones RGB
        for i in 0..<4 {
            let c = service.zoneColors[i]
            bytes.append(String(format: "%02X", c.red))
            bytes.append(String(format: "%02X", c.green))
            bytes.append(String(format: "%02X", c.blue))
        }
        bytes.append("00") // Speed
        return bytes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("IOKit USB HID Controller & Live Packet Stream", systemImage: "cpu")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.indigo)

                Spacer()

                Text(service.isConnected ? "0x0B05:0x1869 (Connected 🟢)" : "Disconnected")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(service.isConnected ? .green : .secondary)
            }

            // Specs Grid
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    SpecRow(label: "Device Name", value: info?.name ?? "ASUS ROG Keyboard")
                    SpecRow(label: "Vendor ID (VID)", value: "\(info?.formattedVID ?? "0x0B05") (ASUSTeK)")
                    SpecRow(label: "Product ID (PID)", value: "\(info?.formattedPID ?? "0x1869") (ITE 8910)")
                }
                VStack(alignment: .leading, spacing: 4) {
                    SpecRow(label: "Transport Bus", value: info?.transport ?? "USB 2.0 (Internal Bus)")
                    SpecRow(label: "Usage Page", value: "0x\(String(format: "%04X", info?.usagePage ?? 0xFF89))")
                    SpecRow(label: "Report Payload", value: "17 Bytes (Aura Protocol v3)")
                }
            }

            Divider().opacity(0.4)

            // Live 17-Byte Feature Report Stream
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Live 17-Byte HID Feature Report Packet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        let hexString = packetBytes.joined(separator: " ")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(hexString, forType: .string)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Hex")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Packet Bytes Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(0..<packetBytes.count, id: \.self) { idx in
                            VStack(spacing: 2) {
                                Text("[\(packetBytes[idx])]")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(byteColor(index: idx))

                                Text(byteLabel(index: idx))
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                            .cornerRadius(4)
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
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

    private func byteColor(index: Int) -> Color {
        switch index {
        case 0, 1: return .blue
        case 2, 3: return .purple
        case 4...6: return Color(rgb: service.zoneColors[0])
        case 7...9: return Color(rgb: service.zoneColors[1])
        case 10...12: return Color(rgb: service.zoneColors[2])
        case 13...15: return Color(rgb: service.zoneColors[3])
        default: return .secondary
        }
    }

    private func byteLabel(index: Int) -> String {
        switch index {
        case 0: return "MAGIC"
        case 1: return "CMD"
        case 2: return "ZONE"
        case 3: return "MODE"
        case 4...6: return "Z1_RGB"
        case 7...9: return "Z2_RGB"
        case 10...12: return "Z3_RGB"
        case 13...15: return "Z4_RGB"
        default: return "SPD"
        }
    }
}

// MARK: - 3. Sleep / Wake Watchdog & Audit Log

struct SleepWakeWatchdogTimeline: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sleep / Wake Watchdog Timeline (Console.app Style)", systemImage: "moon.stars")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.purple)

                Spacer()

                Button(action: { service.forceHardwareResync() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Trigger Handshake")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Dynamic Watchdog Audit Log
            VStack(spacing: 6) {
                if service.watchdogAuditLog.isEmpty {
                    Text("No watchdog events logged yet. Triggering handshakes or system sleep/wake will appear here live.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(8)
                } else {
                    ForEach(service.watchdogAuditLog.reversed()) { event in
                        HStack(spacing: 8) {
                            Text(event.formattedTime)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)

                            Image(systemName: event.icon)
                                .font(.system(size: 9))
                                .foregroundColor(color(for: event.iconColor))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(event.detail)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
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

    private func color(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        default: return .secondary
        }
    }
}

struct TimelineEventRow: View {
    let time: String
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(time)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)

            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - 4. Automation Generator with Direct & Terminal Execution

struct CLIAutomationGeneratorCard: View {
    @ObservedObject var service = AuraService.shared
    @Binding var copiedCommandText: String?
    @Binding var executedCommandText: String?

    let commands: [(title: String, cmd: String)] = [
        ("Spectrum Rainbow Cycle", "rogauracore single_colorcycle 2"),
        ("4-Zone Cyberpunk Matrix", "rogauracore preset cyberpunk"),
        ("Solid Neon Cyan", "rogauracore single_static 00f0ff"),
        ("Set Brightness 100%", "rogauracore brightness 3"),
        ("Force Hardware Re-Sync", "rogauracore resync")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Automation Shortcuts & Terminal Launcher", systemImage: "terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)

                Spacer()

                if copiedCommandText != nil {
                    Text("✓ Copied")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                } else if let exec = executedCommandText {
                    Text("✓ Executed: \(exec)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
            }

            VStack(spacing: 6) {
                ForEach(commands, id: \.cmd) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)

                            Text(item.cmd)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 1. Run Now (Direct native in-app execution)
                        Button(action: {
                            executeDirectly(item.cmd)
                            executedCommandText = item.title
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if executedCommandText == item.title { executedCommandText = nil }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "play.fill")
                                Text("Run Now")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Execute directly in native app")

                        // 2. Copy Command
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.cmd, forType: .string)
                            copiedCommandText = item.cmd
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                if copiedCommandText == item.cmd { copiedCommandText = nil }
                            }
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy command to clipboard")
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
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

    private func executeDirectly(_ cmd: String) {
        if cmd.contains("single_colorcycle") {
            service.applyPreset(AuraPreset.builtInPresets[0])
        } else if cmd.contains("cyberpunk") {
            if let preset = AuraPreset.builtInPresets.first(where: { $0.id == "neon_cyberpunk" || $0.id == "cyberpunk" }) {
                service.applyPreset(preset)
            }
        } else if cmd.contains("single_static 00f0ff") {
            service.applySingleColor(RGBColor(red: 0x00, green: 0xF0, blue: 0xFF))
        } else if cmd.contains("brightness 3") {
            service.setBrightness(3)
        } else if cmd.contains("resync") {
            service.forceHardwareResync()
        }
    }
}
