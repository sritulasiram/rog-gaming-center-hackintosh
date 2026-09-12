import SwiftUI
import Cocoa

// MARK: - Color Extension Bridging

extension Color {
    init(rgb: RGBColor) {
        self.init(
            red: Double(rgb.red) / 255.0,
            green: Double(rgb.green) / 255.0,
            blue: Double(rgb.blue) / 255.0
        )
    }
}

// MARK: - Effect Mode Types

public enum AuraEffectCategory: String, CaseIterable, Identifiable {
    case staticMode = "Static"
    case breathing = "Breathing"
    case colorCycle = "Color Cycle"
    case rainbow = "Rainbow"
    case strobing = "Strobing"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .staticMode: return "lightbulb.fill"
        case .breathing: return "water.waves"
        case .colorCycle: return "sparkles"
        case .rainbow: return "rainbow"
        case .strobing: return "bolt.fill"
        }
    }

    public var subtitle: String {
        switch self {
        case .staticMode: return "Solid or curated themes"
        case .breathing: return "Rhythmic fading pulse"
        case .colorCycle: return "Synchronized spectrum"
        case .rainbow: return "Rolling multi-color wave"
        case .strobing: return "High-energy RGB pulse"
        }
    }
}

public enum StaticSubMode: String, CaseIterable, Identifiable {
    case solid = "Solid Color"
    case themes = "Curated Themes"
    public var id: String { rawValue }
}

public enum BreathingSubMode: String, CaseIterable, Identifiable {
    case single = "Single Color"
    case dual = "Dual Color"
    case multi = "Multi-Color"
    public var id: String { rawValue }
}

public enum StrobingSubMode: String, CaseIterable, Identifiable {
    case custom = "Custom Color"
    case multiRainbow = "Multi-Color Rainbow"
    public var id: String { rawValue }
}

// MARK: - Main Aura Core View

public struct AuraStudioView: View {
    @ObservedObject var service = AuraService.shared

    @State private var selectedEffect: AuraEffectCategory = .staticMode
    @State private var staticSubMode: StaticSubMode = .solid
    @State private var breathingSubMode: BreathingSubMode = .single
    @State private var strobingSubMode: StrobingSubMode = .custom

    @State private var selectedColor: RGBColor = .rogRed
    @State private var breathingColor2: RGBColor = .blue
    @State private var hexInputText: String = "E02933"
    @State private var showAppliedBanner: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                // 1. Seamless Full-Width Keyboard Deck (No artificial zone dividers)
                AuraSeamlessKeyboardDeck(
                    selectedEffect: selectedEffect,
                    activeColor: selectedColor,
                    breathingColor2: breathingColor2
                )

                // 3. Lighting Effect Cards Gallery (5 Authentic Modes)
                AuraEffectsGallery(selectedEffect: $selectedEffect) { effect in
                    handleEffectSelected(effect)
                }

