import Foundation
import IOKit
import IOKit.hid

@main
struct AuraCLI {
    static func printUsage() {
        print("""
rogauracore - Native macOS CLI for ASUS ROG Aura RGB Keyboards
Target Hardware: ASUS ROG Strix GL503 / GL703 / GL504 / GL553 / TUF FX504 (ITE 8910 / 8291 Controller)

Usage:
   rogauracore COMMAND [ARGUMENTS...]

Commands:
   --status, -s                 Show detected ASUS Aura USB HID hardware telemetry
   --json                       Output device status and topology in JSON
   resync, -r                   Force hardware re-handshake & restore controller state
   initialize_keyboard, init    Initialize / wake keyboard controller
   brightness LEVEL             Set brightness (0 = Off, 1 = 33%, 2 = 66%, 3 = 100%)
   on                           Turn on backlight (White static, Brightness 3)
   off                          Turn off backlight completely
   single_static HEX            Set solid color for all keys (e.g. 00ffff or #ff007f)
   multi_static H1 H2 H3 H4     Set 4 separate zone colors (WASD, Center-L, Center-R, Numpad)
   single_breathing H1 H2 [SPD] Breathing animation between two colors (speed: 1, 2, 3)
   multi_breathing H1..H4 [SPD] 4-zone breathing animation (speed: 1, 2, 3)
   single_colorcycle [SPD]      Spectrum color cycle through rainbow (speed: 1, 2, 3)
   rainbow                      4-Zone spectrum preset (Red, Yellow, Cyan, Magenta)
   single_strobing HEX [SPD]    Strobing / flashing effect (speed: 1, 2, 3)
   presets                      List all available designer lighting presets
   preset NAME                  Apply a built-in preset by name (e.g. cyberpunk, sunset)

Preset Colors:
   red, green, blue, yellow, gold, cyan, magenta, white, purple, lime, orange, pink, black

Examples:
   rogauracore --status
   rogauracore single_colorcycle 2
   rogauracore multi_static ff007f 8000ff 00ffff 007fff
   rogauracore single_breathing 00ffff 0000ff 2
   rogauracore brightness 3
   rogauracore preset cyberpunk
""")
    }

