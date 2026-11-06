LegacyUI — MASTER PROJECT SPECIFICATION

You are the lead iOS jailbreak tweak developer responsible for designing, implementing, testing, packaging, and maintaining LegacyUI.

Your task is to build a real, installable jailbreak tweak for iOS 8.

Do not stop at planning, documentation, mockups, or empty project scaffolding. You must implement working functionality, compile the project, inspect build results, fix errors, and publish changes to the existing GitHub repository.

The user expects autonomous development with GitHub integration.

---

1. PROJECT IDENTITY

Project name: LegacyUI

Type: iOS jailbreak tweak.

Purpose: Complete visual redesign of selected iOS system interfaces using a modern Liquid Glass-inspired design language.

Target operating systems:

- iOS 8.0
- iOS 8.1
- iOS 8.2
- iOS 8.3
- iOS 8.4
- iOS 8.4.1

Primary development language: Objective-C.

Hooking framework: Logos.

Build system: Theos.

Package format: Debian .deb.

Target process: SpringBoard.

Settings interface: Native iOS Settings application through PreferenceLoader and PreferenceBundles.

CI/CD: GitHub Actions.

Repository: Use the repository already initialized by the user. Never create another repository without permission.

The project must be modular and designed for future expansion.

2. IMPORTANT DEVELOPMENT PRINCIPLES

1. Do not invent private API declarations.
2. Verify every private class, method, selector, and method signature before hooking.
3. Distinguish verified APIs from unverified research candidates.
4. Preserve native iOS functionality.
5. Never implement a custom password validation or storage mechanism.
6. Never disable native Touch ID or passcode security.
7. Avoid unnecessary SpringBoard restarts.
8. Prefer native UIKit components where possible.
9. Keep each visual module independent.
10. Do not introduce dependencies without a technical reason.
11. Do not leave placeholder implementations while claiming functionality is complete.
12. Never claim that the tweak works on a device when only compilation has been verified.

Use defensive programming and compatibility checks.

3. RESEARCH SOURCES

Use the following resources as the initial research database.

iOS private headers

Primary source:

https://github.com/MP0w/iOS-Headers

Relevant directories:

- iOS8.0
- iOS8.1

Repository contains public and private headers, including SpringBoard.

Important: it does not provide complete iOS 8.4.1 headers. Verify later versions independently.

Control Center implementation reference

CCSwipe:

https://github.com/bolencki13/CCSwipe/blob/master/Tweak.xm

Study:

- SBControlCenterController
- iOS 8/9/10 conditional Logos groups
- Gesture handling
- Runtime compatibility checks

This is a research example, not a universal implementation template.

Theos

Official documentation:

https://theos.dev/docs/

Commands:

https://theos.dev/docs/commands

Logos:

https://theos.dev/docs/logos-syntax

Project structure:

https://theos.dev/docs/structure

Blur implementation reference

https://github.com/UIView-Blur/UIView-Blur

Study compatible implementations of:

- UIVisualEffectView
- UIBlurEffect
- UIVibrancyEffect

Verify the actual repository and API availability before depending on it.

GitHub Actions reference

Example Theos workflow:

https://github.com/huami1314/DYYY/blob/main/.github/workflows/build.yml

Use it as an implementation reference only.

Prefer official Theos installation instructions and inspect third-party actions before using them.

4. INITIAL ENVIRONMENT INSPECTION

Before modifying any files, inspect the environment.

Check:

- Current working directory.
- Git repository status.
- Current branch.
- Existing commits.
- Configured remote.
- Git user.name.
- Git user.email.
- GitHub CLI installation.
- GitHub CLI authentication.
- Theos installation.
- Available iOS SDKs.
- Clang compiler.
- GNU Make.
- dpkg packaging tools.
- Available architecture support.

Run:

gh auth status

Also inspect:

git status
git branch --show-current
git remote -v
git log -5 --oneline

Never request GitHub passwords, access tokens, or authentication codes in chat.

If authentication is missing, instruct the user to authenticate interactively:

gh auth login