                // 4. Contextual Controls & Sub-Options Deck
                AuraContextualControlsDeck(
                    selectedEffect: selectedEffect,
                    staticSubMode: $staticSubMode,
                    breathingSubMode: $breathingSubMode,
                    strobingSubMode: $strobingSubMode,
                    selectedColor: $selectedColor,
                    breathingColor2: $breathingColor2,
                    hexInputText: $hexInputText,
                    onColorChanged: { col in
                        handleColorChanged(col)
                    },
                    onThemeSelected: { preset in
                        service.applyPreset(preset)
                    },
                    onBreathingModeChanged: { mode in
                        handleBreathingModeChanged(mode)
                    },
                    onStrobingModeChanged: { mode in
                        handleStrobingModeChanged(mode)
                    },
                    onApply: { triggerApply() }
                )
            }
            .padding(18)
        }
        .onAppear {
            syncStateFromService()
        }
        .onChange(of: service.activePresetId) { _ in
            syncStateFromService()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { notif in
            guard let panel = notif.object as? NSColorPanel,
                  let srgbColor = panel.color.usingColorSpace(.sRGB) else { return }
            let r = UInt8(max(0, min(255, srgbColor.redComponent * 255)))
            let g = UInt8(max(0, min(255, srgbColor.greenComponent * 255)))
            let b = UInt8(max(0, min(255, srgbColor.blueComponent * 255)))
            let picked = RGBColor(red: r, green: g, blue: b)
            handleColorChanged(picked)
        }
    }

    private func syncStateFromService() {
        switch service.currentMode {
        case .singleStatic(let c):
            selectedEffect = .staticMode
            staticSubMode = .solid
            selectedColor = c
            hexInputText = c.upperHexString
        case .multiStatic:
            selectedEffect = .staticMode
            staticSubMode = .themes
            if let c = service.zoneColors.first {
                selectedColor = c
                hexInputText = c.upperHexString
            }
        case .singleBreathing(let c1, let c2, _):
            selectedEffect = .breathing
            selectedColor = c1
            breathingColor2 = c2
            hexInputText = c1.upperHexString
            breathingSubMode = (c2 == .black || c2 == c1) ? .single : .dual
        case .multiBreathing:
            selectedEffect = .breathing
            breathingSubMode = .multi
        case .colorCycle:
            selectedEffect = .colorCycle
        case .rainbow:
            selectedEffect = .rainbow
        case .strobing(let c, _):
            selectedEffect = .strobing
            if service.activePresetId == "multi_strobing" {
                strobingSubMode = .multiRainbow
            } else {
                strobingSubMode = .custom
                selectedColor = c
                hexInputText = c.upperHexString
            }
        case .off:
            break
        }
    }

    private func handleEffectSelected(_ effect: AuraEffectCategory) {
        selectedEffect = effect
        switch effect {
        case .staticMode:
            if staticSubMode == .solid {
                service.applySingleColor(selectedColor)
            } else {
                if let p = AuraPreset.builtInPresets.first(where: { $0.id == "classic_rog" }) {
                    service.applyPreset(p)
                }
            }
        case .breathing:
            handleBreathingModeChanged(breathingSubMode)
        case .colorCycle:
            service.applyColorCycle(speed: service.currentSpeed)
        case .rainbow:
            service.applyRainbow(speed: service.currentSpeed)
        case .strobing:
            handleStrobingModeChanged(strobingSubMode)
        }
    }

    private func handleColorChanged(_ color: RGBColor) {
        selectedColor = color
        hexInputText = color.upperHexString
        switch selectedEffect {
        case .staticMode:
            service.applySingleColor(color)
        case .breathing:
            handleBreathingModeChanged(breathingSubMode)
        case .strobing:
            if strobingSubMode == .custom {
                service.applyStrobing(color: color, speed: service.currentSpeed)
            }
        default:
            break
        }
    }

    private func handleBreathingModeChanged(_ mode: BreathingSubMode) {
        breathingSubMode = mode
        switch mode {
        case .single:
            service.applyBreathing(c1: selectedColor, c2: nil, speed: service.currentSpeed)
        case .dual:
            service.applyBreathing(c1: selectedColor, c2: breathingColor2, speed: service.currentSpeed)
        case .multi:
            let multiColors: [RGBColor] = [selectedColor, breathingColor2, .cyan, .purple]
            service.currentMode = .multiBreathing(multiColors, service.currentSpeed)
            service.reapplyCurrentLighting()
        }
    }

    private func handleStrobingModeChanged(_ mode: StrobingSubMode) {
        strobingSubMode = mode
        switch mode {
        case .custom:
            service.applyStrobing(color: selectedColor, speed: service.currentSpeed)
        case .multiRainbow:
            service.applyMultiStrobing(speed: service.currentSpeed)
        }
    }

    private func triggerApply() {
        service.reapplyCurrentLighting()
        withAnimation(.easeInOut(duration: 0.2)) {
            showAppliedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAppliedBanner = false
            }
        }
    }
}


// MARK: - 2. Seamless Keyboard Deck

struct AuraSeamlessKeyboardDeck: View {
    @ObservedObject var service = AuraService.shared
    let selectedEffect: AuraEffectCategory
    let activeColor: RGBColor
    let breathingColor2: RGBColor

