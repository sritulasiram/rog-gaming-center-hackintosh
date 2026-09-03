import SwiftUI
import Cocoa

// MARK: - Navigation Tabs

public enum ROGNavTab: Int, CaseIterable, Identifiable {
    case dashboard = 0
    case auraStudio = 1
    case powerFan = 2
    case hackintoshTools = 3
    case settings = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .auraStudio: return "Aura Core"
        case .powerFan: return "Power & Fans"
        case .hackintoshTools: return "Hackintosh Tools"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .dashboard: return "gauge.with.needle.fill"
        case .auraStudio: return "sparkles"
        case .powerFan: return "fanblades.fill"
        case .hackintoshTools: return "wrench.and.screwdriver.fill"
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
                // 1. Native Apple-Style Sidebar
                SidebarNav(selectedTab: $selectedTab)
                    .frame(width: 220)

                Divider()
                    .background(Color(NSColor.separatorColor).opacity(0.4))

                // 2. Main Content Canvas
                VStack(spacing: 0) {
                    MainHeaderBar(selectedTab: selectedTab)

                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView()
                        case .auraStudio:
                            AuraStudioView()
                        case .powerFan:
                            PowerFanView()
                        case .hackintoshTools:
                            HackintoshToolsView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }
}

// MARK: - Apple-Native Sidebar Navigation

struct SidebarNav: View {
    @ObservedObject var service = AuraService.shared
    @Binding var selectedTab: ROGNavTab

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // Top App Identity (positioned below traffic lights)
                HStack(spacing: 8) {
                    ROGLogoView(size: 20)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("ROG Gaming Center")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        Text("macOS Control")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 32) // Precise clearance under window traffic light buttons
                .padding(.bottom, 12)

                // Navigation Items List (Clean Apple Native Style)
                VStack(spacing: 3) {
                    ForEach(ROGNavTab.allCases) { tab in
                        SidebarNavButton(tab: tab, isSelected: (selectedTab == tab)) {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                selectedTab = tab
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // If permission is denied by macOS, show a compact alert
                if service.permissionDenied {
                    Button(action: { service.openInputMonitoringSettings() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Grant Access")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

struct SidebarNavButton: View {
    let tab: ROGNavTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Clean SF Symbol without colored square box
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 18, height: 18)

                Text(tab.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main Header Bar

struct MainHeaderBar: View {
    let selectedTab: ROGNavTab

    var body: some View {
        HStack(alignment: .center) {
            Text(selectedTab.title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }
}