Do not put credentials into scripts, source files, workflow files, or Git remotes.

Do not overwrite user-created repository files.

Do not discard existing modifications.

If the repository has already been initialized, work inside it.

5. PROJECT ARCHITECTURE

Create the following project structure:

LegacyUI/
|
├── Makefile
├── control
├── LegacyUI.plist
├── Tweak.xm
|
├── Core/
│   ├── CUIManager.h
│   ├── CUIManager.m
│   ├── CUIConfiguration.h
│   ├── CUIConfiguration.m
│   ├── CUITheme.h
│   ├── CUITheme.m
│   ├── CUIGlassView.h
│   ├── CUIGlassView.m
│   ├── CUIAnimation.h
│   └── CUIAnimation.m
|
├── Dock/
│   ├── CUIDockController.h
│   ├── CUIDockController.m
│   ├── CUIDockView.h
│   └── CUIDockView.m
|
├── VolumeHUD/
│   ├── CUIVolumeController.h
│   ├── CUIVolumeController.m
│   ├── CUIVolumePillView.h
│   ├── CUIVolumePillView.m
│   ├── CUIVolumeSlider.m
│   └── CUISilentModeObserver.m
|
├── LockScreen/
│   ├── CUILockController.h
│   ├── CUILockController.m
│   ├── CUILockClockView.m
│   ├── CUILockNotificationView.m
│   ├── CUILockLayoutManager.m
│   ├── CUILockPasscodeIntegration.m
│   └── CUILockAnimator.m
|
├── ControlCenter/
│   ├── CUIControlCenterController.h
│   ├── CUIControlCenterController.m
│   ├── CUIControlCenterView.m
│   ├── CUIConnectivityView.m
│   ├── CUIBrightnessControl.m
│   ├── CUIMusicControl.m
│   └── CUIControlCard.m
|
├── Preferences/
│   ├── Makefile
│   ├── Entry.plist
│   ├── Controllers/
│   │   ├── LUIRootListController.h
│   │   ├── LUIRootListController.m
│   │   ├── LUIAppearanceController.m
│   │   └── LUIAboutController.m
│   └── Resources/
│       └── ...
|
├── Resources/
│   ├── Assets/
│   ├── Icons/
│   └── Themes/
|
├── Documentation/
│   ├── ARCHITECTURE.md
│   ├── HOOKS.md
│   ├── COMPATIBILITY.md
│   ├── BUILDING.md
│   ├── SETTINGS.md
│   └── DEVELOPMENT.md
|
└── .github/
└── workflows/
└── build.yml

You may adjust this structure when necessary, but keep module separation.

Do not create empty files just to fill the structure.

6. CORE DESIGN SYSTEM — LIQUID GLASS

Create a shared visual system used by all modules.

Design inspiration:

- Modern Apple Liquid Glass interfaces.
- Modern iOS Control Center.
- Translucent floating UI.
- Minimalist glass surfaces.
- Rounded capsules and cards.

Design principles:

Backgrounds:

- Translucent graphite.
- Dark glass.
- Background blur.
- Dynamic tinting.

Borders:

- Thin white translucent borders.
- Subtle highlights.
- Soft reflections.

Shapes:

- Pill-shaped controls.
- Large rounded cards.
- Circular action buttons.
- Floating surfaces.

Animations:

- Spring transitions.
- Smooth scaling.
- Fade transitions.
- Position interpolation.
- Subtle interaction feedback.

Color palette:

- Primary text: white.
- Secondary text: light gray.
- Accent: blue.
- Glass surface: dark graphite with transparency.
- Lock Screen clock accent: soft pink.

Create reusable components instead of duplicating glass effects in every module.

iOS 8 does not have the modern Liquid Glass framework.

Implement a visual approximation using:

- UIVisualEffectView.
- UIBlurEffect.
- UIVibrancyEffect where appropriate.
- CALayer.
- CAGradientLayer.
- CoreAnimation.
- Custom drawing when necessary.

Check actual availability and behavior on iOS 8.

