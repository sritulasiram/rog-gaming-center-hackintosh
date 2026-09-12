import SwiftUI
import ApplicationServices
import Cocoa

// MARK: - ROG GameVisual Display Calibration Center

public struct GameVisualView: View {
    @ObservedObject var telemetry = TelemetryService.shared
    @State private var showOriginalComparison: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // 1. Interactive Profile Selector Grid (6 Authentic ROG Modes)
                GameVisualProfileGrid(activeProfile: telemetry.activeDisplayProfile) { profile in
                    telemetry.setDisplayProfile(profile)
                }

                // 2. Live Visual Simulation & Comparison Stage
                GameVisualPreviewStage(
                    activeProfile: telemetry.activeDisplayProfile,
                    showOriginal: $showOriginalComparison
                )

                // 3. Hardware CoreGraphics LUT Calibration Architecture Card
                GameVisualHardwareCard(activeProfile: telemetry.activeDisplayProfile)
            }
            .padding(18)
        }
    }
}



// MARK: - 1. Profile Grid

struct GameVisualProfileGrid: View {
    let activeProfile: ROGDisplayProfile
    let onSelect: (ROGDisplayProfile) -> Void

    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Display Color Calibration Profiles", systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.blue)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ROGDisplayProfile.allCases) { profile in
                    ProfileCard(
                        profile: profile,
                        isSelected: activeProfile == profile,
                        action: { onSelect(profile) }
                    )
                }
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

