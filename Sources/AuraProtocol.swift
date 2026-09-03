import Foundation

// MARK: - Color Model

public struct RGBColor: Equatable, Codable, Hashable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        if cleanHex.hasPrefix("0x") { cleanHex = String(cleanHex.dropFirst(2)) }
        
        // Handle 3-character hex (e.g. "f0a" -> "ff00aa")
        if cleanHex.count == 3 {
            let r = cleanHex[cleanHex.startIndex]
            let g = cleanHex[cleanHex.index(cleanHex.startIndex, offsetBy: 1)]
            let b = cleanHex[cleanHex.index(cleanHex.startIndex, offsetBy: 2)]
            cleanHex = "\(r)\(r)\(g)\(g)\(b)\(b)"
        }
        
        guard cleanHex.count == 6, let val = UInt32(cleanHex, radix: 16) else { return nil }
        self.red = UInt8((val >> 16) & 0xFF)
        self.green = UInt8((val >> 8) & 0xFF)
        self.blue = UInt8(val & 0xFF)
    }

    public var hexString: String {
        return String(format: "%02x%02x%02x", red, green, blue)
    }

    public var upperHexString: String {
        return String(format: "%02X%02X%02X", red, green, blue)
    }

    public func scaled(by factor: Double) -> RGBColor {
        let f = max(0.0, min(1.0, factor))
        return RGBColor(
            red: UInt8(Double(red) * f),
            green: UInt8(Double(green) * f),
            blue: UInt8(Double(blue) * f)
        )
    }

    // Curated standard gamer palette
    public static let red       = RGBColor(red: 255, green: 0, blue: 0)
    public static let rogRed    = RGBColor(red: 255, green: 0, blue: 51)
    public static let orange    = RGBColor(red: 255, green: 120, blue: 0)
    public static let gold      = RGBColor(red: 255, green: 170, blue: 0)
    public static let yellow    = RGBColor(red: 255, green: 230, blue: 0)
    public static let lime      = RGBColor(red: 50, green: 220, blue: 50)
    public static let green     = RGBColor(red: 0, green: 255, blue: 0)
    public static let matrix    = RGBColor(red: 0, green: 255, blue: 102)
    public static let cyan      = RGBColor(red: 0, green: 255, blue: 255)
    public static let iceBlue   = RGBColor(red: 0, green: 200, blue: 255)
    public static let blue      = RGBColor(red: 0, green: 100, blue: 255)
    public static let deepBlue  = RGBColor(red: 0, green: 0, blue: 255)
    public static let purple    = RGBColor(red: 160, green: 32, blue: 240)
    public static let violet    = RGBColor(red: 138, green: 43, blue: 226)
    public static let magenta   = RGBColor(red: 255, green: 0, blue: 255)
    public static let neonPink  = RGBColor(red: 255, green: 0, blue: 127)
    public static let pink      = RGBColor(red: 255, green: 0, blue: 127)
    public static let white     = RGBColor(red: 255, green: 255, blue: 255)
    public static let black     = RGBColor(red: 0, green: 0, blue: 0)
}

// MARK: - Speed Enumeration

public enum AuraSpeed: Int, Codable, CaseIterable {
    case slow = 1
    case medium = 2
    case fast = 3

    public var byteValue: UInt8 {
        switch self {
        case .slow:   return 0xe1
        case .medium: return 0xeb
        case .fast:   return 0xf5
        }
    }

    public var displayName: String {
        switch self {
        case .slow:   return "Slow"
        case .medium: return "Normal"
        case .fast:   return "Fast"
        }
    }
}

// MARK: - Zone Identifier

public enum AuraZone: Int, CaseIterable, Identifiable {
    case zone1 = 1 // WASD / Left region
    case zone2 = 2 // Center-Left region
    case zone3 = 3 // Center-Right region
    case zone4 = 4 // Numpad / Right region

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .zone1: return "WASD / Left"
        case .zone2: return "Center-Left"
        case .zone3: return "Center-Right"
        case .zone4: return "Numpad"
        }
    }

    public var shortName: String {
        switch self {
        case .zone1: return "WASD"
        case .zone2: return "Center-L"
        case .zone3: return "Center-R"
        case .zone4: return "Numpad"
        }
    }
}

// MARK: - Lighting Modes

public enum AuraMode: Equatable, Codable {
    case off
    case singleStatic(RGBColor)
    case multiStatic([RGBColor])
    case colorCycle(AuraSpeed)
    case rainbow(AuraSpeed)
    case singleBreathing(RGBColor, RGBColor, AuraSpeed)
    case multiBreathing([RGBColor], AuraSpeed)
    case strobing(RGBColor, AuraSpeed)

