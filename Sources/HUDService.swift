import Foundation
import Cocoa
import SwiftUI

/// On-Screen Display (OSD) Floating Capsule HUD for macOS Tahoe.
/// Renders modern, non-activating floating pill overlays with spring animations
/// when physical Fn hotkeys are pressed anywhere in the operating system.
public final class HUDService {
    public static let shared = HUDService()

    private var hudWindow: NSPanel?
    private var dismissTimer: Timer?
    private let hostingController = NSHostingController(rootView: HUDCapsuleContainer())

    private init() {
        setupHUDWindow()
    }

    private func setupHUDWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentViewController = hostingController
        self.hudWindow = panel
    }

    private func showHUD(state: HUDState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.hudWindow else { return }

            self.dismissTimer?.invalidate()
            HUDStateModel.shared.current = state

            // Position at bottom-center of the active screen (macOS Tahoe style)
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 125
                let y = screenFrame.minY + 90
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            panel.orderFrontRegardless()
            panel.alphaValue = 1.0

            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: false) { [weak self] _ in
                guard let self = self, let p = self.hudWindow else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.35
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    p.animator().alphaValue = 0.0
                }, completionHandler: {
                    p.orderOut(nil)
                })
            }
        }
    }

    // MARK: - Public Triggers

    public func showBacklightHUD(level: Int) {
        let percent: Int
        let icon: String
        switch level {
        case 3: percent = 100; icon = "keyboard.fill"
        case 2: percent = 66;  icon = "keyboard.fill"
        case 1: percent = 33;  icon = "keyboard.fill"
        default: percent = 0;  icon = "keyboard"
        }
        showHUD(state: .slider(icon: icon, title: "Keyboard Backlight", value: Double(percent) / 100.0, label: "\(percent)%"))
    }

    public func showPowerHUD(isOn: Bool) {
        showHUD(state: .toggle(
            icon: isOn ? "power.circle.fill" : "power.circle",
            iconColor: isOn ? .green : .red,
            text: isOn ? "Backlight Powered On" : "Backlight Powered Off"
        ))
    }

    public func showAuraModeHUD(modeName: String) {
        showHUD(state: .toggle(
            icon: "sparkles",
            iconColor: .purple,
            text: "Aura: \(modeName)"
        ))
    }

    public func showTouchpadHUD(isEnabled: Bool) {
        showHUD(state: .toggle(
            icon: isEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1.slash",
            iconColor: isEnabled ? .blue : .orange,
            text: isEnabled ? "TouchPad is enabled" : "TouchPad is disabled"
        ))
    }

    public func showVolumeHUD(percent: Int, isMuted: Bool) {
        let icon = isMuted ? "speaker.slash.fill" : (percent > 50 ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
        showHUD(state: .slider(
            icon: icon,
            title: isMuted ? "Muted" : "Volume",
            value: isMuted ? 0.0 : Double(percent) / 100.0,
            label: isMuted ? "Mute" : "\(percent)%"
        ))
    }

    public func showBrightnessHUD(percent: Int) {
        showHUD(state: .slider(
            icon: "sun.max.fill",
            title: "Display",
            value: Double(percent) / 100.0,
            label: "\(percent)%"
        ))
    }

    public func showMessage(icon: String, text: String, color: Color = .blue) {
        showHUD(state: .toggle(icon: icon, iconColor: color, text: text))
    }
}

// MARK: - HUD State & Models

public enum HUDState: Equatable {
    case slider(icon: String, title: String, value: Double, label: String)
    case toggle(icon: String, iconColor: Color, text: String)
}

final class HUDStateModel: ObservableObject {
    static let shared = HUDStateModel()
    @Published var current: HUDState = .toggle(icon: "keyboard", iconColor: .blue, text: "Aura Ready")
}

struct HUDCapsuleContainer: View {
    @ObservedObject var model = HUDStateModel.shared

    var body: some View {
        ZStack {
            // Glassmorphic Capsule Backdrop
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 6)

            switch model.current {
            case .slider(let icon, _, let value, let label):
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 20)

                    // Continuous Progress Capsule
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(height: 6)

                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(6, geo.size.width * CGFloat(min(1.0, max(0.0, value)))), height: 6)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(height: 6)

                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
                .padding(.horizontal, 16)

            case .toggle(let icon, let color, let text):
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)

                    Text(text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 18)
            }
        }
        .frame(width: 250, height: 48)
    }
}
