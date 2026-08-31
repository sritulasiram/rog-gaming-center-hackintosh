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
        case .auraStudio: return "Aura RGB Studio"
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

                    Divider()
                        .background(Color(NSColor.separatorColor).opacity(0.3))

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
                        Text("ROG Center")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)

                        Text("macOS Control")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 42) // Precise clearance under window traffic light buttons
                .padding(.bottom, 14)

                // Section Label
                Text("FAVORITES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                // Navigation Items List (Clean Apple Finder / Settings style)
                VStack(spacing: 2) {
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

                // Bottom Hardware Controller Status Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(service.isConnected ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)

                        Text(service.isConnected ? "ITE 8910 Connected" : "Controller Standby")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    Text(service.statusMessage)
                        .font(.system(size: 9))
                        .foregroundColor(service.permissionDenied ? .orange : .secondary)
                        .lineLimit(2)

                    if service.permissionDenied {
                        Button(action: { service.openInputMonitoringSettings() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield")
                                Text("Grant Input Monitoring Access")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.orange.opacity(0.18))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.6), lineWidth: 0.5)
                        )
                    }

                    HStack(spacing: 6) {
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
                        )

                        Button(action: { service.togglePower() }) {
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(service.isPoweredOn ? .green : .red)
                                .padding(5)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color(NSColor.controlColor).opacity(0.8))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
                        )
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                )
                .padding(10)
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
    @ObservedObject var service = AuraService.shared

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

    var body: some View {
        HStack(alignment: .center) {
            Text(selectedTab.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // Quick Status Capsule
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(service.isPoweredOn ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)

                    Text("Backlight: \(brightnessString)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 12)

                Text(service.activePresetId.capitalized.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 38) // Align with window titlebar baseline
        .padding(.bottom, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
    }
}