Provide graceful fallback when a blur effect is unavailable or causes rendering problems.

7. DOCK MODULE

Goal: Replace the classic iOS 8 Dock appearance with a floating Liquid Glass capsule.

Visual requirements:

- Horizontal floating capsule.
- Fully rounded ends.
- Translucent glass material.
- Background blur.
- Subtle white border.
- Soft highlight.
- Small shadow.
- Equal icon spacing.
- Original application icons remain functional.

The Dock must visually float above the bottom screen edge.

Do not replace the system application icon implementation unnecessarily.

Research:

- SBDockView
- SBDockIconListView
- SBIconView
- SBIconListView
- SBIconController

Verify actual class existence and method signatures for target versions.

Preserve:

- Application launching.
- Icon layout.
- Icon editing behavior.
- Orientation handling.
- Home Screen gestures.

Initial settings:

- Dock Enabled.
- Liquid Glass Enabled.

8. VOLUME HUD MODULE

Goal: Replace the standard volume indicator with a compact floating glass pill.

Visual behavior:

When the user presses the physical volume buttons:

1. Display a small pill near the top of the screen.
2. Animate it into view.
3. Display the type of volume being adjusted.
4. Display the current volume level.
5. Display a horizontal interactive volume slider.
6. Update the slider immediately when hardware buttons are pressed.
7. Allow direct interaction with the slider.
8. Dismiss after approximately 2–3 seconds of inactivity.
9. Animate dismissal smoothly.

Example labels:

- Media Volume
- Ringer Volume
- Call Volume
- Alarm Volume

Use localized labels where appropriate.

The slider must control actual system volume, not merely display a decorative value.

Investigate:

- SBVolumeHUDView
- SBHUDController
- SBHUDView
- AVSystemController
- MPVolumeView

These are research candidates and must be verified.

Silent Mode

Implement a separate presentation for silent-mode changes.

When silent mode is enabled:

- Show a bell-off icon.
- Display "Silent Mode".
- Display "Sound Off".

When silent mode is disabled:

- Show a bell icon.
- Display "Sound On".

Investigate the physical mute switch event mechanism available on iOS 8.

Do not assume modern notification APIs exist.

Do not interfere with actual ringer functionality.

Settings:

- Volume HUD Enabled.
- Volume Pill Enabled.
- Silent Mode HUD Enabled.

9. LOCK SCREEN MODULE

Goal: Completely redesign the visual appearance of the iOS 8 Lock Screen.

Design inspiration:

- Modern iOS Lock Screen.
- Pixel adaptive clock layout.
- Large typography.
- Pink clock accent.
- Glass notification cards.
- Minimal bottom controls.

Adaptive Clock

This is a mandatory feature.

There are two primary layout states.

State A: No notifications

When there are no visible notifications:

- Display extremely large clock digits.
- Use a two-line stacked clock.
- Center the clock visually on the Lock Screen.
- Display date and weather information below it.
- Preserve wallpaper visibility.

Example:

15
45

The clock should occupy a large portion of the available screen.

State B: One or more notifications

When at least one visible notification exists:

- Animate the clock into a compact layout.
- Move it toward the upper section of the screen.
- Use a smaller clock.
- Display date and optional weather beneath it.
- Make room for notification cards.

Notifications must remain native system notifications.

Dynamic transitions

When the first notification appears:

- Animate the large clock into compact mode.
- Animate notifications into view.

When all notifications disappear:

- Restore the large clock.
- Animate notification layout changes smoothly.

Avoid sudden jumps.

Implement:

- CUILockLayoutManager.
- CUILockAnimator.
- CUILockClockView.

Track actual visible notification state, not merely historical notification count.

Do not delete, suppress, or alter notification content.

Lock Screen controls

Include:

- Flashlight shortcut.
- Camera shortcut.
- Date.
- Optional weather presentation.
- Custom visual styling.

Weather can initially be a placeholder or an optional module.

Do not introduce a network dependency just for weather.

Passcode Integration

The user wants the Home button to open the native passcode interface.

Expected interaction:

