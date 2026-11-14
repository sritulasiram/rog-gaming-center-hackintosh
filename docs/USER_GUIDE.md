# User Guide

- [The window](#the-window)
- [Dashboard](#dashboard)
- [Lighting](#lighting)
- [Display](#display)
- [Status](#status)
- [Menu bar](#menu-bar)
- [Settings](#settings)
- [Keyboard hotkeys](#keyboard-hotkeys)
- [Shortcuts](#shortcuts)
- [What happens in the background](#what-happens-in-the-background)

## The window

The main window has a sidebar with four sections: **Dashboard**, **Lighting**, **Display** and **Status**. Switch between them with ⌘1–⌘4. The status at the bottom of the sidebar shows whether the keyboard is connected and accessible; click it for details.

Closing the window keeps the app running in the menu bar, unless you turn that off in Settings. Reopen it from the menu bar icon, the Dock, or the ROG key. In dark mode the Dock shows a dark version of the app icon.

## Dashboard

| Card | Shows |
| :--- | :--- |
| **Processor** | Total CPU load, user and system split, CPU model and a two-minute history |
| **Memory** | Memory in use, available and compressed |
| **Thermals** | CPU temperature with a status: Cool below 60 °C, Warm below 75 °C, Hot below 88 °C, Very hot above that. Fan speed in RPM when the SMC reports it. |
| **Battery** | Charge, charging state and time remaining. On supported batteries also health, cycle count and power draw. |
| **Keyboard** | Connection status, backlight on/off, brightness and preset, plus a link to Lighting |
| **System** | macOS name, version and build, SMBIOS model, cores, memory and uptime |

Values refresh every two seconds, and only while the dashboard is open. If CPU temperature isn't available on your machine, the Thermals card says so. See [Hackintosh Notes → Sensors](HACKINTOSH.md#sensors).

## Lighting

### Preview

The keyboard preview shows the four lighting zones as the controller will show them, including animated effects. When **Separate color per zone** is on, click a zone in the preview to edit it.

### Backlight

- **Backlight:** turns the keyboard lighting on or off. Your effect and colors are kept while it's off.
- **Brightness:** Low, Medium or High, the three hardware levels.

### Effects

| Effect | Options |
| :--- | :--- |
| **Static** | One color, or **Separate color per zone** for four zones (left to right; the fourth covers the numpad) |
| **Breathing** | A color that fades to off, or turn off **Fade to off** to breathe between two colors |
| **Color Cycle** | All zones move through the spectrum together |
| **Rainbow** | A rainbow wave travels across the zones |
| **Strobe** | A flashing color |

Breathing, Color Cycle, Rainbow and Strobe have a **Speed** setting: Slow, Normal or Fast.

Pick colors from the swatches or the color well, which opens the macOS color picker. Effects run on the keyboard controller itself, so they cost no CPU and keep running when the app is closed.

### Presets

Click a preset to apply it. To save your own:

1. Set up the effect, colors and speed you want.
2. Click **Save Current…** next to the Presets heading and give it a name.

Right-click a saved preset to **Rename** or **Delete** it. Built-in presets can't be changed. Editing any setting after applying a preset makes the lighting **Custom** until you save or pick another preset.

## Display

Choose a profile to adjust the colors of every connected display:

| Profile | Effect |
| :--- | :--- |
| **Standard** | Your display's normal calibration, unchanged |
| **Vivid** | Lifted midtones and a little more color |
| **Eye Care** | Warmer whites with less blue |
| **Cinema** | Softer contrast with gently lifted shadows |
| **FPS** | Brighter dark areas so targets in shadow stand out |
| **RTS / RPG** | Stronger midtone lift with warmer, richer color |

Profiles are applied as display gamma adjustments on top of your normal ColorSync profile. They're reapplied after sleep and when displays are connected or changed. Choosing **Standard** or quitting the app restores the normal calibration.

The **Test Pattern** helps compare profiles: each gray step should stay distinguishable from its neighbors.

## Status

- **Keyboard:** connection status, controller name, product ID, HID usage, transport and when lighting was last sent, plus **Re-sync Keyboard** to send the current lighting again.
- **Permissions:** whether Input Monitoring is allowed, with a button to fix it.
- **Sensors:** whether the SMC is available and whether it reports CPU temperature and fan speed.
- **Events:** a log of connections, permission changes, wake recoveries and errors. Clear it from the toolbar.

## Menu bar

Click the ROG icon in the menu bar for:

- **Keyboard Light** on/off and a brightness slider
- Lighting preset and display profile menus
- **Open ROG Gaming Center** (⌘O), **Settings…** (⌘,) and **Quit ROG Gaming Center** (⌘Q)

A warning appears at the top only when something needs attention: keyboard access missing, keyboard not found, or keyboard not responding. Click it for details.

## Settings

Open with ⌘, or **Settings…** in the menu bar panel.

### General

- **Open at login:** starts the app in the menu bar when you log in, without opening the window. If macOS needs your approval, the button opens Login Items in System Settings.
- **Show icon in the Dock:** when off, the app lives only in the menu bar, even while its window is open. When on, the Dock icon still disappears after you close the window if the app keeps running in the menu bar.
- **Keep running in the menu bar when the window is closed:** when off, closing the window quits the app.

### Keyboard

- **Respond to the ROG key**, and **When pressed**: show or hide the window, switch to the next preset, or turn the backlight on or off.
- **Show the brightness overlay:** shows the macOS keyboard-brightness overlay when you press Fn+↑/↓. Requires Accessibility permission.
- **Enable keyboard shortcuts:** turns the system-wide [shortcuts](#shortcuts) on or off.

## Keyboard hotkeys

Read straight from the keyboard controller:

| Key | Action |
| :--- | :--- |
| **ROG key** | The action chosen in Settings (default: show or hide the window) |
| **Fn + ↑** | Backlight brighter (off → low → medium → high) |
| **Fn + ↓** | Backlight dimmer |
| **Fn + F11** | Sleep |

The fan key and touchpad key are recognized but do nothing: macOS offers no fan control, and the touchpad is handled by its own driver. Volume, mute and display brightness keys are left to macOS and your kexts.

## Shortcuts

**System-wide** (any app, any keyboard; can be turned off in Settings → Keyboard):

| Shortcut | Action |
| :--- | :--- |
| ⌃⌥⌘↑ | Backlight brighter |
| ⌃⌥⌘↓ | Backlight dimmer |
| ⌃⌥⌘→ | Next preset |
| ⌃⌥⌘← | Previous preset |
| ⌃⌥⌘L | Backlight on / off |

**In the app** (Lighting menu and View menu):

| Shortcut | Action |
| :--- | :--- |
| ⌘1–⌘4 | Dashboard, Lighting, Display, Status |
| ⇧⌘L | Backlight on / off |
| ⌥⌘↑ / ⌥⌘↓ | Brighter / dimmer |
| ⌘] / ⌘[ | Next / previous preset |
| ⇧⌘R | Re-sync keyboard |
| ⌘, | Settings |

## What happens in the background

- **Sleep and wake:** the controller forgets its state while asleep. After wake the app sends your lighting again and reapplies the display profile.
- **Reconnects:** if the keyboard controller disappears and comes back, lighting is restored.
- **Power use:** system readings only run while the dashboard or Status screen is open. The keyboard preview only animates while visible.
- **Settings:** saved automatically, a moment after each change.
