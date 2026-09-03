# ROG Gaming Center for macOS & Hackintosh

<p align="center">
  <img src="Resources/app_icon.png" alt="ROG Gaming Center App Icon" width="160"/>
</p>

<p align="center">
  <b>The Complete Native Swift Control Suite for ASUS ROG & TUF Laptops on macOS</b><br/>
  <i>Featuring macOS Tahoe Liquid Glass Aesthetics, 100% Genuine Silicon Telemetry, 2-Column Aura Core Studio, Autonomous EC Cooling Telemetry, Pure Fn Physical Function Keys, Floating Capsule OSD HUD, and Standalone CLI Automation.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-v1.0.0--beta-red?style=for-the-badge" alt="Version 1.0.0-beta"/>
  <img src="https://img.shields.io/badge/Status-In%20Active%20Development-yellow?style=for-the-badge" alt="Status"/>
  <img src="https://img.shields.io/badge/Swift-5.9%2B%20Pure%20Native-orange?style=for-the-badge&logo=swift" alt="Swift 5.9+"/>
  <img src="https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue?style=for-the-badge&logo=apple" alt="macOS 11.0+"/>
  <img src="https://img.shields.io/badge/Driver-Native%20IOKit%20HID-purple?style=for-the-badge" alt="IOKit HID"/>
  <img src="https://img.shields.io/badge/Design-macOS%20Liquid%20Glass-007AFF?style=for-the-badge" alt="Liquid Glass Design"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License"/>
</p>

