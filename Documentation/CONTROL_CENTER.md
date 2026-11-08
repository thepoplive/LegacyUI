# LegacyUI Control Center — Specification (v1)

Status: concept agreed. No implementation until each stage's header
verification passes (project rule: verify every private API before hooking).

## 1. Goals

Custom Control Center for iOS 6.0–8.4.1 (armv7), primary test device
iPhone 3GS (iOS 6.1.6, 320x480 pt). Visual language: iOS 11 structure +
iOS 18 circular toggles + Material Design 3 tonal surfaces + LegacyUI
Liquid Glass. Not a copy of any stock Control Center.

Non-goals (v1): invocation inside third-party apps, top-right corner
invocation, extra settings beyond the existing enable toggle, Low Power.

## 2. Design system

Colors (MD3 baseline purple on dark glass):
- Accent: #D0BCFF
- Active toggle fill (tonal container): #4F378B
- Glyph on active: #EADDFF
- Panel surface: graphite #101319 at ~90% (+ iOS 8 blur when available)
- Inactive tile fill: white 8%
- Slider fill: accent; track: white 20%

Radii hierarchy: panel 28, music card 20, tiles 16, buttons/sliders capsule.

Icons: code-drawn vector glyphs (UIBezierPath / CoreGraphics) — no SF
Symbols on iOS 6, no bundled assets. Required v1 glyphs: Wi-Fi, Bluetooth,
airplane, moon (DND), sun (brightness slider icon), speaker (volume slider
icon), play, pause, prev, next, gear.

No text labels anywhere: neither under toggles nor tooltips.

Materials: iOS 8 — UIVisualEffectView via CUIBlurSupport; iOS 6 —
translucent tint layers only (3GS SGX535: no runtime blur).

Motion:
- Panel follows finger during drag (interactive progress 0..1).
- Open/close spring 0.4 s (CUISpringAnimate; plain curve on iOS 6).
- Elements cascade: staggered alpha + scale driven by drag progress.
- Press on toggle: scale 0.9 + bounce back; on activation — purple glow
  pulse (layer shadow, purple, radius 8, opacity 0.4) that settles.
- Close animation mirrors open. Dismiss: swipe down, tap outside, Home
  button (Home handling pending verification, see §7).

## 3. Layout

Portrait (base 320x480):
- Panel occupies ~65% of screen height (~312 pt), anchored to bottom,
  rounded top corners, subtle top border (white 25%), soft shadow.
- Row 0: grabber handle (visual dot/dash, centered) + gear button
  (top-right, opens Settings).
- Row 1: four circular toggles 56 pt, evenly spaced: Wi-Fi, Bluetooth,
  Airplane, DND.
- Row 2: two vertical capsule sliders ~130 pt tall, side by side, centered:
  brightness (sun icon on top), volume (speaker icon on top).
- Row 3: music card: title (13 pt semibold) + artist (11 pt, gray) left,
  prev / play-pause / next buttons right.

Landscape: panel anchored to bottom, recomposed grid — toggles in a column
on the left, sliders in the middle, music card on the right. Width-adaptive
(points-based layout, max content width capped ~420 pt on wider devices).

## 4. Invocation & lifecycle

- v1: swipe up from bottom edge on Home Screen and Lock Screen only.
- Grabber: invisible 16 pt strip along the bottom edge (own view, custom
  touch tracking — no UIScreenEdgePanGestureRecognizer: unavailable iOS 6).
- Drag tracks finger; release > 35% progress or fast flick -> open spring;
  otherwise spring back.
- State machine: closed -> dragging -> open -> closing -> closed.
- Notifications/calls while open: panel stays as-is.
- v2 (future): invocation over apps via overlay window; top-right corner
  invocation configurable in settings.

## 5. Functionality

v1 toggles: Wi-Fi, Bluetooth, Airplane mode, system Do Not Disturb.
v1 sliders: brightness, volume.
v1 media: play/pause, prev, next, title, artist (no artwork, no progress).
v1 gear: launches Settings app.
v2: VPN toggle (client-independent activation + last VPN app fallback),
flashlight (only when AVCaptureDevice torchAvailable), rotation lock,
respring, additional tiles.

Interaction with existing modules:
- While CC is open, hardware volume changes update the CC slider; the
  volume pill is suppressed (existing setProgress: hook routes into CC).
- Grabber strip does not interfere with dock icons, icon editing,
  Notification Center (top), or the multitasking bar (double Home).

## 6. Architecture (new files)

    ControlCenter/
      CUIControlCenterController.h/.m   lifecycle, state machine, routing
      CUIControlCenterView.h/.m         panel container, layout, materials
      CUIControlCenterGrabber.h/.m      bottom-edge gesture strip
      CUIControlCenterItem.h/.m         circular toggle (press/glow/active)
      CUISliderControl.h/.m             vertical capsule slider
      CUIMusicCard.h/.m                 media card
      CUICCIconDrawing.h/.m             vector glyph drawing
      CUICCServiceBridge.h/.m           per-service read/toggle, iOS-branched,
                                        runtime-verified classes only

Reuses: CUIConfiguration (ControlCenterEnabled already in settings pane),
CUIBlurSupport, CUISpringAnimate, CUIVolumeController volume bridges
(VolumeControl on iOS 6, MPVolumeView slider on iOS 8).

Tweak.m activates the controller; no new settings in v1.

## 7. Verification checklist (blocking each stage)

- SBWiFiManager class + enable/read selectors — iOS 6.1 & 8.0 headers
- BluetoothManager (private framework) setPowered: / poweredState
- RadiosPreferences (AppSupport) setAirplaneMode:
- DND toggle mechanism for iOS 6.1 / 8.x (SB-side manager or preference
  domain + notification) — if unverifiable, propose fallback openly
- GSEventSetBacklightFactor (GraphicsServices) + current-level read
- MRMediaRemoteCopyNowPlayingInfo / MRMediaRemoteSendCommand (MediaRemote)
- SpringBoard home-button event selector (both generations) for close-on-Home
- SBAwayView integration point (iOS 6 lock screen), lock window on iOS 8
- Settings launch (uiopen / prefs: URL behavior on iOS 6 and 8)

## 8. Constraints

- Performance (3GS): tint-based glass only, animate opacity/transform only,
  no animated shadows, no blur.
- Security: no passcode/lock bypass; CC on lock screen exposes toggles only
  (same trust level as stock iOS 11 behavior).
- All private classes resolved via NSClassFromString + selector existence
  checks before any swizzle; missing APIs disable the feature gracefully.

## 9. Implementation stages

1. Skeleton: controller + grabber + static glass panel + interactive
   open/close + gear button. Deploy to 3GS, validate gesture feel.
2. Sliders: volume (existing bridge) + brightness (after GSEvent
   verification); volume-button routing into CC.
3. Toggles: per-service verification then implementation in order
   Wi-Fi -> Bluetooth -> Airplane -> DND; press/glow/active states.
4. Music card: MediaRemote verification + UI.
5. Landscape grid, polish, release as LegacyUI 0.3.0 (+ repo update).

Each stage: CI build -> SSH deploy to device -> visual/behavioral test ->
fix loop before moving on.