    @State private var animPhase: Double = 0.0
    private let dynamicTimer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            // Centered Keyboard Deck Container
            VStack(alignment: .center, spacing: 10) {
                // Dedicated Top Hotkeys Row (Centered with keyboard)
                HStack(spacing: 8) {
                    KeyboardHotkeyPill(title: "VOL -", icon: "speaker.minus")
                    KeyboardHotkeyPill(title: "VOL +", icon: "speaker.plus")
                    KeyboardHotkeyPill(title: "MIC MUTE", icon: "mic.slash")
                    KeyboardHotkeyPill(title: "ROG", icon: "flame.fill", isAccent: true)

                    Spacer()
                }
                .frame(width: 630)

                // The Seamless Laptop Keyboard Matrix (Centered, 630pt width)
                VStack(spacing: 4.5) {
                    // Function Row (Esc, F1-F12, Del, PrtSc, Pause)
                    HStack(spacing: 3.5) {
                        Keycap(label: "ESC", width: 36, color: keyColor(xFraction: 0.02))
                        Spacer().frame(width: 10)
                        Keycap(label: "F1", width: 29, color: keyColor(xFraction: 0.08))
                        Keycap(label: "F2", width: 29, color: keyColor(xFraction: 0.12))
                        Keycap(label: "F3", width: 29, color: keyColor(xFraction: 0.16))
                        Keycap(label: "F4", width: 29, color: keyColor(xFraction: 0.20))
                        Spacer().frame(width: 10)
                        Keycap(label: "F5", width: 29, color: keyColor(xFraction: 0.28))
                        Keycap(label: "F6", width: 29, color: keyColor(xFraction: 0.32))
                        Keycap(label: "F7", width: 29, color: keyColor(xFraction: 0.36))
                        Keycap(label: "F8", width: 29, color: keyColor(xFraction: 0.40))
                        Spacer().frame(width: 10)
                        Keycap(label: "F9", width: 29, color: keyColor(xFraction: 0.48))
                        Keycap(label: "F10", width: 29, color: keyColor(xFraction: 0.52))
                        Keycap(label: "F11", width: 29, color: keyColor(xFraction: 0.56))
                        Keycap(label: "F12", width: 29, color: keyColor(xFraction: 0.60))
                        Spacer().frame(width: 14)
                        Keycap(label: "DEL", width: 32, color: keyColor(xFraction: 0.72))
                        Keycap(label: "PRT", width: 32, color: keyColor(xFraction: 0.78))
                        Keycap(label: "PAU", width: 32, color: keyColor(xFraction: 0.84))
                    }
                    .frame(width: 630, alignment: .leading)

                    // Number Row (`~` through Backspace, plus Numpad Top)
                    HStack(spacing: 3.5) {
                        Keycap(label: "~", width: 30, color: keyColor(xFraction: 0.02))
                        Keycap(label: "1", width: 30, color: keyColor(xFraction: 0.06))
                        Keycap(label: "2", width: 30, color: keyColor(xFraction: 0.10))
                        Keycap(label: "3", width: 30, color: keyColor(xFraction: 0.14))
                        Keycap(label: "4", width: 30, color: keyColor(xFraction: 0.18))
                        Keycap(label: "5", width: 30, color: keyColor(xFraction: 0.22))
                        Keycap(label: "6", width: 30, color: keyColor(xFraction: 0.26))
                        Keycap(label: "7", width: 30, color: keyColor(xFraction: 0.30))
                        Keycap(label: "8", width: 30, color: keyColor(xFraction: 0.34))
                        Keycap(label: "9", width: 30, color: keyColor(xFraction: 0.38))
                        Keycap(label: "0", width: 30, color: keyColor(xFraction: 0.42))
                        Keycap(label: "-", width: 30, color: keyColor(xFraction: 0.46))
                        Keycap(label: "=", width: 30, color: keyColor(xFraction: 0.50))
                        Keycap(label: "BKSP", width: 54, color: keyColor(xFraction: 0.58))
                        Spacer().frame(width: 10)
                        Keycap(label: "NUM", width: 30, color: keyColor(xFraction: 0.74))
                        Keycap(label: "/", width: 30, color: keyColor(xFraction: 0.80))
                        Keycap(label: "*", width: 30, color: keyColor(xFraction: 0.86))
                        Keycap(label: "-", width: 30, color: keyColor(xFraction: 0.92))
                    }
                    .frame(width: 630)

                    // QWERTY Row (Tab 1.5u, Q..P, [, ], \, Numpad 789+)
                    HStack(spacing: 3.5) {
                        Keycap(label: "TAB", width: 44, color: keyColor(xFraction: 0.03))
                        Keycap(label: "Q", width: 30, color: keyColor(xFraction: 0.08))
                        Keycap(label: "W", width: 30, color: keyColor(xFraction: 0.12), isWASD: true)
                        Keycap(label: "E", width: 30, color: keyColor(xFraction: 0.16))
                        Keycap(label: "R", width: 30, color: keyColor(xFraction: 0.20))
                        Keycap(label: "T", width: 30, color: keyColor(xFraction: 0.24))
                        Keycap(label: "Y", width: 30, color: keyColor(xFraction: 0.28))
                        Keycap(label: "U", width: 30, color: keyColor(xFraction: 0.32))
                        Keycap(label: "I", width: 30, color: keyColor(xFraction: 0.36))
                        Keycap(label: "O", width: 30, color: keyColor(xFraction: 0.40))
                        Keycap(label: "P", width: 30, color: keyColor(xFraction: 0.44))
                        Keycap(label: "[", width: 30, color: keyColor(xFraction: 0.48))
                        Keycap(label: "]", width: 30, color: keyColor(xFraction: 0.52))
                        Keycap(label: "\\", width: 40, color: keyColor(xFraction: 0.58))
                        Spacer().frame(width: 10)
                        Keycap(label: "7", width: 30, color: keyColor(xFraction: 0.74))
                        Keycap(label: "8", width: 30, color: keyColor(xFraction: 0.80))
                        Keycap(label: "9", width: 30, color: keyColor(xFraction: 0.86))
                        Keycap(label: "+", width: 30, color: keyColor(xFraction: 0.92))
                    }
                    .frame(width: 630)

                    // Home Row (Caps 1.75u, A..L, ;, ', Enter 2.25u, Numpad 456)
                    HStack(spacing: 3.5) {
                        Keycap(label: "CAPS", width: 52, color: keyColor(xFraction: 0.04))
                        Keycap(label: "A", width: 30, color: keyColor(xFraction: 0.10), isWASD: true)
                        Keycap(label: "S", width: 30, color: keyColor(xFraction: 0.14), isWASD: true)
                        Keycap(label: "D", width: 30, color: keyColor(xFraction: 0.18), isWASD: true)
                        Keycap(label: "F", width: 30, color: keyColor(xFraction: 0.22))
                        Keycap(label: "G", width: 30, color: keyColor(xFraction: 0.26))
                        Keycap(label: "H", width: 30, color: keyColor(xFraction: 0.30))
                        Keycap(label: "J", width: 30, color: keyColor(xFraction: 0.34))
                        Keycap(label: "K", width: 30, color: keyColor(xFraction: 0.38))
                        Keycap(label: "L", width: 30, color: keyColor(xFraction: 0.42))
                        Keycap(label: ";", width: 30, color: keyColor(xFraction: 0.46))
                        Keycap(label: "'", width: 30, color: keyColor(xFraction: 0.50))
                        Keycap(label: "ENTER", width: 65.5, color: keyColor(xFraction: 0.59))
                        Spacer().frame(width: 10)
                        Keycap(label: "4", width: 30, color: keyColor(xFraction: 0.74))
                        Keycap(label: "5", width: 30, color: keyColor(xFraction: 0.80))
                        Keycap(label: "6", width: 30, color: keyColor(xFraction: 0.86))
                        Keycap(label: "+", width: 30, color: keyColor(xFraction: 0.92))
                    }
                    .frame(width: 630)

                    // Shift Row (L-Shift 2.25u, Z../, R-Shift 1.75u, Numpad 123 Enter)
                    HStack(spacing: 3.5) {
                        Keycap(label: "SHIFT", width: 76, color: keyColor(xFraction: 0.05))
                        Keycap(label: "Z", width: 30, color: keyColor(xFraction: 0.12))
                        Keycap(label: "X", width: 30, color: keyColor(xFraction: 0.16))
                        Keycap(label: "C", width: 30, color: keyColor(xFraction: 0.20))
                        Keycap(label: "V", width: 30, color: keyColor(xFraction: 0.24))
                        Keycap(label: "B", width: 30, color: keyColor(xFraction: 0.28))
                        Keycap(label: "N", width: 30, color: keyColor(xFraction: 0.32))
                        Keycap(label: "M", width: 30, color: keyColor(xFraction: 0.36))
                        Keycap(label: ",", width: 30, color: keyColor(xFraction: 0.40))
                        Keycap(label: ".", width: 30, color: keyColor(xFraction: 0.44))
                        Keycap(label: "/", width: 30, color: keyColor(xFraction: 0.48))
                        Keycap(label: "SHIFT", width: 75, color: keyColor(xFraction: 0.56))
                        Spacer().frame(width: 10)
                        Keycap(label: "1", width: 30, color: keyColor(xFraction: 0.74))
                        Keycap(label: "2", width: 30, color: keyColor(xFraction: 0.80))
                        Keycap(label: "3", width: 30, color: keyColor(xFraction: 0.86))
                        Keycap(label: "ENT", width: 30, color: keyColor(xFraction: 0.92))
                    }
                    .frame(width: 630)

                    // Bottom Row (Ctrl, Fn, Opt, Cmd, Spacebar, Cmd, Opt, Arrows, Numpad 0 .)
                    HStack(spacing: 3.5) {
                        Keycap(label: "CTRL", width: 36, color: keyColor(xFraction: 0.03))
                        Keycap(label: "FN", width: 26, color: keyColor(xFraction: 0.07))
                        Keycap(label: "OPT", width: 26, color: keyColor(xFraction: 0.11))
                        Keycap(label: "CMD", width: 36, color: keyColor(xFraction: 0.15))
                        Keycap(label: "SPACEBAR", width: 201, color: keyColor(xFraction: 0.30))
                        Keycap(label: "CMD", width: 36, color: keyColor(xFraction: 0.46))
                        Keycap(label: "OPT", width: 26, color: keyColor(xFraction: 0.52))
                        Spacer().frame(width: 8)

                        // Arrow Cluster (◄, ▼, ► with ▲ placed directly above)
                        HStack(spacing: 2) {
                            Keycap(label: "◄", width: 24, height: 23, color: keyColor(xFraction: 0.65))
                            VStack(spacing: 2) {
                                Keycap(label: "▲", width: 24, height: 10.5, color: keyColor(xFraction: 0.68))
                                Keycap(label: "▼", width: 24, height: 10.5, color: keyColor(xFraction: 0.68))
                            }
                            Keycap(label: "►", width: 24, height: 23, color: keyColor(xFraction: 0.71))
                        }

                        Spacer().frame(width: 8)
                        Keycap(label: "0", width: 60, color: keyColor(xFraction: 0.80))
                        Keycap(label: ".", width: 30, color: keyColor(xFraction: 0.86))
                        Keycap(label: "ENT", width: 30, color: keyColor(xFraction: 0.92))
                    }
                    .frame(width: 630)
                }
                .padding(14)
                .background(
                    ZStack {
                        // Under-deck dark chassis
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))

                        // Diffuse ambient LED underglow layer
                        underglowLayer
                            .blur(radius: 20)
                            .opacity(service.isPoweredOn ? 0.40 : 0.0)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ROGColor.hairline, lineWidth: 0.75)
                )
            }
            .frame(width: 660)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .glassCard(radius: ROGRadius.card, padding: 16)
        .onReceive(dynamicTimer) { _ in
            guard service.isPoweredOn && selectedEffect != .staticMode else { return }
            animPhase = (animPhase + 0.025).truncatingRemainder(dividingBy: 1.0)
        }
    }

    // Dynamic color computation for each key depending on effect mode
    private func keyColor(xFraction: Double) -> Color {
        guard service.isPoweredOn else {
            return Color.white.opacity(0.12)
        }

        switch selectedEffect {
        case .staticMode:
            if case .multiStatic(let zones) = service.currentMode, zones.count == 4 {
                let zoneIdx = min(3, Int(xFraction * 4.0))
                return Color(rgb: zones[zoneIdx])
            }
            return Color(rgb: activeColor)

        case .rainbow:
            let hue = (animPhase + xFraction).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: hue, saturation: 0.95, brightness: 1.0)

        case .colorCycle:
            return Color(hue: animPhase, saturation: 0.95, brightness: 1.0)

        case .breathing:
            let wave = (sin(animPhase * .pi * 2) + 1.0) / 2.0 // 0.0 to 1.0
            if breathingColor2 != .black && breathingColor2 != activeColor {
                let c1 = Color(rgb: activeColor)
                let c2 = Color(rgb: breathingColor2)
                return wave > 0.5 ? c1 : c2
            }
            return Color(rgb: activeColor).opacity(0.2 + 0.8 * wave)

        case .strobing:
            let flash = Int(animPhase * 24) % 2 == 0
            if flash {
                if service.activePresetId == "multi_strobing" {
                    let strobeHue = Double(Int(animPhase * 10) % 8) / 8.0
                    return Color(hue: strobeHue, saturation: 0.95, brightness: 1.0)
                }
                return Color(rgb: activeColor)
            } else {
                return Color.white.opacity(0.1)
            }
        }
    }

    // Diffuse underglow gradient
    private var underglowLayer: some View {
        Group {
            switch selectedEffect {
            case .rainbow:
                LinearGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .colorCycle:
                Color(hue: animPhase, saturation: 0.9, brightness: 1.0)
            case .breathing:
                Color(rgb: activeColor)
            case .strobing:
                Color(rgb: activeColor)
            case .staticMode:
                if case .multiStatic(let zones) = service.currentMode, zones.count == 4 {
                    LinearGradient(
                        colors: zones.map { Color(rgb: $0) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Color(rgb: activeColor)
                }
            }
        }
    }
}

// MARK: - Keycap Component

struct Keycap: View, Equatable {
    let label: String
    let width: CGFloat
    var height: CGFloat = 23
    let color: Color
    var isWASD: Bool = false

    static func == (lhs: Keycap, rhs: Keycap) -> Bool {
        lhs.label == rhs.label && lhs.width == rhs.width && lhs.height == rhs.height && lhs.color == rhs.color && lhs.isWASD == rhs.isWASD
    }

    var body: some View {
        ZStack {
            // Keycap body
            RoundedRectangle(cornerRadius: 4.0, style: .continuous)
                .fill(
                    isWASD
                        ? LinearGradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                )

            // Inner LED glow bleed
            RoundedRectangle(cornerRadius: 4.0, style: .continuous)
                .fill(color.opacity(isWASD ? 0.85 : 0.45))

            // Keycap Legend Text
            Text(label)
                .font(.system(size: label.count > 3 ? 8.5 : 10.0, weight: isWASD ? .heavy : .bold, design: .rounded))
                .foregroundColor(isWASD ? .black : .white.opacity(0.95))
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 4.0, style: .continuous)
                .stroke(isWASD ? ROGColor.accent.opacity(0.85) : color.opacity(0.6), lineWidth: isWASD ? 1.2 : 0.5)
        )
    }
}