    static func main() {
        let args = CommandLine.arguments

        if args.count < 2 || args.contains("-h") || args.contains("--help") {
            printUsage()
            exit(0)
        }

        let driver = AuraDriver.shared
        // Allow brief runloop run to enumerate devices reliably
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let cmd = args[1].lowercased()

        switch cmd {
        case "--status", "-s":
            if driver.isConnected, let info = driver.connectedDeviceInfo {
                print("✅ ASUS ROG Aura Keyboard Detected:")
                print("   Device Name: \(info.name)")
                print("   Vendor ID:   \(info.formattedVID) (ASUSTeK)")
                print("   Product ID:  \(info.formattedPID)")
                print("   Transport:   \(info.transport)")
                print("   Usage Page:  0x\(String(format: "%04X", info.usagePage)) (Usage: 0x\(String(format: "%04X", info.usage)))")
                if let serial = info.serialNumber {
                    print("   Serial:      \(serial)")
                }
                print("   Topology:    4-Zone RGB Backlight (ITE 8910 / 8291 Controller)")
            } else {
                print("❌ No compatible ASUS ROG Aura USB HID keyboard detected.")
                exit(1)
            }
            exit(0)

        case "--json":
            if driver.isConnected, let info = driver.connectedDeviceInfo {
                let jsonDict: [String: Any] = [
                    "connected": true,
                    "name": info.name,
                    "vendor_id": info.formattedVID,
                    "product_id": info.formattedPID,
                    "transport": info.transport,
                    "serial": info.serialNumber ?? "",
                    "usage_page": "0x\(String(format: "%04X", info.usagePage))",
                    "usage": "0x\(String(format: "%04X", info.usage))"
                ]
                if let data = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            } else {
                print("{\"connected\": false}")
                exit(1)
            }
            exit(0)

        case "resync", "-r":
            let sema = DispatchSemaphore(value: 0)
            driver.initializeKeyboard { _ in
                driver.applyMode(.colorCycle(.medium), brightness: 3) { _ in
                    sema.signal()
                }
            }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Forced hardware re-handshake and restored backlight state.")

        case "initialize_keyboard", "init":
            let sema = DispatchSemaphore(value: 0)
            driver.initializeKeyboard { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Initialized keyboard controller.")

        case "brightness":
            guard args.count >= 3, let level = Int(args[2]), (0...3).contains(level) else {
                print("Error: brightness requires an integer from 0 to 3.")
                exit(1)
            }
            let sema = DispatchSemaphore(value: 0)
            driver.setBrightness(level) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set brightness level to \(level).")

        case "on":
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.singleStatic(.white), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Turned backlight on (White, Brightness 3).")

        case "off":
            let sema = DispatchSemaphore(value: 0)
            driver.turnOff { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Turned backlight off.")

        case "single_static":
            guard args.count >= 3, let color = RGBColor(hex: args[2]) else {
                print("Error: single_static requires a hex color (e.g. 00ffff or #ff007f).")
                exit(1)
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.singleStatic(color), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set static color to #\(color.upperHexString).")

        case "multi_static":
            guard args.count >= 6 else {
                print("Error: multi_static requires 4 hex colors: <zone1> <zone2> <zone3> <zone4>")
                exit(1)
            }
            guard let c1 = RGBColor(hex: args[2]),
                  let c2 = RGBColor(hex: args[3]),
                  let c3 = RGBColor(hex: args[4]),
                  let c4 = RGBColor(hex: args[5]) else {
                print("Error: Invalid hex color provided.")
                exit(1)
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.multiStatic([c1, c2, c3, c4]), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set 4-zone static colors: #\(c1.upperHexString), #\(c2.upperHexString), #\(c3.upperHexString), #\(c4.upperHexString).")

        case "single_breathing":
            guard args.count >= 4,
                  let c1 = RGBColor(hex: args[2]),
                  let c2 = RGBColor(hex: args[3]) else {
                print("Error: single_breathing requires 2 hex colors: <color1> <color2> [speed 1-3]")
                exit(1)
            }
            var speed: AuraSpeed = .medium
            if args.count >= 5, let sp = Int(args[4]), let sEnum = AuraSpeed(rawValue: sp) {
                speed = sEnum
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.singleBreathing(c1, c2, speed), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set single breathing: #\(c1.upperHexString) <-> #\(c2.upperHexString) (Speed: \(speed.displayName)).")

        case "multi_breathing":
            guard args.count >= 6,
                  let c1 = RGBColor(hex: args[2]),
                  let c2 = RGBColor(hex: args[3]),
                  let c3 = RGBColor(hex: args[4]),
                  let c4 = RGBColor(hex: args[5]) else {
                print("Error: multi_breathing requires 4 hex colors: <z1> <z2> <z3> <z4> [speed 1-3]")
                exit(1)
            }
            var speed: AuraSpeed = .medium
            if args.count >= 7, let sp = Int(args[6]), let sEnum = AuraSpeed(rawValue: sp) {
                speed = sEnum
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.multiBreathing([c1, c2, c3, c4], speed), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set 4-zone breathing (Speed: \(speed.displayName)).")

        case "single_colorcycle", "color_cycle":
            var speed: AuraSpeed = .medium
            if args.count >= 3, let sp = Int(args[2]), let sEnum = AuraSpeed(rawValue: sp) {
                speed = sEnum
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.colorCycle(speed), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set spectrum color cycle (Speed: \(speed.displayName)).")

        case "rainbow", "rainbow_cycle":
            var speed: AuraSpeed = .medium
            if args.count >= 3, let sp = Int(args[2]), let sEnum = AuraSpeed(rawValue: sp) {
                speed = sEnum
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.rainbow(speed), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set 4-zone rainbow wave (Speed: \(speed.displayName)).")

        case "single_strobing", "strobing":
            guard args.count >= 3, let color = RGBColor(hex: args[2]) else {
                print("Error: strobing requires a hex color.")
                exit(1)
            }
            var speed: AuraSpeed = .medium
            if args.count >= 4, let sp = Int(args[3]), let sEnum = AuraSpeed(rawValue: sp) {
                speed = sEnum
            }
            let sema = DispatchSemaphore(value: 0)
            driver.applyMode(.strobing(color, speed), brightness: 3) { _ in sema.signal() }
            _ = sema.wait(timeout: .now() + 1.0)
            print("✓ Set strobing: #\(color.upperHexString) (Speed: \(speed.displayName)).")

        case "presets":
            print("Available Designer Presets:")
            for p in AuraPreset.builtInPresets {
                print("   - \(p.id.padding(toLength: 18, withPad: " ", startingAt: 0)) : \(p.name)")
            }

        case "preset":
            guard args.count >= 3 else {
                print("Error: preset requires a preset name (e.g. rogauracore preset cyberpunk)")
                exit(1)
            }
            let query = args[2].lowercased().replacingOccurrences(of: "-", with: "_")
            if let matched = AuraPreset.builtInPresets.first(where: {
                $0.id.lowercased() == query ||
                $0.name.lowercased().replacingOccurrences(of: " ", with: "_") == query ||
                $0.id.lowercased().contains(query) ||
                $0.name.lowercased().contains(query.replacingOccurrences(of: "_", with: " "))
            }) {
                let sema = DispatchSemaphore(value: 0)
                driver.applyMode(matched.mode, brightness: 3) { _ in sema.signal() }
                _ = sema.wait(timeout: .now() + 1.0)
                print("✓ Applied preset '\(matched.name)' successfully.")
            } else {
                print("Error: Unknown preset '\(args[2])'. Run 'rogauracore presets' to list all.")
                exit(1)
            }

        case "red":     applyColorShortcut(.red)
        case "green":   applyColorShortcut(.green)
        case "blue":    applyColorShortcut(.blue)
        case "yellow":  applyColorShortcut(.yellow)
        case "gold":    applyColorShortcut(.gold)
        case "cyan":    applyColorShortcut(.cyan)
        case "magenta": applyColorShortcut(.magenta)
        case "white":   applyColorShortcut(.white)
        case "purple":  applyColorShortcut(.purple)
        case "lime":    applyColorShortcut(.lime)
        case "orange":  applyColorShortcut(.orange)
        case "pink":    applyColorShortcut(.pink)
        case "black":   applyColorShortcut(.black)

        default:
            print("Unknown command: \(cmd)")
            printUsage()
            exit(1)
        }

        exit(0)
    }

    private static func applyColorShortcut(_ color: RGBColor) {
        let sema = DispatchSemaphore(value: 0)
        let mode: AuraMode = (color == .black) ? .off : .singleStatic(color)
        AuraDriver.shared.applyMode(mode, brightness: (color == .black) ? 0 : 3) { _ in
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 1.0)
        print("✓ Applied color: #\(color.upperHexString)")
    }
}