struct ProfileCard: View {
    let profile: ROGDisplayProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.8))
                            .frame(width: 28, height: 28)

                        Image(systemName: profile.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)

                    Text(profileDescription(profile))
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(height: 24, alignment: .topLeading)
                }

                // Color Tone Indicator Bar
                LinearGradient(
                    colors: profileGradient(profile),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                .cornerRadius(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color(NSColor.controlColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color(NSColor.separatorColor).opacity(0.4), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func profileDescription(_ p: ROGDisplayProfile) -> String {
        switch p {
        case .standard: return "True neutral sRGB factory gamma transfer curve."
        case .vividGaming: return "Punchy midtones and boosted color saturation."
        case .eyeCare: return "Soft warm tone, attenuates 450nm blue light spikes."
        case .cinema: return "Enriched low-mids and deep dynamic black levels."
        case .fps: return "Lifts shadow detail to reveal hidden enemies in the dark."
        case .rts: return "Sharpened contrast and vivid saturation for fantasy maps."
        }
    }

    private func profileGradient(_ p: ROGDisplayProfile) -> [Color] {
        switch p {
        case .standard: return [.gray.opacity(0.5), .blue.opacity(0.6)]
        case .vividGaming: return [.pink, .purple, .cyan]
        case .eyeCare: return [.orange, .yellow]
        case .cinema: return [.indigo, .blue, .purple]
        case .fps: return [.cyan, .green]
        case .rts: return [.green, .yellow, .orange]
        }
    }
}

// MARK: - 3. Live Visual Simulation & Comparison Stage

struct GameVisualPreviewStage: View {
    let activeProfile: ROGDisplayProfile
    @Binding var showOriginal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Real-Time Visual Simulation", systemImage: "sparkles.tv")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)

                Spacer()

                // A/B Comparison Switch
                HStack(spacing: 6) {
                    Text("Baseline")
                        .font(.system(size: 10, weight: showOriginal ? .bold : .regular))
                        .foregroundColor(showOriginal ? .primary : .secondary)

                    Toggle("", isOn: Binding(
                        get: { !showOriginal },
                        set: { showOriginal = !$0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()

                    Text(activeProfile.title)
                        .font(.system(size: 10, weight: !showOriginal ? .bold : .regular))
                        .foregroundColor(!showOriginal ? .blue : .secondary)
                }
            }

            // Simulated Game Scene Canvas
            ZStack {
                // Background Sky
                LinearGradient(
                    colors: skyColors,
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Distant Mountain Ridges
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height * 0.7))
                        p.addLine(to: CGPoint(x: geo.size.width * 0.25, y: geo.size.height * 0.45))
                        p.addLine(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.65))
                        p.addLine(to: CGPoint(x: geo.size.width * 0.75, y: geo.size.height * 0.35))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.6))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: mountainColors,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Foreground Grid / Terrain
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height * 0.75))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 0.75))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(Color.black.opacity(showOriginal ? 0.65 : (activeProfile == .fps ? 0.35 : 0.7)))
                }

                // Center Sun / Cyber Orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: sunColors),
                            center: .center,
                            startRadius: 2,
                            endRadius: 36
                        )
                    )
                    .frame(width: 72, height: 72)
                    .offset(y: -18)

                // Overlay Badge with Active Status
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Circle()
                                .fill(showOriginal ? Color.secondary : Color.green)
                                .frame(width: 6, height: 6)

                            Text(showOriginal ? "Native Uncalibrated Baseline" : "GameVisual: \(activeProfile.title)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                    }
                    .padding(10)

                    Spacer()
                }
            }
            .frame(height: 140)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private var skyColors: [Color] {
        if showOriginal {
            return [Color.blue.opacity(0.4), Color.purple.opacity(0.3)]
        }
        switch activeProfile {
        case .standard: return [Color.blue.opacity(0.4), Color.purple.opacity(0.3)]
        case .vividGaming: return [Color.blue.opacity(0.7), Color.purple.opacity(0.7), Color.pink.opacity(0.4)]
        case .eyeCare: return [Color.orange.opacity(0.35), Color.yellow.opacity(0.25)]
        case .cinema: return [Color.indigo.opacity(0.8), Color.black.opacity(0.8)]
        case .fps: return [Color.teal.opacity(0.4), Color.cyan.opacity(0.3)]
        case .rts: return [Color.purple.opacity(0.6), Color.green.opacity(0.3)]
        }
    }

    private var mountainColors: [Color] {
        if showOriginal {
            return [Color.blue.opacity(0.3), Color.black.opacity(0.6)]
        }
        switch activeProfile {
        case .standard: return [Color.blue.opacity(0.3), Color.black.opacity(0.6)]
        case .vividGaming: return [Color.purple.opacity(0.6), Color.blue.opacity(0.8)]
        case .eyeCare: return [Color.orange.opacity(0.4), Color.brown.opacity(0.5)]
        case .cinema: return [Color.black.opacity(0.8), Color.indigo.opacity(0.9)]
        case .fps: return [Color.cyan.opacity(0.5), Color.blue.opacity(0.4)] // Lifted shadows
        case .rts: return [Color.green.opacity(0.5), Color.blue.opacity(0.7)]
        }
    }

    private var sunColors: [Color] {
        if showOriginal {
            return [.yellow, .orange.opacity(0.4), .clear]
        }
        switch activeProfile {
        case .standard: return [.yellow, .orange.opacity(0.4), .clear]
        case .vividGaming: return [.pink, .purple, .clear]
        case .eyeCare: return [.orange, .red.opacity(0.3), .clear]
        case .cinema: return [.cyan, .blue.opacity(0.3), .clear]
        case .fps: return [.white, .cyan.opacity(0.5), .clear]
        case .rts: return [.yellow, .green.opacity(0.4), .clear]
        }
    }
}

// MARK: - 4. Hardware Calibration Architecture Card

struct GameVisualHardwareCard: View {
    let activeProfile: ROGDisplayProfile
    private let cal = DisplayCalibrationService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Display Controller & Gamma Transfer Architecture", systemImage: "cpu")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.blue)

            Text("GameVisual profiles are written directly to macOS display driver hardware lookup tables (LUTs) via CoreGraphics CGSetDisplayTransferByTable. Adjustments operate natively at the GPU rasterization pipeline without consuming CPU cycles or requiring background filter daemons.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Divider().opacity(0.4)

            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "display")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Target Display:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Main (ID: \(cal.targetDisplayID))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }

                HStack(spacing: 6) {
                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Hardware LUT Capacity:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(cal.currentTableCapacity) Samples")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }

                Text("Hardware Direct • 0% CPU")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
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
