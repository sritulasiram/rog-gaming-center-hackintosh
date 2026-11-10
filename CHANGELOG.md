# Changelog

All notable changes to ROG Gaming Center. Downloads are on the [Releases](https://github.com/sritulasiram/rog-gaming-center-hackintosh/releases) page.

## [Unreleased]

### Changed

- Documentation: added a contributing guide and issue templates, an events reference in Troubleshooting, upgrade notes for 1.x, and CLI corrections (`--status` fields, `--json` exit code, color shortcut brightness).

## [2.0.0] — 2026-10-25

A ground-up rebuild as a native macOS app, with a safer keyboard driver and only real system readings. Requires macOS 14 Sonoma or later. Settings and saved presets from 1.x are migrated automatically.

### Added

- Sidebar window with **Dashboard**, **Lighting**, **Display** and **Status**, a standard **Settings** window (⌘,), a Lighting menu and keyboard shortcuts (⌘1–⌘4, ⌘[ / ⌘], ⇧⌘L …).
- Simple menu bar panel: keyboard light, brightness, lighting preset and display profile. It shows a warning only when something needs attention.
- New app icon, with a dark variant shown in the Dock in dark mode, and an option to hide the Dock icon.
- Live four-zone keyboard preview that matches what the hardware can do.
- Effects: Static (one color or per zone), Breathing (to off or between two colors), Color Cycle, Rainbow and Strobe, with speed. Save, rename and delete your own presets, including animated ones.
- Dashboard: CPU load with history, memory, CPU temperature with status, battery charge, health and cycles, and system info including the SMBIOS model.
- Optional system-wide shortcuts: ⌃⌥⌘↑/↓ brightness, ⌃⌥⌘←/→ presets, ⌃⌥⌘L backlight.
- CLI: `rogauracore --diagnose` lists every ASUS HID interface and the Input Monitoring state; `rogauracore --keys` shows hotkeys as you press them.
- Disk image packaging (`make-dmg.sh`), unit tests and CI.

### Changed

- Follows the system accent color and light and dark mode.
- Display profiles apply to every connected display and are reapplied after sleep and display changes. Your normal calibration is restored when you choose Standard or quit.
- Color changes are sent latest-first, so the keyboard never lags behind a color drag.
- The ROG key, Fn+↑/↓ and Fn+F11 are read directly from the keyboard controller.
- Volume, mute, display brightness and screen-lock F-keys are left to macOS and your kexts.
- `rogauracore brightness` keeps the current effect.
- System readings only run while the Dashboard or Status screen is open.

### Fixed

- Arrow and F-keys in other apps triggered backlight, preset, lock and sleep actions. Only the keyboard's own vendor hotkeys are used now.
- Lighting packets could be sent to other ASUS USB devices. They now go only to the Aura lighting controller.
- Placeholder battery, fan and GPU values were shown as real data.
- "Re-synced" was shown even when the keyboard didn't respond.

### Removed

- Battery charge limit.
- Software multi-color strobe and the simulated GameVisual preview.
- The ROG key "toggle popover" action. It now shows or hides the window.

## [1.0.0] — 2026-09-12

First release.

- Keyboard lighting: Static, Breathing, Strobe, Spectrum Cycle and Rainbow, built-in themes and custom four-zone presets.
- Telemetry: CPU temperature, load and memory, fan status and battery metrics.
- Battery charge limit (60%, 80% or 100%) through AsusSMC.
- Six GameVisual-style display profiles, restored on quit and sleep.
- Fn hotkeys and the ROG key, a menu bar companion, and restoring lighting after sleep.
- The `rogauracore` command-line tool.

[Unreleased]: https://github.com/sritulasiram/rog-gaming-center-hackintosh/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/sritulasiram/rog-gaming-center-hackintosh/releases/tag/v2.0.0
[1.0.0]: https://github.com/sritulasiram/rog-gaming-center-hackintosh/releases/tag/v1.0.0
