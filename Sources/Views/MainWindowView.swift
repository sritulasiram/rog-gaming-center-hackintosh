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

// MARK: - Main Application Window View

public struct MainWindowView: View {
    @ObservedObject var service = AuraService.shared
    @State private var selectedTab: ROGNavTab = .dashboard

    public init() {}

    public var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .edgesIgnoringSafeArea(.all)

            HStack(spacing: 0) {
                // 1. Apple-native, Tahoe-style glass sidebar
                SidebarNav(selectedTab: $selectedTab)
                    .frame(width: 232)

                // Vertical Divider between sidebar and main content (Apple HIG)
                Rectangle()
                    .fill(ROGColor.hairline)
                    .frame(width: 1)
                    .edgesIgnoringSafeArea(.vertical)

                // 2. Main Content Canvas
                VStack(spacing: 0) {
                    MainHeaderBar(selectedTab: selectedTab)

                    Divider()
                        .background(ROGColor.hairline)

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
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }
}

// MARK: - Apple-Native "Liquid Glass" Sidebar Navigation

struct SidebarNav: View {
    @ObservedObject var service = AuraService.shared
    @Binding var selectedTab: ROGNavTab

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // Top App Identity — Unified 52pt header bar, sitting alongside traffic lights
                HStack(spacing: 8) {
                    ROGLogoView(size: 18)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("ROG Gaming Center")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text("macOS Control")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.leading, 74) // clearance for macOS close/minimize/zoom traffic lights
                .padding(.trailing, 12)
                .frame(height: 52)

                Divider()
                    .background(ROGColor.hairline)

                // Navigation Items — floating capsule selection, Tahoe style
                VStack(spacing: 3) {
                    ForEach(ROGNavTab.allCases) { tab in
                        SidebarNavButton(tab: tab, isSelected: (selectedTab == tab)) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)

                Spacer()

                // If permission is denied by macOS, show a compact glass alert
                if service.permissionDenied {
                    Button(action: { service.openInputMonitoringSettings() }) {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(ROGColor.warn)
                                .font(.system(size: 12))
                            Text("Grant Access")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(ROGColor.warn.opacity(0.16))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

struct SidebarNavButton: View {
    let tab: ROGNavTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? ROGColor.accent : .secondary)
                    .frame(width: 18, height: 18)

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                    .fill(
                        isSelected
                            ? ROGColor.accentSoft
                            : (isHovering ? Color(NSColor.controlColor).opacity(0.35) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovering = $0 }
    }
}

// MARK: - Main Header Bar

struct MainHeaderBar: View {
    @ObservedObject var service = AuraService.shared
    let selectedTab: ROGNavTab

    var body: some View {
        HStack(alignment: .center) {
            Text(selectedTab.title)
                .font(ROGType.title())
                .foregroundStyle(.primary)

            Spacer()

            // Hardware Status Indicator (Apple Control Center style)
            HStack(spacing: 6) {
                Circle()
                    .fill(service.isConnected ? ROGColor.good : ROGColor.warn)
                    .frame(width: 6, height: 6)
                Text(service.isConnected ? "ITE 8910 Online" : "Controller Standby")
                    .font(ROGType.caption())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlColor).opacity(0.4))
            .cornerRadius(ROGRadius.control)
            .overlay(
                RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                    .stroke(ROGColor.hairline, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
    }
}