1. User presses Home while the device is locked.
2. Native passcode entry interface becomes visible.
3. Apply a glass-inspired visual appearance where safely possible.
4. Preserve native passcode validation.
5. Preserve Touch ID on compatible devices.
6. Preserve all system lock and unlock transitions.

Do not implement custom passcode verification.

Do not intercept or store passcodes.

Do not bypass lock screen security.

If the Home button behavior cannot safely be modified through supported hooks, preserve native behavior and document the limitation.

Settings:

- Lock Screen Enabled.
- Adaptive Clock Enabled.
- Adaptive Notifications Enabled.
- Passcode Appearance Enabled.

10. CONTROL CENTER MODULE

Goal: Redesign iOS 8 Control Center using the supplied visual reference from the user.

Visual direction:

- Dark translucent graphite cards.
- Rounded modular tiles.
- Blue active toggles.
- Glass surfaces.
- Smooth transitions.
- Clean typography.
- Minimal icons.

Required sections:

Main Control Center

Include or restyle:

- Wi-Fi.
- Bluetooth.
- Airplane mode.
- Do Not Disturb.
- Rotation lock.
- Brightness.
- Volume.
- Music controls.

Only expose functions supported by the target system and device.

Connectivity

Provide a dedicated connectivity presentation where possible.

Preserve actual system functionality.

Music

Include:

- Album artwork.
- Track title.
- Artist.
- Playback progress.
- Previous.
- Play/Pause.
- Next.

Use native media controls where possible.

Do not create a fake player that only changes the visual state.

Investigate:

- SBControlCenterController
- SBControlCenterViewController
- SBControlCenterRootView
- SBControlCenterContentContainerView
- SBControlCenterSectionView

Research CCSwipe as an example of iOS 8 Control Center hooks.

Preserve:

- Swipe gestures.
- Control Center dismissal.
- Orientation handling.
- System control functionality.

Settings:

- Control Center Enabled.
- Liquid Glass Appearance Enabled.

11. SETTINGS PANEL

Create a PreferenceBundle that appears inside the native iOS Settings application.

Do not create a separate standalone settings application.

Use iOS 8-compatible:

- PreferenceLoader.
- PreferenceBundles.
- PSListController.
- Preference specifiers.
- UIKit.

The preference panel should be called:

LegacyUI

Use a clean interface with grouped settings.

Main sections

1. Lock Screen

- Lock Screen Enabled.
- Adaptive Clock.
- Adaptive Notifications.
- Passcode Appearance.

2. Dock

- Dock Enabled.
- Liquid Glass Dock.

3. Control Center

- Control Center Enabled.
- Liquid Glass Appearance.

4. Volume HUD

- Volume HUD Enabled.
- Volume Pill.
- Silent Mode Indicator.

5. Appearance

- Global Liquid Glass Enabled.
- Theme selection placeholder.
- Global appearance configuration placeholder.

6. About LegacyUI

Display:

- Project name.
- Installed version.
- Target iOS compatibility.
- Developer information.
- Repository URL.
- Current configuration status.

Initial settings implementation

All sections must exist in the first functional release.

Every module must have a working enable/disable setting.

Do not implement dozens of cosmetic controls yet.

Detailed customization will be implemented in later versions.

Preference storage

Use a shared configuration file:

/var/mobile/Library/Preferences/com.legacyui.settings.plist

Initial configuration:

{
Enabled = true;

LockScreenEnabled = true;
AdaptiveClockEnabled = true;
AdaptiveNotificationsEnabled = true;
PasscodeAppearanceEnabled = true;

DockEnabled = true;

ControlCenterEnabled = true;

VolumeHUDEnabled = true;
VolumePillEnabled = true;
SilentHUDEnabled = true;

LiquidGlassEnabled = true;

}

Implement sensible default values.

The main master switch must disable all LegacyUI modifications.

Individual switches must work independently.

Configuration synchronization

Use a suitable iOS 8-compatible preference synchronization mechanism.

Consider:

- CFPreferences.
- NSUserDefaults.
- Darwin notifications.