    public var isOff: Bool {
        if case .off = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .off: return "Off (Stealth)"
        case .singleStatic: return "Single Static"
        case .multiStatic: return "4-Zone Custom"
        case .colorCycle: return "Color Cycle"
        case .rainbow: return "Rainbow Wave"
        case .singleBreathing: return "Single Breathing"
        case .multiBreathing: return "4-Zone Breathing"
        case .strobing: return "Strobing Flash"
        }
    }
}

// MARK: - Preset Definition

public struct AuraPreset: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var icon: String
    public var mode: AuraMode
    public var previewColors: [RGBColor]
    public var isCustom: Bool

    public init(id: String, name: String, icon: String, mode: AuraMode, previewColors: [RGBColor], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.mode = mode
        self.previewColors = previewColors
        self.isCustom = isCustom
    }

    // Built-in Designer Presets
    public static let builtInPresets: [AuraPreset] = [
        AuraPreset(
            id: "color_cycle",
            name: "Spectrum Cycle",
            icon: "sparkles",
            mode: .colorCycle(.medium),
            previewColors: [.red, .green, .blue, .yellow]
        ),
        AuraPreset(
            id: "rainbow",
            name: "Rainbow Wave",
            icon: "rainbow",
            mode: .rainbow(.medium),
            previewColors: [.red, .yellow, .cyan, .magenta]
        ),
        AuraPreset(
            id: "neon_cyberpunk",
            name: "Cyberpunk 2077",
            icon: "bolt.horizontal.fill",
            mode: .multiStatic([
                RGBColor(red: 255, green: 0, blue: 127),
                RGBColor(red: 128, green: 0, blue: 255),
                RGBColor(red: 0, green: 255, blue: 255),
                RGBColor(red: 0, green: 127, blue: 255)
            ]),
            previewColors: [
                RGBColor(red: 255, green: 0, blue: 127),
                RGBColor(red: 128, green: 0, blue: 255),
                RGBColor(red: 0, green: 255, blue: 255),
                RGBColor(red: 0, green: 127, blue: 255)
            ]
        ),
        AuraPreset(
            id: "classic_rog",
            name: "Republic of Gamers",
            icon: "flame.fill",
            mode: .multiStatic([.rogRed, .rogRed, .rogRed, .rogRed]),
            previewColors: [.rogRed, .rogRed, .rogRed, .rogRed]
        ),
        AuraPreset(
            id: "sunset_glow",
            name: "Sunset Glow",
            icon: "sunset.fill",
            mode: .multiStatic([
                RGBColor(red: 255, green: 40, blue: 0),
                RGBColor(red: 255, green: 120, blue: 0),
                RGBColor(red: 255, green: 0, blue: 100),
                RGBColor(red: 120, green: 0, blue: 200)
            ]),
            previewColors: [
                RGBColor(red: 255, green: 40, blue: 0),
                RGBColor(red: 255, green: 120, blue: 0),
                RGBColor(red: 255, green: 0, blue: 100),
                RGBColor(red: 120, green: 0, blue: 200)
            ]
        ),
        AuraPreset(
            id: "emerald_aurora",
            name: "Emerald Aurora",
            icon: "leaf.fill",
            mode: .multiStatic([
                RGBColor(red: 0, green: 255, blue: 128),
                RGBColor(red: 0, green: 200, blue: 255),
                RGBColor(red: 0, green: 255, blue: 80),
                RGBColor(red: 0, green: 100, blue: 255)
            ]),
            previewColors: [
                RGBColor(red: 0, green: 255, blue: 128),
                RGBColor(red: 0, green: 200, blue: 255),
                RGBColor(red: 0, green: 255, blue: 80),
                RGBColor(red: 0, green: 100, blue: 255)
            ]
        ),
        AuraPreset(
            id: "toxic_matrix",
            name: "Toxic Matrix",
            icon: "terminal.fill",
            mode: .multiStatic([
                RGBColor(red: 0, green: 255, blue: 64),
                RGBColor(red: 0, green: 200, blue: 50),
                RGBColor(red: 0, green: 255, blue: 120),
                RGBColor(red: 0, green: 180, blue: 40)
            ]),
            previewColors: [
                RGBColor(red: 0, green: 255, blue: 64),
                RGBColor(red: 0, green: 200, blue: 50),
                RGBColor(red: 0, green: 255, blue: 120),
                RGBColor(red: 0, green: 180, blue: 40)
            ]
        ),
        AuraPreset(
            id: "fire_ice",
            name: "Fire & Ice",
            icon: "snowflake",
            mode: .multiStatic([
                RGBColor(red: 255, green: 20, blue: 0),
                RGBColor(red: 255, green: 120, blue: 0),
                RGBColor(red: 0, green: 200, blue: 255),
                RGBColor(red: 0, green: 80, blue: 255)
            ]),
            previewColors: [
                RGBColor(red: 255, green: 20, blue: 0),
                RGBColor(red: 255, green: 120, blue: 0),
                RGBColor(red: 0, green: 200, blue: 255),
                RGBColor(red: 0, green: 80, blue: 255)
            ]
        ),
        AuraPreset(
            id: "vaporwave",
            name: "Synthwave Glow",
            icon: "waveform.path.ecg",
            mode: .multiStatic([
                RGBColor(red: 255, green: 113, blue: 206),
                RGBColor(red: 1, green: 205, blue: 254),
                RGBColor(red: 5, green: 255, blue: 161),
                RGBColor(red: 185, green: 103, blue: 255)
            ]),
            previewColors: [
                RGBColor(red: 255, green: 113, blue: 206),
                RGBColor(red: 1, green: 205, blue: 254),
                RGBColor(red: 5, green: 255, blue: 161),
                RGBColor(red: 185, green: 103, blue: 255)
            ]
        ),
        AuraPreset(
            id: "ocean_breathing",
            name: "Ocean Breathing",
            icon: "water.waves",
            mode: .singleBreathing(RGBColor(red: 0, green: 255, blue: 255), RGBColor(red: 0, green: 20, blue: 255), .medium),
            previewColors: [RGBColor(red: 0, green: 255, blue: 255), RGBColor(red: 0, green: 20, blue: 255)]
        ),
        AuraPreset(
            id: "fire_breathing",
            name: "Dragon Breath",
            icon: "flame.circle.fill",
            mode: .singleBreathing(RGBColor(red: 255, green: 0, blue: 0), RGBColor(red: 255, green: 100, blue: 0), .medium),
            previewColors: [RGBColor(red: 255, green: 0, blue: 0), RGBColor(red: 255, green: 100, blue: 0)]
        ),
        AuraPreset(
            id: "strobing",
            name: "White Lightning",
            icon: "bolt.fill",
            mode: .strobing(.white, .fast),
            previewColors: [.white, .white]
        )
    ]
}

