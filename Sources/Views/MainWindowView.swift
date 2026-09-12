import SwiftUI
import Cocoa

// MARK: - Navigation Tabs

public enum ROGNavTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case auraStudio = 1
    case gameVisual = 2
    case settings = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .auraStudio: return "Aura Core"
        case .gameVisual: return "GameVisual"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .dashboard: return "gauge.with.needle.fill"
        case .auraStudio: return "sparkles"
        case .gameVisual: return "eye.fill"
        case .settings: return "gearshape.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .dashboard: return Color(red: 0.92, green: 0.16, blue: 0.20)   // ROG Crimson Red
        case .auraStudio: return Color(red: 0.68, green: 0.34, blue: 0.96)  // Aura Chromatic Purple
        case .gameVisual: return Color(red: 0.00, green: 0.68, blue: 1.00)  // GameVisual Vision Cyan
        case .settings: return Color(red: 1.00, green: 0.58, blue: 0.00)    // System Settings Amber
        }
    }
}

// MARK: - Glassmorphic Blur Backdrop

public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .underWindowBackground
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active

    public init(
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Native Window Drag Area (AppKit Window Movement)

public struct WindowDragAreaView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> WindowDragView {
        WindowDragView()
    }

    public func updateNSView(_ nsView: WindowDragView, context: Context) {}
}

public final class WindowDragView: NSView {
    public override var mouseDownCanMoveWindow: Bool {
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.zoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Main Application Window View (Top Navigation Architecture)

public struct MainWindowView: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared
    @State private var selectedTab: ROGNavTab = .dashboard

    public init() {}

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // 1. Unified Top Navigation Toolbar (Exact 52pt Height across all tabs, transparent background with window dragging)
                TopNavigationToolbar(selectedTab: $selectedTab)
                    .frame(height: 52)
                    .background(WindowDragAreaView())

                Divider()
                    .background(ROGColor.hairline)

                // Permission Warning Banner if Input Monitoring is denied
                if service.permissionDenied {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ROGColor.warn)
                            .font(.system(size: 12))

                        Text("Input Monitoring access is required for keyboard RGB control.")
                            .font(ROGType.caption())
                            .foregroundStyle(.primary)

                        Spacer()

                        Button("Grant Access") {
                            service.openInputMonitoringSettings()
                        }
                        .font(ROGType.caption())
                        .buttonStyle(BorderedProminentButtonStyle())
                        .tint(ROGColor.warn)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(ROGColor.warn.opacity(0.12))

                    Divider()
                        .background(ROGColor.hairline)
                }

                // 2. Full-Width Main Content Canvas (Reclaims 244pt width)
                Group {
                    switch selectedTab {
                    case .dashboard:
                        DashboardView()
                    case .auraStudio:
                        AuraStudioView()
                    case .gameVisual:
                        GameVisualView()
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }
}

// MARK: - Unified Top Navigation Toolbar

struct TopNavigationToolbar: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared
    @Binding var selectedTab: ROGNavTab

    var body: some View {
        HStack(spacing: 0) {
            // 1. Leading: Traffic Lights Clearance + App Brand Identity
            HStack(spacing: 11) {
                ROGLogoView(size: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text("ROG Gaming Center")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(tabSubtitle(for: selectedTab))
                        .font(ROGType.footnote())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.leading, 18)
            .fixedSize(horizontal: true, vertical: false)
            .allowsHitTesting(false) // Allows window dragging directly over brand identity

            Spacer(minLength: 24)

            // 2. Trailing Controls Group: Segmented Capsule Navigation + Circular Action Frame
            HStack(spacing: 10) {
                // Segmented Capsule Navigation (Content-Based Accents & Zero Separators)
                HStack(spacing: 2) {
                    ForEach(ROGNavTab.allCases) { tab in
                        TopNavSegmentButton(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(2.5)
                .background(
                    Capsule()
                        .fill(Color(white: 1.0, opacity: 0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(white: 1.0, opacity: 0.14), lineWidth: 0.5)
                )
                .fixedSize(horizontal: true, vertical: false)

                // Fixed-Size Circular Action Frame
                CircularHeaderAction(selectedTab: selectedTab)
            }
            .padding(.trailing, 20)
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 52)
    }

    private func tabSubtitle(for tab: ROGNavTab) -> String {
        switch tab {
        case .dashboard: return "Hardware Telemetry & Vitality"
        case .auraStudio: return "Hardware Backlight Studio"
        case .gameVisual: return "CoreGraphics LUT Calibration"
        case .settings: return "Preferences & System Daemon"
        }
    }
}

// MARK: - Top Navigation Segment Button (Content-Based Accents)

struct TopNavSegmentButton: View {
    let tab: ROGNavTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? tab.accentColor : (isHovering ? .primary : Color.white.opacity(0.65)))

                Text(tab.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : (isHovering ? .primary : Color.white.opacity(0.65)))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(tab.accentColor.opacity(0.24))
                            .overlay(
                                Capsule()
                                    .stroke(tab.accentColor.opacity(0.55), lineWidth: 0.5)
                            )
                            .shadow(color: tab.accentColor.opacity(0.30), radius: 3, y: 1)
                    } else if isHovering {
                        Capsule()
                            .fill(Color(white: 1.0, opacity: 0.06))
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Trailing Circular Action Frame (Zero Jitter, Fixed 28x28pt)

struct CircularHeaderAction: View {
    @ObservedObject var service = AuraService.shared
    @ObservedObject var telemetry = TelemetryService.shared
    let selectedTab: ROGNavTab

    var body: some View {
        Group {
            switch selectedTab {
            case .dashboard:
                Button(action: {
                    telemetry.refreshTelemetry()
                }) {
                    CircularActionBadge(
                        icon: "arrow.triangle.2.circlepath",
                        tintColor: selectedTab.accentColor,
                        tooltip: "Refresh Live Hardware Telemetry"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)

            case .auraStudio:
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        service.togglePower()
                    }
                }) {
                    CircularActionBadge(
                        icon: "power",
                        tintColor: service.isPoweredOn ? ROGColor.good : selectedTab.accentColor,
                        isActive: service.isPoweredOn,
                        tooltip: service.isPoweredOn ? "Turn Backlight Off" : "Turn Backlight On"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)

            case .gameVisual:
                Button(action: {
                    telemetry.setDisplayProfile(.standard)
                }) {
                    CircularActionBadge(
                        icon: "arrow.counterclockwise",
                        tintColor: selectedTab.accentColor,
                        tooltip: "Reset Display Gamma to Factory Standard"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)

            case .settings:
                Button(action: {
                    if let url = URL(string: "https://github.com/sritulasiram/rog-gaming-center-hackintosh") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    CircularActionBadge(
                        icon: "safari",
                        tintColor: selectedTab.accentColor,
                        tooltip: "Open GitHub Repository"
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Perfectly Centered Circular Action Badge

struct CircularActionBadge: View {
    let icon: String
    var tintColor: Color = .primary
    var isActive: Bool = false
    let tooltip: String
    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .center) {
            Circle()
                .fill(Color(white: 1.0, opacity: isHovering ? 0.12 : 0.08))

            Circle()
                .stroke(Color(white: 1.0, opacity: 0.14), lineWidth: 0.5)

            Image(systemName: icon)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(tintColor)
        }
        .frame(width: 28, height: 28)
        .shadow(color: Color.black.opacity(0.15), radius: 2, y: 1)
        .help(tooltip)
        .onHover { isHovering = $0 }
    }
}