struct KeyboardHotkeyPill: View {
    let title: String
    let icon: String
    var isAccent: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
        }
        .foregroundColor(isAccent ? ROGColor.accent : .secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(ROGRadius.control)
        .overlay(
            RoundedRectangle(cornerRadius: ROGRadius.control)
                .stroke(isAccent ? ROGColor.accent.opacity(0.5) : ROGColor.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - 3. Effects Gallery (5 Visual Cards)

struct AuraEffectsGallery: View {
    @Binding var selectedEffect: AuraEffectCategory
    let onSelect: (AuraEffectCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Lighting Effects", systemImage: "sparkles")

            HStack(spacing: 10) {
                ForEach(AuraEffectCategory.allCases) { effect in
                    EffectVisualCard(
                        effect: effect,
                        isSelected: selectedEffect == effect
                    ) {
                        onSelect(effect)
                    }
                }
            }
        }
    }
}

struct EffectVisualCard: View {
    let effect: AuraEffectCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isSelected ? ROGColor.accent.opacity(0.2) : Color.white.opacity(0.08))
                            .frame(width: 28, height: 28)

                        Image(systemName: effect.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? ROGColor.accent : .secondary)
                    }

                    Spacer()

                    if isSelected {
                        Circle()
                            .fill(ROGColor.accent)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(effect.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Text(effect.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                    .fill(isSelected ? ROGColor.accentSoft : Color(NSColor.controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                    .stroke(isSelected ? ROGColor.accent : ROGColor.hairline, lineWidth: isSelected ? 1.5 : 0.75)
            )
            .shadow(color: isSelected ? ROGColor.accent.opacity(0.2) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 4. Contextual Controls Deck

struct AuraContextualControlsDeck: View {
    @ObservedObject var service = AuraService.shared

    let selectedEffect: AuraEffectCategory
    @Binding var staticSubMode: StaticSubMode
    @Binding var breathingSubMode: BreathingSubMode
    @Binding var strobingSubMode: StrobingSubMode
    @Binding var selectedColor: RGBColor
    @Binding var breathingColor2: RGBColor
    @Binding var hexInputText: String

    let onColorChanged: (RGBColor) -> Void
    let onThemeSelected: (AuraPreset) -> Void
    let onBreathingModeChanged: (BreathingSubMode) -> Void
    let onStrobingModeChanged: (StrobingSubMode) -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // A. Contextual Mode Sub-Options
            switch selectedEffect {
            case .staticMode:
                StaticSubOptionsView(
                    subMode: $staticSubMode,
                    selectedColor: $selectedColor,
                    hexInputText: $hexInputText,
                    onColorChanged: onColorChanged,
                    onThemeSelected: onThemeSelected
                )

            case .breathing:
                BreathingSubOptionsView(
                    subMode: $breathingSubMode,
                    c1: $selectedColor,
                    c2: $breathingColor2,
                    onModeChanged: onBreathingModeChanged
                )

            case .colorCycle:
                ColorCycleSubOptionsView()

            case .rainbow:
                RainbowSubOptionsView()

            case .strobing:
                StrobingSubOptionsView(
                    subMode: $strobingSubMode,
                    selectedColor: $selectedColor,
                    hexInputText: $hexInputText,
                    onColorChanged: onColorChanged,
                    onModeChanged: onStrobingModeChanged
                )
            }

            Divider().background(ROGColor.hairline)

            // B. Hardware Attributes Strip (Brightness, Tempo, Apply)
            HStack(spacing: 16) {
                // Brightness Segment
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brightness")
                        .font(ROGType.footnote())
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        BrightnessPill(title: "Off", isSelected: !service.isPoweredOn || service.currentBrightness == 0) {
                            service.setBrightness(0)
                        }
                        BrightnessPill(title: "33%", isSelected: service.isPoweredOn && service.currentBrightness == 1) {
                            service.setBrightness(1)
                        }
                        BrightnessPill(title: "66%", isSelected: service.isPoweredOn && service.currentBrightness == 2) {
                            service.setBrightness(2)
                        }
                        BrightnessPill(title: "100%", isSelected: service.isPoweredOn && service.currentBrightness == 3) {
                            service.setBrightness(3)
                        }
                    }
                }

                // Animation Speed (Shown for dynamic modes)
                if selectedEffect != .staticMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tempo")
                            .font(ROGType.footnote())
                            .foregroundColor(.secondary)

                        HStack(spacing: 4) {
                            TempoSegmentPill(title: "Slow", isSelected: service.currentSpeed == .slow) {
                                service.setSpeed(.slow)
                            }
                            TempoSegmentPill(title: "Medium", isSelected: service.currentSpeed == .medium) {
                                service.setSpeed(.medium)
                            }
                            TempoSegmentPill(title: "Fast", isSelected: service.currentSpeed == .fast) {
                                service.setSpeed(.fast)
                            }
                        }
                    }
                }

                Spacer()

                // Primary Apply Button
                Button(action: onApply) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Apply to Keyboard")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                            .fill(ROGColor.accent)
                    )
                    .shadow(color: ROGColor.accent.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .glassCard(radius: ROGRadius.card, padding: 16)
    }
}

// MARK: - Sub-Options Views

struct StaticSubOptionsView: View {
    @Binding var subMode: StaticSubMode
    @Binding var selectedColor: RGBColor
    @Binding var hexInputText: String
    let onColorChanged: (RGBColor) -> Void
    let onThemeSelected: (AuraPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Static Mode:")
                    .font(ROGType.bodyEmphasized())

                Picker("", selection: $subMode) {
                    ForEach(StaticSubMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 220)

                Spacer()
            }

            if subMode == .solid {
                ColorPaletteRow(
                    selectedColor: $selectedColor,
                    hexInputText: $hexInputText,
                    onColorChanged: onColorChanged
                )
            } else {
                // Curated Multi-Color Themes Grid
                ThemesGrid(onThemeSelected: onThemeSelected)
            }
        }
    }
}

struct BreathingSubOptionsView: View {
    @Binding var subMode: BreathingSubMode
    @Binding var c1: RGBColor
    @Binding var c2: RGBColor
    let onModeChanged: (BreathingSubMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Breathing Style:")
                    .font(ROGType.bodyEmphasized())

                Picker("", selection: $subMode) {
                    ForEach(BreathingSubMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 260)
                .onChange(of: subMode) { mode in
                    onModeChanged(mode)
                }

                Spacer()
            }

            if subMode == .single {
                HStack(spacing: 8) {
                    Text("Pulse Color:")
                        .font(ROGType.footnote())
                        .foregroundColor(.secondary)

                    QuickPaletteDots(selectedColor: $c1) { col in
                        c1 = col
                        onModeChanged(.single)
                    }
                }
            } else if subMode == .dual {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("Color 1:")
                            .font(ROGType.footnote())
                            .foregroundColor(.secondary)
                        QuickPaletteDots(selectedColor: $c1) { col in
                            c1 = col
                            onModeChanged(.dual)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("Color 2:")
                            .font(ROGType.footnote())
                            .foregroundColor(.secondary)
                        QuickPaletteDots(selectedColor: $c2) { col in
                            c2 = col
                            onModeChanged(.dual)
                        }
                    }
                }
            } else {
                Text("Multi-color spectrum breathing cycles across all 4 zones automatically.")
                    .font(ROGType.footnote())
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ColorCycleSubOptionsView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(ROGColor.accent)
            Text("Full spectrum phase cycle automatically transitions through every color in sync.")
                .font(ROGType.footnote())
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct RainbowSubOptionsView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rainbow")
                .foregroundColor(.cyan)
            Text("Hardware Mode 3: Autonomous rolling chromatic wave flows dynamically across all keys.")
                .font(ROGType.footnote())
                .foregroundColor(.secondary)
            Spacer()
            AccentBadge("Multi-Color Flow", color: .cyan)
        }
    }
}