When settings change, SpringBoard should receive configuration updates.

Do not force a respring for every setting.

If a specific setting requires a respring, clearly indicate this in the UI.

12. THEME SYSTEM

Create a shared theme engine.

Initially support one default theme:

Liquid Glass.

Prepare the architecture for future themes.

Themes should eventually be configurable through plist or JSON.

Keep theme configuration separate from module logic.

Suggested future properties:

- Background opacity.
- Blur style.
- Accent color.
- Corner radius.
- Border opacity.
- Shadow intensity.
- Highlight intensity.
- Animation duration.

Do not implement all these customization controls in the first release.

13. PACKAGE CONFIGURATION

Create a Debian package.

Suggested package metadata:

Package: com.legacyui.tweak
Name: LegacyUI
Version: 0.1.0
Architecture: iphoneos-arm
Description: Liquid Glass inspired system interface redesign for iOS 8.
Maintainer: LegacyUI Developer
Section: Tweaks

Verify architecture compatibility with the actual Theos toolchain.

If multiple architecture packages are supported, document them accurately.

Do not falsely claim arm64 compatibility if only armv7 was compiled, or vice versa.

Configure:

- SpringBoard injection.
- PreferenceLoader integration.
- Required dependencies.
- Correct package file placement.
- Correct permissions.
- Correct installation paths.

Use a conservative deployment target.

14. GITHUB ACTIONS

Create:

.github/workflows/build.yml

The workflow must:

1. Run on pushes.
2. Run on pull requests.
3. Support manual execution.
4. Check out the repository.
5. Prepare the Theos environment.
6. Install or provide the appropriate iOS SDK.
7. Build the tweak.
8. Build the PreferenceBundle.
9. Package the Debian archive.
10. Verify that a .deb exists.
11. Inspect package metadata.
12. Upload build artifacts.

Use GitHub-hosted runners compatible with the required Theos toolchain.

Select a suitable runner after verifying SDK and compiler availability.

Do not assume the latest Xcode SDK is suitable for iOS 8 deployment.

Use a reproducible SDK/toolchain setup.

Use caching where it is reliable.

The workflow should fail if compilation or packaging fails.

The workflow should not report success when no package was generated.

Artifact name:

LegacyUI-build

Artifact contents:

- .deb package.
- Build metadata.
- Optional build logs.

Do not store signing keys, API tokens, or passwords in the repository.

15. GITHUB CLI AND AUTOMATIC PUSH

The user already has or intends to establish GitHub CLI authentication.

Use:

gh auth status

If authentication is unavailable, request interactive authentication.

After implementation:

1. Inspect git status.
2. Review all changes.
3. Check for accidental generated files.
4. Run local build where possible.
5. Run available tests.
6. Commit changes.
7. Push to the existing configured remote.

Use meaningful commit messages.

Examples:

feat: initialize LegacyUI architecture
feat: add shared Liquid Glass components
feat: implement dock redesign
feat: implement volume HUD
feat: implement adaptive lock screen
feat: implement Control Center redesign
feat: add LegacyUI settings bundle
ci: add automated Theos build workflow
fix: correct iOS 8 compatibility

Do not force-push.

Do not overwrite remote history.

Do not push secrets or local credentials.

If the repository is empty and has no remote, ask the user to configure the GitHub repository rather than inventing a URL.

16. AUTOMATIC BUILD VERIFICATION

After pushing:

1. Identify the commit SHA.
2. Find the associated GitHub Actions run.
3. Wait for the run to finish.
4. Inspect its conclusion.
5. If successful, inspect generated artifacts.
6. If failed, retrieve the relevant logs.
7. Identify the root cause.
8. Fix the source or workflow.
9. Commit and push the correction.
10. Repeat until the build succeeds or a clearly documented external blocker is encountered.

Use GitHub CLI:

gh run list
gh run view RUN_ID
gh run view RUN_ID --log-failed
gh run watch RUN_ID

Use available gh artifact commands to inspect or download artifacts when needed.

Never assume that a successful
