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

public struct AuraStudioView: View {
    @ObservedObject var service = AuraService.shared
    @State private var hexInputText: String = ""
    @State private var showingSaveModal: Bool = false
    @State private var newPresetName: String = ""

    public init() {}

    var activeZone: AuraZone {
        AuraZone(rawValue: service.activeEditingZoneIndex + 1) ?? .zone1
    }

    var currentColor: RGBColor {
        service.zoneColors[service.activeEditingZoneIndex]
    }

    public var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 14) {
                    // 1. Top Stage: Interactive Keyboard Chassis Visualizer
                    KeyboardStudioChassis()

                    // 2. Middle Controls: Effects & Dynamics + Color Studio
                    HStack(alignment: .top, spacing: 12) {
                        EffectsDynamicsPanel()
                        ColorStudioPanel(hexInputText: $hexInputText)
                    }

                    // 3. Bottom Strip: Lighting Scenes & Presets Gallery
                    PresetsSceneStrip(
                        showingSaveModal: $showingSaveModal,
                        newPresetName: $newPresetName
                    )
                }
                .padding(18)
            }

            // Save Preset Modal
            if showingSaveModal {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showingSaveModal = false }

                VStack(spacing: 14) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.purple)
                        Text("Save Lighting Scene")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    TextField("Scene Name (e.g. Synthwave)", text: $newPresetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))

                    HStack(spacing: 10) {
                        Button("Cancel") {
                            showingSaveModal = false
                            newPresetName = ""
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            service.saveCustomPreset(name: newPresetName)
                            showingSaveModal = false
                            newPresetName = ""
                        }) {
                            Text("Save Scene")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
                .frame(width: 300)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10)
            }
        }
        .onAppear {
            hexInputText = currentColor.upperHexString
        }
        .onChange(of: service.activeEditingZoneIndex) {
            hexInputText = currentColor.upperHexString
        }
    }
}

// MARK: - 1. Interactive Vector Keyboard Chassis Visualizer