struct StrobingSubOptionsView: View {
    @Binding var subMode: StrobingSubMode
    @Binding var selectedColor: RGBColor
    @Binding var hexInputText: String
    let onColorChanged: (RGBColor) -> Void
    let onModeChanged: (StrobingSubMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Strobe Mode:")
                    .font(ROGType.bodyEmphasized())

                Picker("", selection: $subMode) {
                    ForEach(StrobingSubMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 250)
                .onChange(of: subMode) { mode in
                    onModeChanged(mode)
                }

                Spacer()
            }

            if subMode == .custom {
                ColorPaletteRow(
                    selectedColor: $selectedColor,
                    hexInputText: $hexInputText,
                    onColorChanged: onColorChanged
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(ROGColor.warn)
                    Text("Multi-color strobe rapidly flashes alternating spectrum colors on every pulse.")
                        .font(ROGType.footnote())
                        .foregroundColor(.secondary)
                    Spacer()
                    AccentBadge("Rainbow Flash", color: ROGColor.warn)
                }
            }
        }
    }
}

// MARK: - Color Palette Row

struct ColorPaletteRow: View {
    @Binding var selectedColor: RGBColor
    @Binding var hexInputText: String
    let onColorChanged: (RGBColor) -> Void

    var body: some View {
        HStack(spacing: 12) {
            QuickPaletteDots(selectedColor: $selectedColor, onSelect: onColorChanged)

            Spacer()

            // Hex input
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                TextField("RRGGBB", text: $hexInputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 72)
                    .onChange(of: hexInputText) { text in
                        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                        if clean.count == 6, let c = RGBColor(hex: clean) {
                            onColorChanged(c)
                        }
                    }
                    .onSubmit {
                        if let c = RGBColor(hex: hexInputText) {
                            onColorChanged(c)
                        }
                    }
            }

            // macOS Color Wheel button
            Button(action: {
                NSColorPanel.shared.orderFront(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                    Text("Wheel")
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlColor).opacity(0.8))
                .cornerRadius(ROGRadius.control)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct QuickPaletteDots: View {
    @Binding var selectedColor: RGBColor
    let onSelect: (RGBColor) -> Void

    private static let swatches: [RGBColor] = [
        .rogRed,
        RGBColor(red: 255, green: 102, blue: 0),   // Orange
        RGBColor(red: 255, green: 204, blue: 0),   // Yellow
        RGBColor(red: 0, green: 220, blue: 90),    // Green
        RGBColor(red: 0, green: 220, blue: 255),   // Cyan
        RGBColor(red: 0, green: 122, blue: 255),   // Blue
        RGBColor(red: 175, green: 82, blue: 222),  // Purple
        .white
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.swatches, id: \.self) { c in
                Button(action: {
                    selectedColor = c
                    onSelect(c)
                }) {
                    Circle()
                        .fill(Color(rgb: c))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == c ? Color.white : Color.white.opacity(0.2), lineWidth: selectedColor == c ? 2.0 : 0.5)
                        )
                        .shadow(color: selectedColor == c ? Color(rgb: c).opacity(0.5) : .clear, radius: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Themes Grid

struct ThemesGrid: View {
    @ObservedObject var service = AuraService.shared
    let onThemeSelected: (AuraPreset) -> Void

    @State private var showingSavePopover: Bool = false
    @State private var customPresetName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Built-in presets
            ForEach(AuraPreset.builtInPresets) { preset in
                ThemePillView(
                    preset: preset,
                    isSelected: service.activePresetId == preset.id,
                    onSelect: { onThemeSelected(preset) },
                    onDelete: nil
                )
            }

            // User-created custom presets
            ForEach(service.customPresets) { preset in
                ThemePillView(
                    preset: preset,
                    isSelected: service.activePresetId == preset.id,
                    onSelect: { onThemeSelected(preset) },
                    onDelete: { service.deleteCustomPreset(id: preset.id) }
                )
            }

            // Save Current Colors as Custom Preset Button
            Button(action: {
                customPresetName = "Custom \(service.customPresets.count + 1)"
                showingSavePopover = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11))
                    Text("Save Theme")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(ROGColor.accent.opacity(0.12))
                .foregroundColor(ROGColor.accent)
                .cornerRadius(ROGRadius.control)
                .overlay(
                    RoundedRectangle(cornerRadius: ROGRadius.control)
                        .stroke(ROGColor.accent.opacity(0.35), lineWidth: 0.8)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingSavePopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Save Custom Theme")
                        .font(.system(size: 12, weight: .bold))

                    Text("Saves current 4-zone lighting colors.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    TextField("Theme Name", text: $customPresetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 11))
                        .frame(width: 190)

                    HStack {
                        Button("Cancel") {
                            showingSavePopover = false
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Save") {
                            service.saveCustomPreset(name: customPresetName)
                            showingSavePopover = false
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ROGColor.accent)
                    }
                }
                .padding(12)
            }
        }
    }
}

struct ThemePillView: View {
    let preset: AuraPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(0..<min(4, preset.previewColors.count), id: \.self) { i in
                            Circle()
                                .fill(Color(rgb: preset.previewColors[i]))
                                .frame(width: 7, height: 7)
                        }
                    }
                    Text(preset.name)
                        .font(.system(size: 10, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                }

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete custom preset")
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                isSelected ?
                    ROGColor.accent.opacity(0.85) :
                    Color(NSColor.controlBackgroundColor).opacity(0.6)
            )
            .cornerRadius(ROGRadius.control)
            .overlay(
                RoundedRectangle(cornerRadius: ROGRadius.control)
                    .stroke(isSelected ? ROGColor.accent : ROGColor.hairline, lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Hardware Control Pills

struct BrightnessPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                        .fill(isSelected ? ROGColor.accent : Color(NSColor.controlColor).opacity(0.5))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TempoSegmentPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                        .fill(isSelected ? ROGColor.accent : Color(NSColor.controlColor).opacity(0.5))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
