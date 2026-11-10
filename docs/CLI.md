# CLI Reference: `rogauracore`

`rogauracore` controls the keyboard backlight from Terminal, shell scripts, Shortcuts or launchers like Raycast and Alfred. It uses the same driver as the app.

- [Install](#install)
- [Commands](#commands)
- [Colors and speeds](#colors-and-speeds)
- [Exit codes](#exit-codes)
- [Using it alongside the app](#using-it-alongside-the-app)
- [Examples](#examples)

## Install

`./build.sh --install` copies it to `/usr/local/bin` when that folder is writable. Otherwise:

```bash
sudo cp "/Applications/ROG Gaming Center.app/Contents/Resources/rogauracore" /usr/local/bin/
```

Your terminal app needs **Input Monitoring** (System Settings → Privacy & Security) for lighting writes to work.

## Commands

### Status and diagnostics

| Command | Description |
| :--- | :--- |
| `rogauracore --status`, `-s` | Show the lighting interface in use: name, vendor and product ID, transport, HID usage, maximum feature report size and serial number (if any) |
| `rogauracore --json` | The same as JSON (`connected`, `name`, `vendor_id`, `product_id`, `transport`, `usage_page`, `usage`, `serial`). When nothing is found it prints `connected` as `false` and exits with code 1. |
| `rogauracore --diagnose` | List every ASUS HID interface, mark the one used for lighting (`→`), and show the Input Monitoring state |
| `rogauracore --keys` | Print ROG hotkeys as you press them. Stop with Ctrl+C. |
| `rogauracore --help` | Show usage |

### Lighting

| Command | Arguments | Description |
| :--- | :--- | :--- |
| `init` | | Send the controller handshake |
| `brightness` | `0`–`3` | Set brightness and keep the current effect. `0` is off. |
| `on` | | White, full brightness |
| `off` | | Backlight off |
| `single_static` | `HEX` | One color on all zones |
| `multi_static` | `HEX HEX HEX HEX` | One color per zone, left to right |
| `single_breathing` | `HEX HEX [SPEED]` | Breathe between two colors (`000000` fades to off) |
| `multi_breathing` | `HEX HEX HEX HEX [SPEED]` | Per-zone breathing |
| `single_colorcycle` | `[SPEED]` | Spectrum color cycle |
| `rainbow` | `[SPEED]` | Rainbow wave |
| `single_strobing` | `HEX [SPEED]` | Strobe |
| `presets` | | List built-in presets |
| `preset` | `NAME` | Apply a built-in preset by id or name, e.g. `cyberpunk`, `sunset`, `ocean` |
| `red`, `green`, `blue`, `yellow`, `gold`, `cyan`, `magenta`, `white`, `purple`, `lime`, `orange`, `pink`, `black` | | Solid color at full brightness (`black` turns the backlight off) |

Aliases: `initialize_keyboard` (= `init`), `color_cycle` (= `single_colorcycle`), `rainbow_cycle` (= `rainbow`), `strobing` (= `single_strobing`), `resync` / `-r` (re-send the handshake).

Run `rogauracore presets` for the list of built-in preset ids. `preset` also accepts a partial id or name, so `sunset` matches `sunset_glow`.

## Colors and speeds

- **Colors:** hex `RRGGBB` or `RGB`, with or without `#` or `0x`: `ff007f`, `#ff007f`, `f07`.
- **Speeds:** `1` slow, `2` normal (default), `3` fast.

## Exit codes

| Code | Meaning |
| :--- | :--- |
| `0` | Success |
| `1` | Invalid arguments, unknown command, no lighting interface found (including `--status` and `--json`), write blocked by macOS, or write failed. The message goes to stderr. |

## Using it alongside the app

The CLI and the app never interleave packets: writes are serialized with a lock file. But the app doesn't know about CLI changes, so it restores **its own** lighting after sleep, reconnects, or when you change lighting in the app. For lasting changes, use the app or its presets. The CLI is best for scripts and one-off changes.

## Examples

```bash
# Is the controller detected?
rogauracore --diagnose

# Cyberpunk zones at full speed breathing
rogauracore multi_breathing ff007f 8000ff 00ffff 007fff 3

# Dim the backlight but keep the effect
rogauracore brightness 1

# Use in a script
# --json exits 0 only when a lighting interface is found
if rogauracore --json >/dev/null 2>&1; then
  rogauracore preset classic_rog
fi
```