// MARK: - Aura Packet Builder (ITE 8910 / Aura Core Protocol Engine)

public enum AuraPacketBuilder {
    public static let MESSAGE_LENGTH = 17

    /// Generates the initial handshake packet ("ASUS Tech.Inc.")
    public static func buildHandshakePacket() -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
        pkt[0] = 0x5a
        let text = "ASUS Tech.Inc."
        for (i, b) in text.utf8.enumerated() {
            if (1 + i) < MESSAGE_LENGTH {
                pkt[1 + i] = b
            }
        }
        return pkt
    }

    /// Generates hardware brightness control packet (0 = Off, 1 = 33%, 2 = 66%, 3 = 100%)
    public static func buildBrightnessPacket(level: Int) -> [UInt8] {
        let clamped = max(0, min(3, level))
        var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
        pkt[0] = 0x5a
        pkt[1] = 0xba
        pkt[2] = 0xc5
        pkt[3] = 0xc4
        pkt[4] = UInt8(clamped)
        return pkt
    }

    /// Generates the hardware SET commit packet
    public static func buildSetPacket() -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
        pkt[0] = 0x5d
        pkt[1] = 0xb5
        return pkt
    }

    /// Generates the hardware APPLY commit packet
    public static func buildApplyPacket() -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
        pkt[0] = 0x5d
        pkt[1] = 0xb4
        return pkt
    }

    /// Builds the complete sequence of packets required to configure a mode
    public static func buildModeTransaction(mode: AuraMode, brightness: Int = 3) -> [[UInt8]] {
        var packets = [[UInt8]]()

        // 1. Handshake header
        packets.append(buildHandshakePacket())

        // 2. Brightness register
        let bLevel = (mode == .off) ? 0 : max(0, min(3, brightness))
        packets.append(buildBrightnessPacket(level: bLevel))

        // Note: The ITE 8910 controller handles LED PWM pulse-width scaling via the
        // dedicated hardware brightness register above. We retain full 8-bit RGB color
        // precision to prevent double-dimming and preserve color saturation.
        func scaled(_ c: RGBColor) -> RGBColor {
            if bLevel == 0 { return .black }
            return c
        }

        // 3. Mode / Color payload packets
        switch mode {
        case .off:
            var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = 0x00; pkt[3] = 0x00
            packets.append(pkt)

        case .singleStatic(let color):
            let sc = scaled(color)
            var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = 0x00; pkt[3] = 0x00
            pkt[4] = sc.red; pkt[5] = sc.green; pkt[6] = sc.blue; pkt[7] = 0xeb
            packets.append(pkt)

        case .multiStatic(let zones):
            // Broadcast Zone 0 first so 1-zone laptops immediately change color
            let primaryCol = zones.first ?? .white
            let scPrimary = scaled(primaryCol)
            var allPkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            allPkt[0] = 0x5d; allPkt[1] = 0xb3; allPkt[2] = 0x00; allPkt[3] = 0x00
            allPkt[4] = scPrimary.red; allPkt[5] = scPrimary.green; allPkt[6] = scPrimary.blue; allPkt[7] = 0xeb
            packets.append(allPkt)

            // Then send individual zones for 4-zone laptops
            for i in 0..<4 {
                let col = i < zones.count ? zones[i] : (zones.last ?? .white)
                let sc = scaled(col)
                var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
                pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = UInt8(i + 1); pkt[3] = 0x00
                pkt[4] = sc.red; pkt[5] = sc.green; pkt[6] = sc.blue; pkt[7] = 0xeb
                packets.append(pkt)
            }

        case .colorCycle(let speed):
            var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = 0x00; pkt[3] = 0x02
            pkt[4] = 0xff; pkt[7] = speed.byteValue
            packets.append(pkt)

        case .rainbow(let speed):
            var allPkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            allPkt[0] = 0x5d; allPkt[1] = 0xb3; allPkt[2] = 0x00; allPkt[3] = 0x02
            allPkt[4] = 0xff; allPkt[7] = speed.byteValue
            packets.append(allPkt)

            let rainbowColors: [RGBColor] = [.red, .yellow, .cyan, .magenta]
            for i in 0..<4 {
                let sc = scaled(rainbowColors[i])
                var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
                pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = UInt8(i + 1); pkt[3] = 0x00
                pkt[4] = sc.red; pkt[5] = sc.green; pkt[6] = sc.blue; pkt[7] = speed.byteValue
                packets.append(pkt)
            }

        case .singleBreathing(let c1, let c2, let speed):
            let sc1 = scaled(c1)
            let sc2 = scaled(c2)
            var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = 0x00; pkt[3] = 0x01
            pkt[4] = sc1.red; pkt[5] = sc1.green; pkt[6] = sc1.blue
            pkt[7] = speed.byteValue
            pkt[9] = 0x01
            pkt[10] = sc2.red; pkt[11] = sc2.green; pkt[12] = sc2.blue
            packets.append(pkt)

        case .multiBreathing(let zones, let speed):
            let primary = zones.first ?? .white
            let scPrimary = scaled(primary)
            var allPkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            allPkt[0] = 0x5d; allPkt[1] = 0xb3; allPkt[2] = 0x00; allPkt[3] = 0x01
            allPkt[4] = scPrimary.red; allPkt[5] = scPrimary.green; allPkt[6] = scPrimary.blue
            allPkt[7] = speed.byteValue
            packets.append(allPkt)

            for i in 0..<4 {
                let col = i < zones.count ? zones[i] : (zones.last ?? .white)
                let sc = scaled(col)
                var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
                pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = UInt8(i + 1); pkt[3] = 0x01
                pkt[4] = sc.red; pkt[5] = sc.green; pkt[6] = sc.blue
                pkt[7] = speed.byteValue
                packets.append(pkt)
            }

        case .strobing(let color, let speed):
            let sc = scaled(color)
            var pkt = [UInt8](repeating: 0, count: MESSAGE_LENGTH)
            pkt[0] = 0x5d; pkt[1] = 0xb3; pkt[2] = 0x00; pkt[3] = 0x0a
            pkt[4] = sc.red; pkt[5] = sc.green; pkt[6] = sc.blue
            pkt[7] = speed.byteValue
            packets.append(pkt)
        }

        // 4. Commit Set & Apply
        packets.append(buildSetPacket())
        packets.append(buildApplyPacket())

        return packets
    }
}
