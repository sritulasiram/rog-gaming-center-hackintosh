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

public enum AuraCoreSubTab: String, CaseIterable, Identifiable {
    case basicEffects = "BASIC EFFECTS"
    case custom4Zone = "4-ZONE CUSTOM"

    public var id: String { rawValue }
}

public struct AuraStudioView: View {
    @ObservedObject var service = AuraService.shared
    @State private var selectedSubTab: AuraCoreSubTab = .basicEffects
    @State private var hexInputText: String = ""
    @State private var showAppliedBanner: Bool = false

    public init() {}

    var activeColor: RGBColor {
        service.zoneColors[service.activeEditingZoneIndex]
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Top Sub-Navigation Bar
            HStack(spacing: 16) {
                ForEach(AuraCoreSubTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSubTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedSubTab == tab ? .bold : .medium, design: .rounded))
                                .foregroundColor(selectedSubTab == tab ? .red : .secondary)

                            Rectangle()
                                .fill(selectedSubTab == tab ? Color.red : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                if showAppliedBanner {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Applied to Hardware")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // 2-Column Main Canvas (Homage to Windows AURA Core)
            HStack(alignment: .top, spacing: 14) {
                // LEFT: GL503 Physical Keyboard Stage (70% width)
                AuraKeyboardStage(selectedSubTab: selectedSubTab, hexInputText: $hexInputText)
                    .frame(maxWidth: .infinity)

                // RIGHT: Controls Panel (30% width)
                AuraControlsSidebar(
                    selectedSubTab: $selectedSubTab,
                    onApply: {
                        triggerApply()
                    }
                )
                .frame(width: 260)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            hexInputText = activeColor.upperHexString
        }
        .onChange(of: service.activeEditingZoneIndex) {
            hexInputText = activeColor.upperHexString
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

// MARK: - Left Stage: GL503 Vector Keyboard Canvas

struct AuraKeyboardStage: View {
    @ObservedObject var service = AuraService.shared
    let selectedSubTab: AuraCoreSubTab
    @Binding var hexInputText: String

    private static let zone1KeyRows: [[String]] = [
        ["ESC", "F1", "F2", "F3"],
        ["~", "1", "2", "3"],
        ["TAB", "Q", "W", "E"],
        ["CAPS", "A", "S", "D"],
        ["SHIFT", "Z", "X", "C"],
        ["CTRL", "FN", "OPT", "CMD"]
    ]

    private static let zone2KeyRows: [[String]] = [
        ["F4", "F5", "F6", "F7"],
        ["4", "5", "6", "7"],
        ["R", "T", "Y", "U"],
        ["F", "G", "H", "J"],
        ["V", "B", "N", "M"],
        ["SPACE (L)", "CMD"]
    ]

    private static let zone3KeyRows: [[String]] = [
        ["F8", "F9", "F10", "F11"],
        ["8", "9", "0", "-"],
        ["I", "O", "P", "["],
        ["K", "L", ";", "'"],
        [",", ".", "/", "SHIFT"],
        ["SPACE (R)", "ALT", "CTRL"]
    ]

    private static let zone4KeyRows: [[String]] = [
        ["F12", "DEL", "PAUSE", "PRT"],
        ["=", "NUM", "/", "*"],
        ["]", "7", "8", "9"],
        ["ENT", "4", "5", "6"],
        ["▲", "1", "2", "3"],
        ["◄", "▼", "►", "0"]
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Technical Crop Brackets Header
            HStack {
                Text("┌ ASUS ROG STRIX GL503 KEYBOARD CHASSIS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("4-ZONE RGB MATRIX ┐")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Dedicated Top Hotkeys Row
            HStack(spacing: 8) {
                HotkeyCap(title: "VOL -", icon: "speaker.minus")
                HotkeyCap(title: "VOL +", icon: "speaker.plus")
                HotkeyCap(title: "MIC MUTE", icon: "mic.slash")
                HotkeyCap(title: "ROG", icon: "flame.fill", isAccent: true)
                Spacer()
                Text(selectedSubTab == .custom4Zone ? "Click a zone to configure colors" : "Hardware animation active")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 6)

            // 4-Zone Keyboard Array
            HStack(spacing: 6) {
                ZoneChassisBlock(
                    zoneIndex: 0,
                    zoneName: "Zone 1 (WASD)",
                    keyRows: Self.zone1KeyRows,
                    color: service.zoneColors[0],
                    isSelected: (service.activeEditingZoneIndex == 0 && selectedSubTab == .custom4Zone),
                    isCustomMode: selectedSubTab == .custom4Zone
                ) {
                    if selectedSubTab == .custom4Zone {
                        service.activeEditingZoneIndex = 0
                    }
                }

                ZoneChassisBlock(
                    zoneIndex: 1,
                    zoneName: "Zone 2 (Center-L)",
                    keyRows: Self.zone2KeyRows,
                    color: service.zoneColors[1],
                    isSelected: (service.activeEditingZoneIndex == 1 && selectedSubTab == .custom4Zone),
                    isCustomMode: selectedSubTab == .custom4Zone
                ) {
                    if selectedSubTab == .custom4Zone {
                        service.activeEditingZoneIndex = 1
                    }
                }

                ZoneChassisBlock(
                    zoneIndex: 2,
                    zoneName: "Zone 3 (Center-R)",
                    keyRows: Self.zone3KeyRows,
                    color: service.zoneColors[2],
                    isSelected: (service.activeEditingZoneIndex == 2 && selectedSubTab == .custom4Zone),
                    isCustomMode: selectedSubTab == .custom4Zone
                ) {
                    if selectedSubTab == .custom4Zone {
                        service.activeEditingZoneIndex = 2
                    }
                }

                ZoneChassisBlock(
                    zoneIndex: 3,
                    zoneName: "Zone 4 (Numpad)",
                    keyRows: Self.zone4KeyRows,
                    color: service.zoneColors[3],
                    isSelected: (service.activeEditingZoneIndex == 3 && selectedSubTab == .custom4Zone),
                    isCustomMode: selectedSubTab == .custom4Zone
                ) {
                    if selectedSubTab == .custom4Zone {
                        service.activeEditingZoneIndex = 3
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.35))
            .cornerRadius(10)

            // Technical Bottom Bracket
            HStack {
                Text("└ GL503GE REVISION 2.0")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("ITE 8910 CONTROLLER ┘")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // In 4-Zone Custom Mode: Inline Color Swatches & Hex Input
            if selectedSubTab == .custom4Zone {
                ZoneColorPickerToolbar(hexInputText: $hexInputText)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Zone Color Picker Toolbar

struct ZoneColorPickerToolbar: View {
    @ObservedObject var service = AuraService.shared
    @Binding var hexInputText: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Editing Zone \(service.activeEditingZoneIndex + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Pick quick swatch or custom hex")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Quick Palette
            HStack(spacing: 6) {
                QuickColorDot(color: .rogRed) { setZoneColor(.rogRed) }
                QuickColorDot(color: .orange) { setZoneColor(.orange) }
                QuickColorDot(color: .yellow) { setZoneColor(.yellow) }
                QuickColorDot(color: .green) { setZoneColor(.green) }
                QuickColorDot(color: .cyan) { setZoneColor(.cyan) }
                QuickColorDot(color: .blue) { setZoneColor(.blue) }
                QuickColorDot(color: .purple) { setZoneColor(.purple) }
                QuickColorDot(color: .white) { setZoneColor(.white) }
            }

            Spacer()

            // Hex Input
            HStack(spacing: 4) {
                Text("#")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("RRGGBB", text: $hexInputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 70)
                    .onSubmit {
                        if let c = RGBColor(hex: hexInputText) {
                            setZoneColor(c)
                        }
                    }
            }

            // Native macOS Color Wheel Button
            Button(action: {
                NSColorPanel.shared.orderFront(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                    Text("Wheel")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlColor).opacity(0.8))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
    }

    private func setZoneColor(_ color: RGBColor) {
        service.setZoneColor(zoneIndex: service.activeEditingZoneIndex, color: color)
        hexInputText = color.upperHexString
    }
}

// MARK: - Dedicated Hotkey Cap

struct HotkeyCap: View {
    let title: String
    let icon: String
    var isAccent: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
        }
        .foregroundColor(isAccent ? .red : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.35))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isAccent ? Color.red.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

// MARK: - Zone Keycap Block

struct ZoneChassisBlock: View {
    let zoneIndex: Int
    let zoneName: String
    let keyRows: [[String]]
    let color: RGBColor
    let isSelected: Bool
    let isCustomMode: Bool
    let onTap: () -> Void

    var displayColor: Color {
        Color(rgb: color)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Key Grid
            VStack(spacing: 2) {
                ForEach(0..<keyRows.count, id: \.self) { r in
                    HStack(spacing: 2) {
                        ForEach(0..<keyRows[r].count, id: \.self) { c in
                            let label = keyRows[r][c]
                            let isWASD = (zoneIndex == 0 && (label == "W" || label == "A" || label == "S" || label == "D"))

                            Text(label)
                                .font(.system(size: 7, weight: isWASD ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isWASD ? .white : .primary.opacity(0.85))
                                .frame(maxWidth: .infinity, minHeight: 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(isWASD ? displayColor.opacity(0.9) : displayColor.opacity(0.35))
                                )
                        }
                    }
                }
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(5)

            // Zone Footer Tag
            HStack(spacing: 3) {
                Circle()
                    .fill(displayColor)
                    .frame(width: 5, height: 5)
                Text(zoneName)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .red : .secondary)
                Spacer()
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.red.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.red : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Quick Color Dot

struct QuickColorDot: View {
    let color: RGBColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(rgb: color))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Right Column: Aura Controls Stack

struct AuraControlsSidebar: View {
    @ObservedObject var service = AuraService.shared
    @Binding var selectedSubTab: AuraCoreSubTab
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Brightness Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BRIGHTNESS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(service.isPoweredOn ? "\(service.currentBrightness * 33)%" : "Off")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    BrightnessSegmentButton(title: "Off", isSelected: !service.isPoweredOn || service.currentBrightness == 0) {
                        service.setBrightness(0)
                        HUDService.shared.showBacklightHUD(level: 0)
                    }
                    BrightnessSegmentButton(title: "33%", isSelected: service.isPoweredOn && service.currentBrightness == 1) {
                        service.setBrightness(1)
                        HUDService.shared.showBacklightHUD(level: 1)
                    }
                    BrightnessSegmentButton(title: "66%", isSelected: service.isPoweredOn && service.currentBrightness == 2) {
                        service.setBrightness(2)
                        HUDService.shared.showBacklightHUD(level: 2)
                    }
                    BrightnessSegmentButton(title: "100%", isSelected: service.isPoweredOn && service.currentBrightness == 3) {
                        service.setBrightness(3)
                        HUDService.shared.showBacklightHUD(level: 3)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            // 2. Lighting Effects List (Matching Windows AURA radio list)
            VStack(alignment: .leading, spacing: 8) {
                Text("[ EFFECTS ]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                VStack(spacing: 3) {
                    EffectRowRadio(
                        title: "STATIC",
                        subtitle: "Constant RGB luminescence",
                        isSelected: isCurrentModeStatic(),
                        icon: "lightbulb.fill"
                    ) {
                        selectedSubTab = .basicEffects
                        service.applySingleColor(service.zoneColors.first ?? .rogRed)
                    }

                    EffectRowRadio(
                        title: "BREATHING",
                        subtitle: "Smooth rhythmic cycle",
                        isSelected: isCurrentModeBreathing(),
                        icon: "water.waves"
                    ) {
                        selectedSubTab = .basicEffects
                        service.applyPreset(AuraPreset.builtInPresets[9])
                    }

                    EffectRowRadio(
                        title: "COLOR CYCLE",
                        subtitle: "Full spectrum shift",
                        isSelected: isCurrentModeColorCycle(),
                        icon: "sparkles"
                    ) {
                        selectedSubTab = .basicEffects
                        service.applyPreset(AuraPreset.builtInPresets[0])
                    }

                    EffectRowRadio(
                        title: "RAINBOW",
                        subtitle: "Dynamic rolling gradient",
                        isSelected: isCurrentModeRainbow(),
                        icon: "rainbow"
                    ) {
                        selectedSubTab = .basicEffects
                        service.applyPreset(AuraPreset.builtInPresets[1])
                    }

                    EffectRowRadio(
                        title: "STROBING",
                        subtitle: "High-energy RGB pulse",
                        isSelected: isCurrentModeStrobing(),
                        icon: "bolt.fill"
                    ) {
                        selectedSubTab = .basicEffects
                        service.applyPreset(AuraPreset.builtInPresets[11])
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            // 3. Animation Speed (Tempo)
            VStack(alignment: .leading, spacing: 6) {
                Text("[ TEMPO ]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    TempoPillButton(title: "SLOW", isSelected: service.currentSpeed == .slow) {
                        service.setSpeed(.slow)
                    }
                    TempoPillButton(title: "MEDIUM", isSelected: service.currentSpeed == .medium) {
                        service.setSpeed(.medium)
                    }
                    TempoPillButton(title: "FAST", isSelected: service.currentSpeed == .fast) {
                        service.setSpeed(.fast)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)

            Spacer()

            // 4. Prominent Red Apply Button (Exact Windows Homage)
            Button(action: onApply) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("APPLY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                )
                .shadow(color: Color.red.opacity(0.35), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func isCurrentModeStatic() -> Bool {
        if case .singleStatic = service.currentMode { return true }
        if case .multiStatic = service.currentMode { return true }
        return false
    }

    private func isCurrentModeBreathing() -> Bool {
        if case .singleBreathing = service.currentMode { return true }
        if case .multiBreathing = service.currentMode { return true }
        return false
    }

    private func isCurrentModeColorCycle() -> Bool {
        if case .colorCycle = service.currentMode { return true }
        return false
    }

    private func isCurrentModeRainbow() -> Bool {
        if case .rainbow = service.currentMode { return true }
        return false
    }

    private func isCurrentModeStrobing() -> Bool {
        if case .strobing = service.currentMode { return true }
        return false
    }
}

// MARK: - Control Buttons

struct BrightnessSegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EffectRowRadio: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? .red : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    Text(subtitle)
                        .font(.system(size: 8.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .red : .secondary.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.red.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.red.opacity(0.4) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TempoPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.red : Color(NSColor.controlColor).opacity(0.6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
