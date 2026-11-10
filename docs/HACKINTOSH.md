# Hackintosh Notes

- [Compatible laptops](#compatible-laptops)
- [USB mapping](#usb-mapping)
- [Sensors](#sensors)
- [Fn keys and other kexts](#fn-keys-and-other-kexts)
- [SMBIOS](#smbios)

## Compatible laptops

The app works with laptops that use ASUS's ITE USB lighting controller and the Aura protocol (`0x5A` handshake, `0x5D 0xB3` mode, `0x5D 0xB5` set, `0x5D 0xB4` apply).

| Series | Models | Status |
| :--- | :--- | :--- |
| ROG Strix | **GL503GE** | **Verified** |
| ROG Strix | GL503VD, GL503VS, GL503VM, GL703, GL703GE, GL703GS, GL703VD | Expected to work |
| ROG Strix SCAR / Hero | GL504, GL504GM, GL504GS, GL553, GL553VD, GL553VE, GL753 | Expected to work |
| ROG Zephyrus | GX501, GM501, GA503, G531, G533, G733 | Expected to work |
| TUF Gaming | FX504, FX505, FX705 (RGB models) | Expected to work |

"Expected to work" means the model is known to use a supported product ID, but nobody has confirmed it yet. If you try one, please report the result (see [Reporting a bug](TROUBLESHOOTING.md#reporting-a-bug)) so its status can be updated.

To check your machine, run:

```bash
rogauracore --diagnose
```

It lists every ASUS HID interface and marks with `→` the one the app writes to. The app only writes to an ASUS interface on a vendor usage page that accepts full-size feature reports, so other ASUS devices such as mice and docks are never touched. If no interface is marked, please open an issue with the output.

The list of known product IDs is `AuraInterfaceSelector.knownProductIDs` in `Sources/AuraCore/HardwareKeys.swift`. An unlisted ID can still work if the interface is on a vendor usage page that accepts full-size feature reports; `--diagnose` shows what was selected.

## USB mapping

The keyboard controller is an internal USB device (vendor `0x0B05`), commonly on port `HS05` or `HS07`. In your USB map (`USBMap.kext`, `UTBMap.kext` or similar), set that port to **internal (type 255)**. If it's mapped as external, or left out, the controller can disappear after sleep. You'd then see "Keyboard not found" until a restart.

## Sensors

The dashboard only shows readings macOS actually provides. Nothing is estimated.

| Reading | Source | How to get it on a Hackintosh |
| :--- | :--- | :--- |
| CPU load, memory, uptime | macOS kernel | Always available |
| Battery charge and charging state | macOS power management | Needs a working battery setup (for example ECEnabler plus battery patches) |
| Battery health, cycles, power | `AppleSmartBattery` | Present when the battery driver reports design and full-charge capacity in mAh |
| **CPU temperature** | SMC keys `TC0P`, `TC0D`, `TC0E`, `TC0F`, `TC1C`–`TC4C`, `TCXC` | VirtualSMC with **SMCProcessor** (Intel) or **SMCAMDProcessor** (AMD) |
| **Fan speed** | SMC keys `F0Ac` / `F0Mx` | A kext that publishes fan keys to VirtualSMC, such as **SMCSuperIO** where the chip is supported |

### About fan speed

On many ASUS laptops the fans are driven by the embedded controller (EC), and no macOS kext reads them. SMCSuperIO targets desktop Super I/O chips and usually doesn't support laptop ECs. If nothing publishes the `F0Ac` key, macOS has no fan reading. The app then shows only the CPU temperature, and **Status → Sensors** lists fan speed as "Not reported" (and shows "Reported" when a value is available). The fans themselves still work normally under the EC's control.

The app never controls fans, and macOS offers no way to do it on this hardware. The Fn+F5 fan key is recognized but intentionally does nothing.

To see what your SMC exposes, check **Status → Sensors**. You can also use a VirtualSMC tool such as `smcread`, or HWMonitorSMC2.

## Fn keys and other kexts

The app only handles keys that arrive as ASUS vendor HID reports from the keyboard controller: ROG key, Fn+↑/↓ (backlight) and Fn+F11 (sleep). Other Fn keys are left alone, so they keep working through whatever handles them today:

| Keys | Usually handled by |
| :--- | :--- |
| Volume, mute | macOS, via AsusSMC or VoodooPS2 key mapping |
| Display brightness | AsusSMC / BrightnessKeys |
| Touchpad on/off | VoodooI2C / VoodooPS2 |
| Airplane mode, camera | ACPI / AsusSMC |

To see which hotkeys the controller sends on your model:

```bash
rogauracore --keys
```

The output only lists keys the app understands. If your ROG key or backlight keys don't show up, open an issue with your model.

## SMBIOS

The System card shows your SMBIOS model identifier (for example `MacBookPro16,4`), as set in your OpenCore `config.plist`. The app doesn't depend on it; it's shown because it helps when comparing reports from different setups.
