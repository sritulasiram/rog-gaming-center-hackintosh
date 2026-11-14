import Foundation
import AuraCore
import AuraHID

@main
struct AuraCLI {
    static let usage = """
    rogauracore - control the ASUS ROG Aura keyboard backlight (ITE 8910 / 8291)

    Usage:
       rogauracore COMMAND [ARGUMENTS...]

    Status:
       --status, -s                 Show the detected Aura lighting interface
       --json                       Same, as JSON
       --diagnose                   List every ASUS HID interface and Input Monitoring state
       --keys                       Print ROG hotkeys (ROG, Fn+Up/Down, ...) as they are pressed

    Lighting:
       init                         Send the controller handshake
       brightness LEVEL             0 = off, 1-3 = low/medium/high (keeps the current effect)
       on | off                     White static at full brightness | backlight off
       single_static HEX            Solid color, e.g. 00ffff or #ff007f
       multi_static H1 H2 H3 H4     One color per zone (left -> right)
       single_breathing H1 H2 [SPD] Breathe between two colors (speed 1-3)
       multi_breathing H1..H4 [SPD] Per-zone breathing
       single_colorcycle [SPD]      Spectrum color cycle
       rainbow [SPD]                Rainbow wave
       single_strobing HEX [SPD]    Strobe
       presets                      List built-in presets
       preset NAME                  Apply a built-in preset (e.g. cyberpunk, sunset)
       red|green|blue|...|black     Shortcut for a solid color (black = off)

    Note: the app remembers its own lighting state and restores it on wake.
    """

    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first?.lowercased(), !["-h", "--help", "help"].contains(command) else {
            print(usage)
            exit(0)
        }

        let hid = AuraHIDTransport(listenForKeys: command == "--keys")
        // Let IOKit finish matching before reading the device list.
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        hid.refreshDevices()

