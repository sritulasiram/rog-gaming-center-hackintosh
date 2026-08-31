import Foundation
import AppKit
import IOKit
import IOKit.hid
import CoreGraphics

print("==================================================================")
print("  ROG KEY INPUT DETECTOR & SCANNER (macOS / Hackintosh)           ")
print("==================================================================")
print("Listening for input events across:")
print("  1. IOKit HID Input Reports & Values (ASUS ITE 8910 + All Keyboards)")
print("  2. AppKit Global Event Stream (Standard Keys, Function Keys)")
print("  3. CoreGraphics / System-Defined Media & Launch Keys")
print("------------------------------------------------------------------")
print("👉 PLEASE PRESS YOUR PHYSICAL 'ROG' KEY (AND OTHER KEYS) NOW...")
print("   (Press Ctrl+C to exit when finished)")
print("==================================================================\n")

// -----------------------------------------------------------------------------
// 1. IOKit HID Input Monitoring
// -----------------------------------------------------------------------------
let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(hidManager, nil) // Match all devices to catch everything

func hidValueCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, value: IOHIDValue) {
    let elem = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(elem)
    let usage = IOHIDElementGetUsage(elem)
    let intVal = IOHIDValueGetIntegerValue(value)
    
    // Ignore high-frequency mouse movement / axis reports (UsagePage 1, usage 0x30/0x31) to reduce noise
    if page == 1 && (usage == 0x30 || usage == 0x31 || usage == 0x38) { return }
    
    let dev = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue()
    let prod = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
    let vid = IOHIDDeviceGetProperty(dev, kIOHIDVendorIDKey as CFString) as? Int ?? 0
    let pid = IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int ?? 0
    
    let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(now)] 🕹️ [IOKit HID Input] Device: '\(prod)' (0x\(String(format: "%04X", vid)):0x\(String(format: "%04X", pid))) | UsagePage: 0x\(String(format: "%04X", page)) (\(pageName(page))) | Usage: 0x\(String(format: "%04X", usage)) | Value: \(intVal)")
}

func hidReportCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, type: IOHIDReportType, reportID: UInt32, report: UnsafeMutablePointer<UInt8>, reportLength: CFIndex) {
    let dev = Unmanaged<IOHIDDevice>.fromOpaque(sender!).takeUnretainedValue()
    let prod = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
    let vid = IOHIDDeviceGetProperty(dev, kIOHIDVendorIDKey as CFString) as? Int ?? 0
    let pid = IOHIDDeviceGetProperty(dev, kIOHIDProductIDKey as CFString) as? Int ?? 0
    
    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
    let hexStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    print("[\(now)] 📦 [IOKit Raw Report] Device: '\(prod)' (0x\(String(format: "%04X", vid)):0x\(String(format: "%04X", pid))) | ID: \(reportID) | Data [\(reportLength)B]: \(hexStr)")
}

func pageName(_ page: UInt32) -> String {
    switch page {
    case 1: return "Generic Desktop"
    case 7: return "Keyboard / Keypad"
    case 11: return "Telephony"
    case 12: return "Consumer / Media"
    case 0xFF00...0xFFFF: return "Vendor Defined (ASUS/ITE)"
    default: return "Other"
    }
}

let openRes = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
if openRes == kIOReturnSuccess {
    IOHIDManagerRegisterInputValueCallback(hidManager, hidValueCallback, nil)
    IOHIDManagerRegisterInputReportCallback(hidManager, hidReportCallback, nil)
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    print("✅ IOKit HID Manager listener successfully attached.")
} else {
    print("⚠️ IOKit HID Manager open returned \(openRes) (Check Input Monitoring permissions if needed)")
}

// -----------------------------------------------------------------------------
// 2. AppKit Global Key Event Monitor
// -----------------------------------------------------------------------------
NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .systemDefined, .flagsChanged]) { event in
    let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    
    if event.type == .keyDown {
        let keycode = event.keyCode
        let chars = event.charactersIgnoringModifiers ?? ""
        print("[\(now)] ⌨️ [Global KeyDown] KeyCode: \(keycode) (0x\(String(format: "%02X", keycode))) | Chars: '\(chars)' | Flags: 0x\(String(format: "%08X", event.modifierFlags.rawValue))")
    } else if event.type == .systemDefined {
        let subtype = event.subtype.rawValue
        let data1 = event.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA
        print("[\(now)] ⚙️ [System-Defined Event] Subtype: \(subtype) | KeyCode: \(keyCode) | State: \(keyState ? "DOWN" : "UP") | Raw Data1: 0x\(String(format: "%08X", data1))")
    }
}

// Keep run loop alive
CFRunLoopRun()