struct KeyboardStudioChassis: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Interactive Keyboard Chassis", systemImage: "keyboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text("Click any zone to customize color")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Realistic 4-Zone Laptop Keyboard Visualizer
            HStack(spacing: 6) {
                // Zone 1: Left & WASD
                ChassisZoneTile(
                    zoneIndex: 0,
                    title: "Zone 1 (WASD)",
                    keyRows: [
                        ["ESC", "1", "2", "3"],
                        ["TAB", "W", "E", "R"],
                        ["CAPS", "A", "S", "D"],
                        ["SHIFT", "Z", "X", "C"]
                    ],
                    color: service.zoneColors[0],
                    isSelected: service.activeEditingZoneIndex == 0,
                    isPowered: service.isPoweredOn
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        service.activeEditingZoneIndex = 0
                    }
                }

                // Zone 2: Center Typing Area
                ChassisZoneTile(
                    zoneIndex: 1,
                    title: "Zone 2 (Mid)",
                    keyRows: [
                        ["4", "5", "6", "7"],
                        ["T", "Y", "U", "I"],
                        ["F", "G", "H", "J"],
                        ["V", "B", "N", "M"]
                    ],
                    color: service.zoneColors[1],
                    isSelected: service.activeEditingZoneIndex == 1,
                    isPowered: service.isPoweredOn
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        service.activeEditingZoneIndex = 1
                    }
                }

                // Zone 3: Right Navigation Area
                ChassisZoneTile(
                    zoneIndex: 2,
                    title: "Zone 3 (Right)",
                    keyRows: [
                        ["8", "9", "0", "DEL"],
                        ["O", "P", "[", "]"],
                        ["K", "L", ";", "ENT"],
                        [",", ".", "/", "SHIFT"]
                    ],
                    color: service.zoneColors[2],
                    isSelected: service.activeEditingZoneIndex == 2,
                    isPowered: service.isPoweredOn
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        service.activeEditingZoneIndex = 2
                    }
                }

                // Zone 4: Numpad / Arrow Keys / Lightbar
                ChassisZoneTile(
                    zoneIndex: 3,
                    title: "Zone 4 (Numpad)",
                    keyRows: [
                        ["NUM", "/", "*", "-"],
                        ["7", "8", "9", "+"],
                        ["4", "5", "6", "▲"],
                        ["1", "2", "3", "◄▼►"]
                    ],
                    color: service.zoneColors[3],
                    isSelected: service.activeEditingZoneIndex == 3,
                    isPowered: service.isPoweredOn
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        service.activeEditingZoneIndex = 3
                    }
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.2))
            .cornerRadius(10)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct ChassisZoneTile: View {
    let zoneIndex: Int
    let title: String
    let keyRows: [[String]]
    let color: RGBColor
    let isSelected: Bool
    let isPowered: Bool

    var displayColor: Color {
        isPowered ? Color(rgb: color) : Color.gray.opacity(0.3)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Miniature Keycap Grid Simulation
            VStack(spacing: 3) {
                ForEach(0..<keyRows.count, id: \.self) { rowIdx in
                    HStack(spacing: 3) {
                        ForEach(0..<keyRows[rowIdx].count, id: \.self) { colIdx in
                            let label = keyRows[rowIdx][colIdx]
                            let isWASD = (zoneIndex == 0 && (label == "W" || label == "A" || label == "S" || label == "D"))

                            Text(label)
                                .font(.system(size: 8, weight: isWASD ? .bold : .regular, design: .monospaced))
                                .foregroundColor(isWASD ? .white : .primary.opacity(0.8))
                                .frame(maxWidth: .infinity, minHeight: 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isWASD ? displayColor.opacity(0.9) : displayColor.opacity(0.35))
                                )
                        }
                    }
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .cornerRadius(6)

            // Zone Footer
            HStack(spacing: 4) {
                Circle()
                    .fill(displayColor)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                Text("#\(color.upperHexString)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
        )
        .shadow(
            color: isPowered ? displayColor.opacity(isSelected ? 0.3 : 0.08) : Color.clear,
            radius: isSelected ? 8 : 4
        )
    }
}

// MARK: - 2. Middle Controls: Effects & Dynamics + Color Studio

struct EffectsDynamicsPanel: View {
    @ObservedObject var service = AuraService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Effects & Dynamics", systemImage: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            // Effect Selector (Apple Segmented Grid)
            VStack(alignment: .leading, spacing: 6) {
                Text("Lighting Mode")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    EffectPillButton(title: "Static", icon: "lightbulb.fill", isSelected: isStatic()) {
                        service.applySingleColor(service.zoneColors.first ?? .rogRed)
                    }

                    EffectPillButton(title: "Spectrum", icon: "sparkles", isSelected: isSelected(.colorCycle(.medium))) {
                        service.applyPreset(AuraPreset.builtInPresets[0])
                    }

                    EffectPillButton(title: "Rainbow", icon: "rainbow", isSelected: isSelected(.rainbow(.medium))) {
                        service.applyPreset(AuraPreset.builtInPresets[1])
                    }

                    EffectPillButton(title: "Breathing", icon: "water.waves", isSelected: isBreathing()) {
                        service.applyPreset(AuraPreset.builtInPresets[9])
                    }

                    EffectPillButton(title: "Strobe", icon: "bolt.fill", isSelected: isStrobe()) {
                        service.applyPreset(AuraPreset.builtInPresets[11])
                    }
                }
            }

            Divider().opacity(0.4)

            // Control Center Brightness Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brightness")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(service.isPoweredOn ? "\(service.currentBrightness * 33)%" : "Off")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sun.min.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(service.isPoweredOn ? service.currentBrightness : 0) },
                            set: { val in service.setBrightness(Int(val.rounded())) }
                        ),
                        in: 0...3,
                        step: 1
                    )
                    .accentColor(.blue)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.4)

            // Animation Speed
            VStack(alignment: .leading, spacing: 6) {
                Text("Animation Speed")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Picker("", selection: Binding(
                    get: { service.currentSpeed },
                    set: { speed in service.setSpeed(speed) }
                )) {
                    ForEach(AuraSpeed.allCases, id: \.self) { sp in
                        Text(sp.displayName).tag(sp)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private func isStatic() -> Bool {
        if case .singleStatic = service.currentMode { return true }
        if case .multiStatic = service.currentMode { return true }
        return false
    }

    private func isSelected(_ mode: AuraMode) -> Bool {
        switch (service.currentMode, mode) {
        case (.colorCycle, .colorCycle): return true
        case (.rainbow, .rainbow): return true
        default: return false
        }
    }

    private func isBreathing() -> Bool {
        if case .singleBreathing = service.currentMode { return true }
        if case .multiBreathing = service.currentMode { return true }
        return false
    }

    private func isStrobe() -> Bool {
        if case .strobing = service.currentMode { return true }
        return false
    }
}

struct EffectPillButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)

                Text(title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Color Studio Panel
struct ColorStudioPanel: View {
    @ObservedObject var service = AuraService.shared
    @Binding var hexInputText: String
    @State private var isAllZonesMode: Bool = true

    var activeZone: AuraZone {
        AuraZone(rawValue: service.activeEditingZoneIndex + 1) ?? .zone1
    }

    var currentColor: RGBColor {
        service.zoneColors[service.activeEditingZoneIndex]
    }

    let applePalette: [RGBColor] = [
        RGBColor.rogRed, RGBColor.red, RGBColor.orange, RGBColor.gold,
        RGBColor.yellow, RGBColor.lime, RGBColor.green, RGBColor.matrix,
        RGBColor.cyan, RGBColor.iceBlue, RGBColor.blue, RGBColor.purple,
        RGBColor.magenta, RGBColor.neonPink, RGBColor.white
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with target zone indicator and Color Picker trigger
            HStack {
                Label(isAllZonesMode ? "Color Studio (All Zones / Whole Keyboard)" : "Color Studio (\(activeZone.name))", systemImage: "paintpalette")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: openSystemColorPicker) {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 11))
                        Text("Color Wheel")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open macOS System Color Picker")
            }

            // Scope Selector: All Zones vs Per-Zone
            HStack(spacing: 4) {
                Button(action: {
                    isAllZonesMode = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 9))
                        Text("All Zones")
                            .font(.system(size: 10, weight: isAllZonesMode ? .semibold : .regular))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAllZonesMode ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                    .foregroundColor(isAllZonesMode ? .white : .primary)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())

                ForEach(0..<4) { idx in
                    Button(action: {
                        isAllZonesMode = false
                        service.activeEditingZoneIndex = idx
                    }) {
                        Text(zoneLabel(idx))
                            .font(.system(size: 10, weight: (!isAllZonesMode && service.activeEditingZoneIndex == idx) ? .semibold : .regular))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background((!isAllZonesMode && service.activeEditingZoneIndex == idx) ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                            .foregroundColor((!isAllZonesMode && service.activeEditingZoneIndex == idx) ? .white : .primary)
                            .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Curated Swatch Palette
            VStack(alignment: .leading, spacing: 5) {
                Text("Curated Color Palette")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(applePalette, id: \.self) { c in
                        Button(action: {
                            hexInputText = c.upperHexString
                            applySelectedColor(c)
                        }) {
                            Circle()
                                .fill(Color(rgb: c))
                                .frame(height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(c == currentColor ? 0.9 : 0.2), lineWidth: c == currentColor ? 2 : 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            Divider().opacity(0.4)

            // Hex input & Quick Actions
            HStack(spacing: 8) {
                TextField("HEX", text: $hexInputText, onCommit: applyHex)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 85)

                Button("Apply") {
                    applyHex()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlColor).opacity(0.8))
                .cornerRadius(6)

                Spacer()

                Button(action: {
                    isAllZonesMode = true
                    service.applySingleColor(currentColor)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.fill.on.square.fill")
                        Text("Apply to All")
                    }
                    .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private func zoneLabel(_ idx: Int) -> String {
        switch idx {
        case 0: return "WASD"
        case 1: return "Center-L"
        case 2: return "Center-R"
        case 3: return "Numpad"
        default: return "Z\(idx+1)"
        }
    }

    private func applySelectedColor(_ col: RGBColor) {
        if isAllZonesMode {
            service.applySingleColor(col)
        } else {
            service.setZoneColor(zoneIndex: service.activeEditingZoneIndex, color: col)
        }
    }

    private func applyHex() {
        if let col = RGBColor(hex: hexInputText) {
            applySelectedColor(col)
        }
    }

    private func openSystemColorPicker() {
        let panel = NSColorPanel.shared
        let c = currentColor
        panel.color = NSColor(red: CGFloat(c.red)/255.0, green: CGFloat(c.green)/255.0, blue: CGFloat(c.blue)/255.0, alpha: 1.0)
        panel.orderFront(nil)
        ColorPanelDelegate.shared.isAllZones = isAllZonesMode
        panel.setTarget(ColorPanelDelegate.shared)
        panel.setAction(#selector(ColorPanelDelegate.colorChanged(_:)))
    }
}

class ColorPanelDelegate: NSObject {
    static let shared = ColorPanelDelegate()
    var isAllZones: Bool = true

    @objc func colorChanged(_ sender: NSColorPanel) {
        let col = sender.color.usingColorSpace(.sRGB) ?? sender.color
        let r = UInt8(max(0, min(255, col.redComponent * 255.0)))
        let g = UInt8(max(0, min(255, col.greenComponent * 255.0)))
        let b = UInt8(max(0, min(255, col.blueComponent * 255.0)))
        let rgb = RGBColor(red: r, green: g, blue: b)
        if isAllZones {
            AuraService.shared.applySingleColor(rgb)
        } else {
            AuraService.shared.setZoneColor(zoneIndex: AuraService.shared.activeEditingZoneIndex, color: rgb)
        }
    }
}

// MARK: - 3. Bottom Strip: Lighting Scenes & Presets Gallery

struct PresetsSceneStrip: View {
    @ObservedObject var service = AuraService.shared
    @Binding var showingSaveModal: Bool
    @Binding var newPresetName: String

    var allPresets: [AuraPreset] {
        AuraPreset.builtInPresets + service.customPresets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Lighting Scenes & Presets", systemImage: "slider.horizontal.2.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    newPresetName = "Custom \(service.customPresets.count + 1)"
                    showingSaveModal = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Save Current Scene")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(allPresets) { preset in
                    ScenePillCard(preset: preset, isSelected: (service.activePresetId == preset.id))
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
}

struct ScenePillCard: View {
    let preset: AuraPreset
    let isSelected: Bool
    @ObservedObject var service = AuraService.shared

    var body: some View {
        Button(action: {
            service.applyPreset(preset)
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(NSColor.controlColor).opacity(0.6))
                        .frame(width: 24, height: 24)

                    Image(systemName: preset.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        ForEach(0..<min(preset.previewColors.count, 4), id: \.self) { cIdx in
                            Circle()
                                .fill(Color(rgb: preset.previewColors[cIdx]))
                                .frame(width: 4, height: 4)
                        }
                    }
                }

                Spacer()

                if preset.isCustom {
                    Button(action: {
                        service.deleteCustomPreset(id: preset.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : Color(NSColor.controlColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.8) : Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
