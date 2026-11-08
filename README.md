# LegacyUI

Liquid Glass inspired system interface redesign for jailbroken iOS — supports both **iOS 6.1 on the iPhone 3GS** and **iOS 8.0–8.4.1** from a single armv7 binary.

## Features

- **Control Center**: swipe (or tap) from the bottom of the home screen opens an interactive Liquid Glass panel (iOS 6 style)
  - Toggle row: Wi-Fi, Bluetooth, Do Not Disturb, Airplane Mode — active toggles glow violet, wired to real service APIs (`SBWiFiManager`, `BluetoothManager`, `RadiosPreferences`, `com.apple.DoNotDisturb` preferences)
  - Vertical sliders: brightness (`setBacklightFactor:`) and volume (routes to `VolumeControl` on iOS 6 / `MPVolumeView` on iOS 8)
  - Music square with previous / play-pause / next controls and live track title + artist in the panel header (`SBMediaController`)
  - Hardware volume buttons do not pop the volume pill while the Control Center is open — the volume slider follows them live
  - Home button closes the Control Center first; the gear closes it and opens Settings
  - Transform-only panel movement — smooth on the 3GS GPU (SGX535)
- **Dock**: floating Liquid Glass capsule design (classic iOS 6 icon graphics)
- **Lock Screen**: complete visual redesign with adaptive clock and notifications
- **Volume HUD**: compact floating glass pill that stays visible over apps and the lock screen; controls the system ringer HUD
- **Runtime verification**: place an empty marker file `/var/mobile/.legacyui_probe`; on the next respring the tweak dumps the real method lists of service classes (`SBWiFiManager`, `BluetoothManager`, `RadiosPreferences`, `SBMediaController`, `VolumeControl`, `SpringBoard`) to `/var/mobile/legacyui_probe.txt` — ground truth from the actual binary, used to wire private APIs safely

## Requirements

- iOS 6.1 (iPhone 3GS) or iOS 8.0–8.4.1
- A jailbroken device
- MobileSubstrate

## Building

This project uses GitHub Actions. On each push to `master`, the workflow:
1. Builds the tweak with plain clang + ldid (no Theos) against the iPhoneOS10.3 SDK, deployment target 6.0, armv7
2. Packages it as a .deb
3. Uploads the artifact

Local build on macOS: `./scripts/build.sh package`

## Installation

1. Grab the .deb from the latest successful GitHub Actions run
2. Transfer it to the device
3. Install: `dpkg -i LegacyUI_*.deb` (`preferenceloader` dependency warning can be forced past: `dpkg --force-depends --configure com.legacyui.tweak`)
4. Respring: `killall SpringBoard`

## Settings

Configure through Settings > LegacyUI.

## Status / roadmap

- [x] Control Center: toggles, sliders, media controls (v0.3.0)
- [x] DO NOT TRACK: volume pill suppression while Control Center is open
- [ ] Wi-Fi toggle: wired via probe-verified `SBWiFiManager`; status-bar DND moon sync is empirical
- [ ] Brightness slider: getter needs on-device ivar verification
- [ ] iOS 8 Control Center parity testing

## License

MIT