> [!IMPORTANT]
> **Active Development & Beta Notice:**
> This software is currently in **active development and is not yet production-ready**. You are warmly invited to try it out, experiment with its features, and help test. If you encounter any issues, bugs, or unexpected controller behavior, please [open an issue on GitHub](https://github.com/sritulasiram/rog-gaming-center-hackintosh/issues) with your hardware details and logs!

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Design System & Aesthetics](#design-system--aesthetics)
- [Key Features & Modules](#key-features--modules)
  - [1. Windows-Inspired 3-Column Dashboard (Zero Placebos)](#1-windows-inspired-3-column-dashboard-zero-placebos)
  - [2. Aura Core 2-Column Lighting Studio](#2-aura-core-2-column-lighting-studio)
  - [3. Power, Cooling & Autonomous EC Management](#3-power-cooling--autonomous-ec-management)
  - [4. Pure Fn Physical Function Keys Suite](#4-pure-fn-physical-function-keys-suite)
  - [5. macOS Tahoe Floating Capsule OSD HUD](#5-macos-tahoe-floating-capsule-osd-hud)
  - [6. CoreGraphics Display Calibration (GameVisual)](#6-coregraphics-display-calibration-gamevisual)
  - [7. Dedicated Hardware ROG Key Launcher (IOKit Native)](#7-dedicated-hardware-rog-key-launcher-iokit-native)
  - [8. Hackintosh Tools & IOKit Packet Stream Inspector](#8-hackintosh-tools--iokit-packet-stream-inspector)
  - [9. Liquid Glass Menu Bar Companion Popover](#9-liquid-glass-menu-bar-companion-popover)
  - [10. Sleep / Wake Auto-Repair Watchdog](#10-sleep--wake-auto-repair-watchdog)
  - [11. Standalone Native CLI (`rogauracore`)](#11-standalone-native-cli-rogauracore)
- [Supported Hardware & Compatibility](#supported-hardware--compatibility)
  - [Primary Verified Testbed](#primary-verified-testbed)
  - [Architecturally Compatible Models](#architecturally-compatible-models-ite-usb-hid-protocol)
- [Installation & Quick Start](#installation--quick-start)
- [macOS Privacy & Permissions (Input Monitoring)](#macos-privacy--permissions-input-monitoring)
- [CLI Reference Guide (`rogauracore`)](#cli-reference-guide-rogauracore)
- [Hackintosh Setup & OpenCore Tuning](#hackintosh-setup--opencore-tuning)
- [Codebase Structure](#codebase-structure)
- [Hardware & Backend Test Suite](#hardware--backend-test-suite)
- [Acknowledgements](#acknowledgements)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## Overview

**ROG Gaming Center for macOS** is a 100% pure native Swift application built specifically for Hackintosh enthusiasts and ASUS ROG / TUF laptop users running macOS.

Official ASUS utility software (*Armoury Crate* and *ROG Gaming Center*) is strictly Windows-exclusive and heavily burdened with background bloatware services. This project brings a lightweight, hyper-responsive, and visually stunning macOS desktop experience with:

- **Zero External Dependencies:** No Python, no libusb, no Electron, no Node.js runtime, and no C bridging headers.
- **Direct Kernel-Level Communication:** Communicates directly with internal ASUS USB HID microcontrollers via Apple's native **IOKit HID Manager** (`IOHIDManager` / `IOHIDDeviceSetReport`).
- **Hardware Safety & Latency Control:** Enforces strict 10ms FIFO micro-delay transaction queues to guarantee proper ITE 8910 PWM register latching without bus lockup.
- **100% Genuine Hardware Data (Zero Placebos):** No fake discrete GPU telemetry, no placebo memory cleaners, and no non-functional CPU power sliders. Every statistic is polled live from active kernel frameworks (`AppleSMC`, Mach VM, Mach host load, and `AppleSmartBattery`).
- **Pure Physical Fn Hotkey Suite:** Full physical function key support matching the Windows keyboard legends with pure `Fn` actuation and zero extra modifier keys needed.
- **macOS Tahoe Floating Capsule OSD HUD:** Modern Dynamic Island-style bezel pill overlays for all hardware toggles and brightness adjustments.
- **macOS Tahoe "Liquid Glass" UI:** Implements modern frosted glass vibrancy, Apple Control Center-inspired bento cards, continuous squircles, and SF Symbols typography.

---

## System Architecture

```
+---------------------------------------------------------------------------------------------------+
|                                 ROG GAMING CENTER (macOS / Hackintosh)                            |
+---------------------------------------------------------------------------------------------------+
|  [APPLE SIDEBAR] |                                [MAIN CONTENT AREA]                             |
|                  |                                                                                |
|  - Dashboard     |  [3-COLUMN COMMAND CENTER]                                                     |
|  - Aura Core     |  - Col 1: System Specs (i7-8750H, 16GB, macOS Tahoe) & Battery Flow (Live W)   |
|  - Power & Fans  |  - Col 2: AppleSMC Silicon Die Temp (TC0P), Headroom %, EC RPM & Mach Wave     |
|  - Hackintosh    |  - Col 3: Dual Glowing Circular Dials (CPU Load % & Mach RAM Utilization)      |
|    Tools         |                                                                                |
|  - Settings      |  [BOTTOM HARDWARE DOCK]                                                        |
|                  |  - Backlight Power (ON/OFF) • 4-Step Brightness • Aura Preset • GameVisual LUT |
+---------------------------------------------------------------------------------------------------+
```

### Data Flow & Communication Stack

```
+--------------------------------------------------------------------+
|  UI Layer: SwiftUI Views (Dashboard, AuraCore, PowerFans, Popover) |
+--------------------------------------------------------------------+
                                  │
                                  ▼
+--------------------------------------------------------------------+
|  Service Layer: AuraService, TelemetryService & HUDService         |
|  - State Management, Sleep/Wake Watchdog, Global Fn Key Monitor    |
|  - CoreGraphics Display Gamma Calibration, AppleSmartBattery Poller|
+--------------------------------------------------------------------+
                                  │
                                  ▼
+--------------------------------------------------------------------+
|  Driver Layer: AuraDriver & SMCReader (IOKit HID & AppleSMC Engine)|
|  - Device Matching (VID 0x0B05, PID 0x1869, Usage Page 0xFF89)     |
|  - FIFO Serial Queue with 10ms Micro-Delay Register Latching       |
|  - Direct AppleSMC TC0P Kernel Register Access                     |
+--------------------------------------------------------------------+
                                  │
                                  ▼
+--------------------------------------------------------------------+
|  Hardware Layer: ITE 8910 USB Controller & Motherboard ITE 8987 EC |
|  - 17-Byte Feature Reports: Handshake -> Brightness -> Set -> Latch|
|  - Autonomous Hardware Fan Curve (Coffee Lake DTS Silicon Plate)   |
+--------------------------------------------------------------------+
```

---

## Design System & Aesthetics

The interface is engineered around Apple Human Interface Guidelines and modern **macOS Tahoe "Liquid Glass"** visual aesthetics:

- **Apple-Native Minimalist Sidebar:**
  - Single clean Apple HIG navigation list without artificial group labels or bottom status box clutter.
  - Aligned under window traffic light buttons (`.fullSizeContentView`).
  - Monochromatic SF Symbols with continuous rounded squircles (`RoundedRectangle(cornerRadius: 6, style: .continuous)`).
- **Windows-Inspired 3-Column Command Stage:**
  - Homage to the official Windows ROG Gaming Center layout, adapted with clean typography, dark frosted materials, and zero clutter.
- **Aura Core 2-Column Studio:**
  - Homage to the official ASUS AURA Windows design: 70% width GL503 keyboard stage on the left, dedicated controls and red `APPLY` button on the right.
- **Floating Capsule OSD HUD:**
  - Modern Dynamic Island-style floating pill capsule at the bottom-center of the screen with smooth spring animations.
- **Liquid Glass Menu Bar Popover:**
  - Ultra-compact geometry (`290 × 320 pt`) with transient background dimming.
  - Glowing circular power orb, dual vitals bento cards, brightness capsule slider, and GameVisual display LUT switcher.

---

## Key Features & Modules

### 1. Windows-Inspired 3-Column Dashboard (Zero Placebos)
- **Column 1 (Hardware Specification & Battery Telemetry):**
  - Processor brand, 6-Core / 12-Thread topology, 16 GB Dual-Channel DDR4, ASUS ROG Strix GL503GE model identity, and kernel uptime.
  - Genuine IOKit `AppleSmartBattery` telemetry: Live power draw in Watts ($V \times A$), voltage, health percentage, cycle count, and charging state.
- **Column 2 (Silicon Thermal Stage - Hero Readout):**
  - Direct read from kernel `AppleSMC` silicon die register (`TC0P`) with verified `[SMC]` badge.
  - Real-time Thermal Headroom percentage ($100 - T_{\text{die}}$) calculating distance to the 100°C junction thermal limit.
  - Dual Blower Cooling Array phase indicator (`🟢 Quiet Airflow < 52°C`, `🟡 Active Cooling 52–75°C`, `🔴 Thermal Turbo > 75°C`) and autonomous hardware EC RPM.
  - 24-point live rolling CPU load waveform based on Mach kernel host ticks.
- **Column 3 (Dual Circular Gauges):**
  - **CPU Activity Dial:** Glowing circular progress ring tracking total Mach CPU load percentage.
  - **RAM Memory Dial:** Glowing circular progress ring tracking 64-bit Mach VM allocated memory (Active + Wired + Compressed / Total).
- **Bottom Hardware Tray (Windows Dock Homage):**
  - 4 quick hardware control cards: Backlight Power (ON/OFF), 4-step Brightness (`0`, `33%`, `66%`, `100%`), Aura Core mode with quick cycle, and GameVisual display calibration.

### 2. Aura Core 2-Column Lighting Studio
- **2-Column Layout (Zero Vertical Scrolling):**
  - Fits the application window comfortably with everything accessible in a single glance.
- **70% Left Stage (Physical GL503 Keyboard Canvas):**
  - Vector GL503 keyboard chassis framed inside technical crop brackets (`┌ ┐ └ ┘`).
  - Dedicated top hotkeys (Volume -, Volume +, Mic Mute, ROG Key).
  - 4 physical lighting zones: Zone 1 (WASD), Zone 2 (Center-L), Zone 3 (Center-R), Zone 4 (Numpad).
  - In `4-ZONE CUSTOM` mode, clicking any zone selects it and presents an inline quick-color palette, custom hex field, and native macOS color wheel (`NSColorPanel`).
- **30% Right Panel (Controls Stack):**
  - **Brightness Selector:** Segmented bar (`Off`, `33%`, `66%`, `100%`).
  - **Effects Radio List:** Matches official ASUS AURA modes: `Static`, `Breathing`, `Color Cycle`, `Rainbow`, and `Strobing`.
  - **Tempo (Speed):** 3 speed notches (`Slow`, `Medium`, `Fast`).
  - **Apply Button:** Prominent red button that commits 17-byte HID packets directly to the ITE 8910 controller with visual confirmation.

### 3. Power, Cooling & Autonomous EC Management
- **Dual Blower Cooling Array:** Real-time RPM readout for the shared thermal cooling plate governed by Intel Coffee Lake DTS silicon junction curves.
- **Autonomous Hardware EC Management:** Full technical transparency into the motherboard ITE IT8987 Embedded Controller on hardware ports `0x62`/`0x66`:
  - **Quiet Airflow (< 52°C):** ~1,800 RPM whisper-quiet operation.
  - **Active Cooling (52–75°C):** ~2,400 RPM balanced acoustic profile.
  - **Thermal Turbo (> 75°C):** Up to 3,315 RPM maximum heat dissipation.
- **Smart Battery Saver:** Automatically dims the keyboard backlight to 33% when unplugged from AC power and restores full brightness upon reconnecting.

### 4. Pure Fn Physical Function Keys Suite
Enjoy complete physical keyboard hotkey integration matching the printed ASUS Windows legends using **pure `Fn` key actuation** (zero extra modifiers required):

| Physical Hotkey | Printed Legend | Action |
| :--- | :--- | :--- |
| **`Fn + Up Arrow`** (↑) / **`Fn + F8`** | Backlight Up | Steps keyboard brightness UP (Off -> 33% -> 66% -> 100%) |
| **`Fn + Down Arrow`** (↓) / **`Fn + F7`** | Backlight Down | Steps keyboard brightness DOWN (100% -> 66% -> 33% -> Off) |
| **`Fn + Right Arrow`** (→) | Aura Mode Next | Cycles next RGB animation (`Static` -> `Breathing` -> `Cycle` -> `Rainbow` -> `Strobe`) |
| **`Fn + Left Arrow`** (←) | Aura Mode Prev | Cycles previous RGB animation |
| **`Fn + Space`** | Backlight Power | Instantly toggles keyboard backlight on/off (Mute / Wake) |
| **`Fn + F1`** | Audio Mute | Toggles macOS system audio mute |
| **`Fn + F2` / `Fn + F3`** | Volume Down / Up | Steps macOS system volume down / up |
| **`Fn + F4` / `Fn + F5`** | Display Dim / Bright | Steps laptop screen display brightness down / up |
| **`Fn + F6`** | Touchpad Toggle | Toggles trackpad on/off |
| **`Fn + F9`** | Screen Lock | Immediately locks the macOS screen |
| **`Fn + F11`** | System Sleep | Puts macOS to sleep |
| **Physical ROG Key** | ROG Logo | Instantly opens / toggles the ROG Gaming Center window |

### 5. macOS Tahoe Floating Capsule OSD HUD
- Built with a non-activating, click-through `NSPanel` (`level: .floating`) that floats seamlessly over all full-screen apps and games.
- Provides immediate visual feedback with smooth spring animations for:
  - Keyboard backlight brightness levels (with 4-step progress fill)
  - Backlight power on/off
  - Aura Core lighting mode switches
  - Touchpad enabled / disabled
  - System volume & mute
  - Display brightness adjustments
  - Screen lock confirmation

### 6. CoreGraphics Display Calibration (GameVisual)
- Direct display transfer table calibration via `CGGetDisplayTransferByTable` and `CGSetDisplayTransferByTable`:
  - **Default Standard:** Restores native factory gamma transfer curves.
  - **Eye Care (Warm):** Attenuates harsh blue 450nm spectral spikes (~22% reduction) for nighttime reading comfort.
  - **Vivid Gaming:** Steepens midtone contrast curve for vibrant in-game visual clarity.
  - **Cinema Mode:** Lifts shadow detail and enriches deeper tone gradients.

### 7. Dedicated Hardware ROG Key Launcher (IOKit Native)
- **Direct ITE 8910 Hardware Interception:** Intercepts hardware input report `0x5A` payload `0x38` (`UsagePage: 0xFF31`, `Usage: 0x0038`) emitted by the physical ROG / Armoury Crate keyboard button via Apple's native `IOHIDManager`.
- **Zero Daemon & Zero ACPI Hacks:** Requires no Karabiner-Elements, no external key daemons, and no custom DSDT/SSDT EC method re-routes.
- **Configurable One-Touch Actions:**
  - **Toggle Main Window:** Instant press-to-reveal / press-to-dismiss behavior identical to Windows Armoury Crate.
  - **Toggle Menu Bar HUD:** Opens/closes the compact Liquid Glass popover.
  - **Cycle Aura RGB Presets:** Cycles through built-in and custom lighting profiles.
  - **Toggle Backlight Power:** Instant night-mode backlight shutoff.
- **Hardware Debouncing:** Enforces 250ms hardware debounce to prevent duplicate triggers on physical key actuation.

### 8. Hackintosh Tools & IOKit Packet Stream Inspector
- **System Readiness Health Bar:** Instant visual diagnostic indicators for IOKit USB HID matching, ITE 8910 controller presence, ROG key HID listener state, sleep watchdog daemon status, and CLI binary installation.
- **One-Click Self Test:** Dispatches test transactions and validates hardware response.
- **Live 17-Byte Feature Report Inspector:**
  - Real-time visualization of the exact 17-byte raw HID report dispatched over the USB bus:
    ```
    [5D] [B3] [00] [01] [FF] [00] [33] [80] [00] [FF] [00] [FF] [FF] [00] [7F] [FF] [00]
    MAGIC CMD  ZONE MODE <--- Z1 RGB ---> <--- Z2 RGB ---> <--- Z3 RGB ---> <--- Z4 RGB ---> SPD
    ```
  - One-click **Copy Hex** button for debugging in IORegistryExplorer or Wireshark.
- **Sleep / Wake Watchdog Timeline (Console.app Style):**
  - Live chronological audit log of power events (`willSleepNotification`, `didWakeNotification`) and handshake ack timings.
- **Automation Shortcuts & Terminal Launcher:**
  - Direct execution ("Run Now" button) or external Terminal execution ("Terminal" button) for common scripting routines.

### 9. Liquid Glass Menu Bar Companion Popover
- Discreet status icon in the macOS menu bar.
- Left-click triggers the rich `290 × 320 pt` Liquid Glass Popover with live EC cooling status, thermals, battery telemetry, brightness slider, GameVisual display LUT profiles, and quick hardware actions.
- Right-click or Control-click reveals a fast native context menu with brightness levels, preset submenus, hardware re-sync, and quit actions.

### 10. Sleep / Wake Auto-Repair Watchdog
- **The Issue:** ASUS ITE 8910 / 8291 USB HID controllers lose volatile register state when resuming from macOS system sleep (entering an unlit or default maroon state).
- **The Fix:** An automatic background observer monitors `NSWorkspace.didWakeNotification`, `screensDidWakeNotification`, and `sessionDidBecomeActiveNotification`. After a 600ms debounce, it re-transmits the `"ASUS Tech.Inc."` handshake and reapplies the user's active lighting profile with zero manual intervention.

### 11. Standalone Native CLI (`rogauracore`)
- Bundled pure Swift command-line tool with zero external runtime dependencies.
- Perfect for shell scripts, Terminal aliases, keyboard shortcut daemons (skhd), Alfred workflows, Raycast script commands, and Elgato Stream Deck integrations.

---

## Supported Hardware & Compatibility

### Primary Verified Testbed
- **Model:** ASUS ROG Strix GL503GE
- **Controller:** ITE 8910 USB HID Controller (`VID: 0x0B05`, `PID: 0x1869`)
- **Lighting:** 4-Zone RGB Backlight
- **Status:** **Fully Tested & 100% Verified** across all IOKit HID features, 4-zone lighting studio, dual-fan telemetry, battery care thresholds, and sleep/wake auto-repair watchdog.

### Architecturally Compatible Models (ITE USB HID Protocol)
The following models utilize the same ASUS ITE USB HID microcontroller protocol (`0x5A` handshake, `0x5D 0xB3` packet structure, `0x5D 0xB5` set, `0x5D 0xB4` apply) according to open-source reverse-engineering specifications (`rogauracore` / Linux kernel `asus-wmi` / `AsusSMC`). If you own one of these models, the application is designed to communicate with your controller out-of-the-box:

| Series | Models | Controller / Protocol Status |
| :--- | :--- | :--- |
| **ROG Strix (15" & 17")** | GL503GE | **Verified Working (Primary Testbed)** |
| **ROG Strix (15" & 17")** | GL503VD, GL503VS, GL503VM, GL703, GL703GE, GL703GS, GL703VD | Compatible (ITE 8910 / 8291 Protocol) |
| **ROG Strix SCAR & Hero** | GL504, GL504GM, GL504GS (SCAR II / Hero II), GL553, GL553VD, GL553VE, GL753 | Compatible (ITE 8910 / 8291 Protocol) |
| **ROG Zephyrus** | GX501, GM501, GA503, G531, G533, G733 | Compatible (Aura Core Protocol) |
| **TUF Gaming** | FX504, FX505, FX705 (RGB models) | Compatible (ITE USB HID 1-Zone / 4-Zone) |


---

## Installation & Quick Start

### 1-Click Build & Install to `/Applications`

Clone the repository and run the build script with the `--install` flag:

```bash
git clone https://github.com/sritulasiram/rog-gaming-center-hackintosh.git
cd rog-gaming-center-hackintosh
./build.sh --install
```

This automated script will:
1. Compile the native Swift application (`ROG Gaming Center.app`).
2. Compile the standalone CLI utility (`rogauracore`).
3. Package the app bundle with high-resolution icons and Info.plist.
4. Apply consistent ad-hoc or developer code-signing.
5. Install the app to `/Applications/ROG Gaming Center.app`.
6. Install the CLI binary to `/usr/local/bin/rogauracore` (if writable).
7. Reset stale TCC cache entries (`tccutil reset ListenEvent com.asus.roggamingcenter`) to prompt for Input Monitoring permissions.
8. Launch the application.

### Manual Build

```bash
./build.sh
```

**Build Artifacts:**
- Application Bundle: `./build/ROG Gaming Center.app`
- Standalone CLI: `./build/rogauracore`

### Custom Code-Signing (Survives Rebuilds)

To prevent macOS from resetting your Input Monitoring permission after every rebuild, sign with your local Apple Development certificate:

```bash
SIGNING_IDENTITY="Apple Development: your_email@example.com (XXXXXXXXXX)" ./build.sh --install
```

---

## macOS Privacy & Permissions (Input Monitoring)

Because the keyboard backlight controller is an internal USB HID device that shares an interface with the physical keyboard, macOS treats vendor feature report writes as sensitive input events.

### How to Grant Permission:

1. Open **System Settings** → **Privacy & Security** → **Input Monitoring**.
2. Enable the toggle for **ROG Gaming Center**.
3. If prompted, select **Quit & Reopen**.

```
+-----------------------------------------------------------------------+
|  System Settings > Privacy & Security > Input Monitoring              |
|                                                                       |
|  [ ✓ ] ROG Gaming Center                                              |
|                                                                       |
|  Allows ROG Gaming Center to send USB HID feature reports to the      |
|  internal ITE keyboard backlight controller.                          |
+-----------------------------------------------------------------------+
```

### In-App Detection & Deep Link

If macOS blocks HID writes, the app detects `kIOReturnNotPermitted` immediately and displays a prominent status banner in the sidebar with a direct button: **"Grant Input Monitoring Access"**, which opens System Settings straight to the Input Monitoring pane.

---

## CLI Reference Guide (`rogauracore`)

The bundled standalone CLI utility (`rogauracore`) provides complete terminal control:

### Command Overview

| Command | Arguments | Description | Example |
| :--- | :--- | :--- | :--- |
| `--status`, `-s` | *None* | Displays detected USB HID hardware telemetry | `rogauracore --status` |
| `--json` | *None* | Outputs device topology and info in JSON format | `rogauracore --json` |
| `resync`, `-r` | *None* | Forces hardware handshake and restores state | `rogauracore resync` |
| `init`, `initialize_keyboard` | *None* | Wakes and initializes the controller | `rogauracore init` |
| `brightness` | `<0-3>` | Sets backlight brightness (0=Off, 1=33%, 2=66%, 3=100%) | `rogauracore brightness 3` |
| `on` | *None* | Turns on backlight (White, 100% brightness) | `rogauracore on` |
| `off` | *None* | Turns off backlight completely | `rogauracore off` |
| `single_static` | `<HEX>` | Sets a single solid color for all keys | `rogauracore single_static 00f0ff` |
| `multi_static` | `<Z1> <Z2> <Z3> <Z4>` | Sets 4 distinct zone colors (WASD, Mid, Right, Num) | `rogauracore multi_static ff007f 8000ff 00ffff 007fff` |
| `single_breathing` | `<HEX1> <HEX2> [SPD 1-3]` | Breathing animation between 2 colors | `rogauracore single_breathing 00ffff 0000ff 2` |
| `multi_breathing` | `<Z1> <Z2> <Z3> <Z4> [SPD]` | 4-zone simultaneous breathing effect | `rogauracore multi_breathing ff0000 00ff00 0000ff ffff00 2` |
| `single_colorcycle` | `[SPD 1-3]` | Spectrum rainbow color cycle | `rogauracore single_colorcycle 2` |
| `rainbow` | `[SPD 1-3]` | 4-Zone rainbow wave effect | `rogauracore rainbow 2` |
| `single_strobing` | `<HEX> [SPD 1-3]` | Fast strobing / flashing effect | `rogauracore single_strobing ffffff 3` |
| `presets` | *None* | Lists all available designer presets | `rogauracore presets` |
| `preset` | `<name>` | Applies a preset by name or keyword | `rogauracore preset cyberpunk` |
| `<color_name>` | *None* | Shortcut for standard colors (`red`, `cyan`, `gold`, etc.) | `rogauracore cyan` |

### Scripting Examples

```bash
# Set a Cyberpunk neon aesthetic
rogauracore preset cyberpunk

# Set solid ROG Crimson at maximum brightness
rogauracore single_static ff0033
rogauracore brightness 3

# Dim keyboard for nighttime coding
rogauracore brightness 1

# Extract JSON status in a shell script
CONNECTED=$(rogauracore --json | grep '"connected"' | awk '{print $2}')
```

---

## Hackintosh Setup & OpenCore Tuning

1. **USB Port Mapping (Crucial):**
   - Ensure the internal USB keyboard controller (usually located on `HS07` or `HS05`, Vendor ID `0x0B05`) is declared as **Internal (`Type 255`)** in your OpenCore `USBMap.kext` or `UTBMap.kext`. Marking it as an external USB port will cause controller disconnections during sleep transitions.
2. **Kext Compatibility:**
   - Works harmoniously alongside `VirtualSMC.kext` and `AsusSMC.kext` (which manages Fn hotkeys and ACPI battery threshold calls `BCLM` / `CBAT`).
3. **Sleep Watchdog Optimization:**
   - ROG Gaming Center operates completely in user space without requiring root daemons or custom sleep/wake shell scripts in `/usr/local/bin`.

---

## Codebase Structure

```
rog-gaming-center/
├── LICENSE                        # MIT License
├── README.md                      # Comprehensive Documentation
├── ROGGamingCenter.entitlements   # macOS Code-Signing Entitlements (Un-sandboxed)
├── build.sh                       # Automated Compiler, Packager & Installer
├── Resources/
│   ├── AppIcon.icns               # macOS High-Resolution Application Icon
│   ├── app_icon.png               # PNG App Icon for UI & Documentation
│   ├── logo.png                   # ROG Fearless Eye Logo
│   ├── menubar_icon.png           # 1x Menu Bar Status Icon (Template)
│   ├── menubar_icon@2x.png        # 2x Retina Menu Bar Status Icon (Template)
│   ├── rog_emblem_red.svg         # Vector ROG Red Emblem
│   └── rog_emblem_white.svg       # Vector ROG White Emblem
├── Sources/
│   ├── main.swift                 # App Lifecycle, NSWindow, NSStatusItem & Key Router
│   ├── AuraProtocol.swift         # 17-Byte Packet Builder, RGB Models, Modes & Curves
│   ├── AuraDriver.swift           # Native IOKit HID Manager, Device Matching & Micro-Delays
│   ├── AuraService.swift          # Core Service: Pure Fn Hotkeys, Presets, Sleep Watchdog
│   ├── SMCReader.swift            # Direct AppleSMC Kernel Hardware Access (TC0P Thermals)
│   ├── DisplayCalibrationService.swift # CoreGraphics Gamma Table Calibration (GameVisual)
│   ├── HUDService.swift           # macOS Tahoe Floating Capsule OSD HUD Engine
│   ├── TelemetryService.swift     # Telemetry Engine: CPU Load, Mach VM, AppleSmartBattery
│   ├── AuraCLI.swift              # Standalone 'rogauracore' CLI Binary Entry Point
│   ├── AuraPopoverView.swift      # Liquid Glass Menu Bar Companion Popover View
│   └── Views/
│       ├── MainWindowView.swift   # Main App Window, Minimalist Apple Sidebar & Routing
│       ├── DashboardView.swift    # Windows 3-Column Command Center, Sparkline & Vitals
│       ├── AuraStudioView.swift   # Windows 2-Column Aura Core Studio & GL503 Key Matrix
│       ├── PowerFanView.swift     # Dual Blower Array, Autonomous EC Curves & Diagnostics
│       ├── HackintoshToolsView.swift # IOKit Packet Inspector, Console Timeline & Tools
│       ├── SettingsView.swift     # Launch at Login, ASUS ROG Function Keys Cheat Sheet
│       └── ROGLogoView.swift      # Vector ROG Fearless Eye Shape & Image Loader
└── Tests/
    └── test_backend.swift         # Hardware & IOKit HID Validation Suite
```

---

## Hardware & Backend Test Suite

To run the automated backend test suite directly against your laptop's internal USB HID controller:

```bash
swift -framework IOKit -framework Foundation ./Tests/test_backend.swift
```

### Verified Test Points:
- `[Test Point 1]` IOKit HID Discovery, Vendor Matching & Usage Page Identification
- `[Test Point 2]` Controller Handshake (`"ASUS Tech.Inc."`) & Brightness Register Verification
- `[Test Point 3]` RGB Color Payload Dispatch & Hardware SET/APPLY Latch Commits
- `[Test Point 4]` Dynamic Hardware Animation Mode Dispatch (Spectrum Cycle `0x02`)
- `[Test Point 5]` Host Kernel Telemetry Extraction (`sysctl`, `mach_host_self`)

---

## Acknowledgements

- **[wrobelda / wroberts](https://github.com/wroberts/rogauracore)** — Reverse-engineering of the ASUS ROG Aura ITE USB protocol and creation of the original Linux `rogauracore` utility.
- **[black-dragon74](https://github.com/black-dragon74/macRogAuraCore)** — Early macOS IOKit HID experiments and USB protocol exploration.
- **[hieplpvip](https://github.com/hieplpvip/AsusSMC)** — Creator of `AsusSMC.kext` and pioneer of ASUS laptop hardware control on macOS.
- **[Acidanthera](https://github.com/acidanthera)** — OpenCore, Lilu, VirtualSMC, and the foundation of the modern Hackintosh ecosystem.
- **[Seerge / G-Helper](https://github.com/seerge/g-helper)** & **[asusctl](https://gitlab.com/asus-linux/asusctl)** — Inspiration for clean, lightweight, all-in-one ASUS hardware control without background bloatware.
- **ASUS (Republic of Gamers)** — Engineering of the ROG and TUF laptop hardware.

---

## Disclaimer

- **Educational & Research Purposes Only:** This software and project is developed strictly for **educational, academic, and non-commercial hardware interoperability research purposes**.
- **Copyright & Trademark Non-Infringement:** This project does not intend to infringe upon, claim ownership of, or challenge any copyrights, intellectual property, patents, or trademarks owned by **ASUSTeK Computer Inc. (ASUS)**, **Apple Inc.**, or any of their respective subsidiaries or affiliates.
- **Non-Affiliation:** This project is an independent open-source community research tool and is **not affiliated with, maintained, authorized, endorsed, or sponsored by ASUSTeK Computer Inc. (ASUS) or Apple Inc.**
- **Trademarks:** All product names, logos, brands, emblems, and registered trademarks (including *ASUS*, *ROG*, *Republic of Gamers*, *Aura*, *Armoury Crate*, *Apple*, *macOS*, and *MacBook*) are the exclusive property of their respective owners. Any use of these names or marks within this repository is purely for identification, descriptive, and nominative interoperability purposes.
- **"AS IS" Hardware & Software Use:** This software interacts directly with internal USB HID microcontroller hardware and system statistics. While thoroughly tested with micro-delay safety FIFO queues, this software is provided **"AS IS" WITHOUT WARRANTY OF ANY KIND**, express or implied. The authors and contributors assume no liability for any issues, hardware behaviors, or data loss arising from its use.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
