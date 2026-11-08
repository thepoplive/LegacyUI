# LegacyUI

Liquid Glass inspired system interface redesign for jailbroken iOS — supports both **iOS 6.1 on the iPhone 3GS** and **iOS 8.0–8.4.1** from a single armv7 binary.

## Modules

The tweak injects into SpringBoard (`com.legacyui.tweak`) and ships four independent modules. Every module can be toggled separately in Settings > LegacyUI (master switch `Enabled` disables everything); the preference pane is a plist-only PreferenceLoader pane with live reload via the Darwin notification `com.legacyui.settings.changed`.

### Control Center (`ControlCenter/`, key `ControlCenterEnabled`)

Swipe (or tap) from the bottom edge of the home screen opens an interactive Liquid Glass panel:

- Glass panel is hosted in a dedicated overlay window (`CUIOverlayWindow`) — the iOS 6 home screen is windowless, so UIKit touches only work at window level
- Toggle row: **Wi-Fi, Bluetooth, Do Not Disturb, Airplane Mode** — wired to real system APIs via a service bridge (`SBWiFiManager`, `BluetoothManager`, `RadiosPreferences` from AppSupport, `com.apple.DoNotDisturb` preferences + Darwin notification); active toggles glow violet with an activation pulse
- Vertical sliders: **brightness** (`setBacklightFactor:` on SpringBoard) and **volume** (routes to `VolumeControl` on iOS 6, hidden `MPVolumeView` slider observer on iOS 8); commit-on-release to avoid flooding the render server on the 3GS
- **Music square**: previous / play-pause / next buttons, live track title + artist in the panel header, all through `SBMediaController`
- Hardware volume buttons do **not** pop the volume pill while the panel is open — the volume slider follows them live (`CUICCVolumeChangedNotification` across modules)
- The **Home button closes the panel first** (swizzled `menuButtonDown:`); the gear button closes it and opens Settings (`applicationOpenURL:`)
- Panel movement is transform-only — the glass mask never re-renders while dragging (smooth on SGX535)
- A swizzled `frontDisplayDidChange:` gates the bottom grabber strip: visible on the home screen only, hidden in apps and on the lock screen

### Dock (`Dock/`, keys `DockEnabled` + `LiquidGlassEnabled`)

Floating Liquid Glass capsule dock:

- iOS 6: swizzles into the icon content view, sizes the glass capsule to the icon union, clears the native dock layer and label backgrounds, classic icon geometry without reflections
- iOS 8: runtime glass capsule replacing the native dock bar

### Volume HUD (`VolumeHUD/`, keys `VolumeHUDEnabled` + `VolumePillEnabled` / `SilentHUDEnabled`)

Compact floating glass pill in a dedicated overlay window, visible over apps and the lock screen:

- **Volume pill**: swizzles `SBHUDController -presentHUDView:`/`-presentHUDView:autoDismissWithDelay:` and `SBVolumeHUDView -setProgress:` so hardware volume presses drive the pill and the system HUD is suppressed
- **Silent mode indicator**: replaces the system ringer HUD (`SBRingerHUDView`) with the pill
- Reading/writing system volume: `VolumeControl -getMediaVolume/-setMediaVolume:` on iOS 6, `MPVolumeView` slider on iOS 8

### Lock Screen (`LockScreen/`, keys `LockScreenEnabled` + `AdaptiveClockEnabled`)

Complete lock screen visual redesign with an adaptive clock and notification restyling (planned/experimental — see roadmap).

## Design verification: the runtime probe

Private API calls are only made against selectors verified either in class-dump headers (iOS 6.1 SDK files, MP0w iOS 8 headers) or — better — against the real binary on the test device. Place an empty marker file `/var/mobile/.legacyui_probe`; on the next respring the tweak writes to `/var/mobile/legacyui_probe.txt`:

- method lists of `SBWiFiManager`, `BluetoothManager`, `RadiosPreferences`, `SBMediaController`, `VolumeControl`, `SpringBoard` + candidate classes
- ivar list of SpringBoard (verifies where the live backlight level is stored)
- a "live states" readout: actual values returned by the service getters on this firmware

This is how iOS-6-era discrepancies like BluetoothManager `powered` vs `enabled` and the SBMediaController `isPlaying` selector get resolved empirically before wiring UI state to them.

## Version history (short)

- 0.1–0.2: dock glass, overlay window volume pill, HUD swizzles, PreferenceLoader pane, iOS 6 runtime support
- 0.2.5–0.2.9: Control Center skeleton → grabber/panel moved into the overlay window (home screen is windowless on iOS 6) → working open gesture
- 0.3.0: functional Control Center — service bridge, violet active glow, real toggles/sliders/media controls, volume-system coupling, home-button close

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

Configure through Settings > LegacyUI. Toggle keys (domain `com.legacyui.settings`): `Enabled`, `DockEnabled`, `LiquidGlassEnabled`, `VolumeHUDEnabled`, `VolumePillEnabled`, `SilentHUDEnabled`, `LockScreenEnabled`, `AdaptiveClockEnabled`, `ControlCenterEnabled`.

## Status / roadmap

- [x] Control Center: toggles, sliders, media controls (v0.3.0)
- [x] Volume pill suppression while Control Center is open (live slider sync)
- [x] Wi-Fi toggle wired via probe-verified `SBWiFiManager`
- [ ] DND status-bar moon does not appear when toggled from the panel (preference write verified, SpringBoard refresh path under investigation)
- [ ] Bluetooth glow may mismatch the Settings switch on open (`powered` vs `enabled` semantics — live-state probe pending on test device)
- [ ] Brightness slider: getter needs on-device ivar verification (slider snaps to 50%)
- [ ] iOS 8 Control Center parity testing

## License

MIT