        let rest = Array(args.dropFirst())
        switch command {
        case "--status", "-s": status(hid)
        case "--json": json(hid)
        case "--diagnose": diagnose(hid)
        case "--keys": listenForKeys(hid)
        case "init", "initialize_keyboard":
            finish(hid.sendAndWait([AuraPacketBuilder.buildHandshakePacket()]), "Initialized keyboard controller.")
        case "resync", "-r":
            finish(hid.sendAndWait([AuraPacketBuilder.buildHandshakePacket()]), "Re-sent the controller handshake.")
        case "brightness":
            guard let level = rest.first.flatMap(Int.init), (0...3).contains(level) else {
                fail("brightness requires a level from 0 to 3.")
            }
            let packets = [AuraPacketBuilder.buildHandshakePacket(), AuraPacketBuilder.buildBrightnessPacket(level: level)]
            finish(hid.sendAndWait(packets), "Set brightness to \(level).")
        case "on": apply(hid, .singleStatic(.white), "Backlight on.")
        case "off": apply(hid, .off, brightness: 0, "Backlight off.")
        case "single_static":
            let c = colors(rest, count: 1)
            apply(hid, .singleStatic(c[0]), "Static #\(c[0].upperHexString).")
        case "multi_static":
            let c = colors(rest, count: 4)
            apply(hid, .multiStatic(c), "Zones " + c.map { "#\($0.upperHexString)" }.joined(separator: " "))
        case "single_breathing":
            let c = colors(rest, count: 2)
            let s = speed(rest, at: 2)
            apply(hid, .singleBreathing(c[0], c[1], s), "Breathing #\(c[0].upperHexString) <-> #\(c[1].upperHexString) (\(s.displayName)).")
        case "multi_breathing":
            let c = colors(rest, count: 4)
            let s = speed(rest, at: 4)
            apply(hid, .multiBreathing(c, s), "Per-zone breathing (\(s.displayName)).")
        case "single_colorcycle", "color_cycle":
            let s = speed(rest, at: 0)
            apply(hid, .colorCycle(s), "Color cycle (\(s.displayName)).")
        case "rainbow", "rainbow_cycle":
            let s = speed(rest, at: 0)
            apply(hid, .rainbow(s), "Rainbow wave (\(s.displayName)).")
        case "single_strobing", "strobing":
            let c = colors(rest, count: 1)
            let s = speed(rest, at: 1)
            apply(hid, .strobing(c[0], s), "Strobe #\(c[0].upperHexString) (\(s.displayName)).")
        case "presets":
            for p in AuraPreset.builtInPresets {
                print("   \(p.id.padding(toLength: 18, withPad: " ", startingAt: 0)) \(p.name)")
            }
        case "preset":
            guard let name = rest.first else { fail("preset requires a name. Run 'rogauracore presets'.") }
            guard let preset = findPreset(name) else { fail("Unknown preset '\(name)'. Run 'rogauracore presets'.") }
            apply(hid, preset.mode, "Applied preset '\(preset.name)'.")
        default:
            if let color = namedColors[command] {
                apply(hid, color == .black ? .off : .singleStatic(color), brightness: color == .black ? 0 : 3,
                      "Color #\(color.upperHexString).")
            } else {
                print("Unknown command: \(command)\n")
                print(usage)
                exit(1)
            }
        }
        exit(0)
    }

    // MARK: - Commands

    static func status(_ hid: AuraHIDTransport) {
        guard let d = hid.device else {
            fail("No Aura lighting interface found." + accessHint(hid))
        }
        print("Aura lighting interface")
        print("   Name:        \(d.name)")
        print("   Vendor ID:   \(d.formattedVID)")
        print("   Product ID:  \(d.formattedPID)")
        print("   Transport:   \(d.transport)")
        print("   Usage:       \(d.formattedUsage)")
        print("   Feature max: \(d.maxFeatureReportSize) bytes")
        if let serial = d.serialNumber { print("   Serial:      \(serial)") }
    }

    static func json(_ hid: AuraHIDTransport) {
        var dict: [String: Any] = ["connected": hid.device != nil]
        if let d = hid.device {
            dict["name"] = d.name
            dict["vendor_id"] = d.formattedVID
            dict["product_id"] = d.formattedPID
            dict["transport"] = d.transport
            dict["usage_page"] = String(format: "0x%04X", d.usagePage)
            dict["usage"] = String(format: "0x%04X", d.usage)
            dict["serial"] = d.serialNumber ?? ""
        }
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if hid.device == nil { exit(1) }
    }

    static func diagnose(_ hid: AuraHIDTransport) {
        print("Input Monitoring: \(describe(hid.access))")
        print("ASUS HID interfaces (\(hid.interfaces.count)):")
        for d in hid.interfaces.sorted(by: { ($0.productID, $0.usagePage) < ($1.productID, $1.usagePage) }) {
            let mark = (d == hid.device) ? "→" : " "
            print(" \(mark) \(d.formattedPID)  usage \(d.formattedUsage)  feature \(d.maxFeatureReportSize)B  \(d.name)")
        }
        print(hid.device == nil ? "No interface qualifies for lighting writes." : "→ = interface used for lighting writes")
    }

    static func listenForKeys(_ hid: AuraHIDTransport) {
        guard hid.access == .granted else { fail("Input Monitoring is not granted for this terminal." + accessHint(hid)) }
        print("Listening for ROG hotkeys. Press Ctrl+C to stop.")
        hid.onKey = { key in print("  \(Date().formatted(date: .omitted, time: .standard))  \(key.rawValue)") }
        RunLoop.current.run()
    }

    // MARK: - Helpers

    static let namedColors: [String: AuraColor] = [
        "red": .red, "green": .green, "blue": .blue, "yellow": .yellow, "gold": .gold,
        "cyan": .cyan, "magenta": .magenta, "white": .white, "purple": .purple,
        "lime": .lime, "orange": .orange, "pink": .pink, "black": .black,
    ]

    static func apply(_ hid: AuraHIDTransport, _ mode: AuraMode, brightness: Int = 3, _ message: String) {
        let packets = AuraPacketBuilder.buildModeTransaction(mode: mode, brightness: brightness)
        finish(hid.sendAndWait(packets), message)
    }

    static func finish(_ result: AuraWriteResult, _ message: String) {
        switch result {
        case .success: print("✓ \(message)")
        case .noDevice: fail("No Aura lighting interface found. Run 'rogauracore --diagnose'.")
        case .accessDenied: fail("macOS blocked the write. Grant Input Monitoring to this terminal in System Settings.")
        case .busy: fail("Another app is holding the keyboard controller exclusively (for example a key remapper). Quit it and try again.")
        case .failed(let code): fail(String(format: "Write failed (IOReturn 0x%08X).", code))
        case .superseded: break
        }
    }

    static func colors(_ args: [String], count: Int) -> [AuraColor] {
        guard args.count >= count else { fail("Expected \(count) hex color(s).") }
        return args.prefix(count).map { arg in
            guard let c = AuraColor(hex: arg) else { fail("Invalid hex color '\(arg)'.") }
            return c
        }
    }

    static func speed(_ args: [String], at index: Int) -> AuraSpeed {
        guard index < args.count else { return .medium }
        guard let raw = Int(args[index]), let s = AuraSpeed(rawValue: raw) else { fail("Speed must be 1, 2 or 3.") }
        return s
    }

    static func findPreset(_ name: String) -> AuraPreset? {
        let query = name.lowercased().replacingOccurrences(of: "-", with: "_")
        return AuraPreset.builtInPresets.first {
            $0.id == query
                || $0.name.lowercased().replacingOccurrences(of: " ", with: "_") == query
                || $0.id.contains(query)
                || $0.name.lowercased().contains(query.replacingOccurrences(of: "_", with: " "))
        }
    }

    static func describe(_ access: HIDAccess) -> String {
        switch access {
        case .granted: return "granted"
        case .denied: return "denied"
        case .undetermined: return "not yet requested"
        }
    }

    static func accessHint(_ hid: AuraHIDTransport) -> String {
        hid.access == .granted ? "" : "\nInput Monitoring is \(describe(hid.access)) for this terminal (System Settings → Privacy & Security)."
    }

    static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
        exit(1)
    }
}
