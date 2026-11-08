LegacyUI — Explicit iOS 6.1.3 Hook Map

Target device

Primary test device:

- iPhone 3GS
- iOS 6.1.3
- ARMv7
- SpringBoard process
- Jailbreak with MobileSubstrate support

Compatibility target: iOS 6.0–6.1.6.

IMPORTANT: Do not perform open-ended research to discover alternative hook classes. Use the classes and selectors listed below as the initial implementation map. Do not invent APIs or assume iOS 7+ classes exist on iOS 6.

Reference headers:

- https://github.com/caughtinflux/iOS-6-SpringBoard-Headers
- https://github.com/Bensge/iOS-6-SpringBoard-Headers
- https://github.com/MP0w/iOS-Headers/tree/master/iOS6.1

Use the iOS 6.1 headers as the primary reference.

---

1. Dock

Primary class

"SBIconController"

Primary integration point

- (id)dockContainerView;
- (id)dock;
- (id)contentView;
+ (id)sharedInstance;

Hook strategy

Hook:

%hook SBIconController

- (id)dockContainerView {
    id original = %orig;

    // Obtain the original Dock container.
    // Attach or update the LegacyUI visual background.
    // Never replace the original Dock container.
    // Never remove or recreate the original icon list.

    return original;
}

%end

The exact implementation must avoid adding duplicate background views every time the getter is called.

Additional class

"SBDockIconListView"

Use it as the original Dock icon-list view. Do not replace its icon views or touch handling.

If additional layout integration is required, use:

- (void)layoutSubviews;

Only hook this method after confirming the class and method exist at runtime.

Visual implementation

Create "LUIIOS6DockBackgroundView" using:

- UIView
- CALayer
- CAGradientLayer
- CoreGraphics
- alpha
- corner radius
- shadows
- highlights

Do not use UIVisualEffectView or UIBlurEffect.

Keep the original icons, animations, hit-testing and rearrangement behavior intact.

---

2. Volume HUD

Primary class

"SBHUDController"

Use these iOS 6 methods:

+ (id)sharedHUDController;

- (void)presentHUDView:(id)view;

- (void)presentHUDView:(id)view
    autoDismissWithDelay:(double)delay;

- (void)hideHUDView;

- (id)visibleHUDView;

- (id)visibleOrFadingHUDView;

Hook strategy

Hook both presentation methods.

%hook SBHUDController

- (void)presentHUDView:(id)view {
    // Inspect the original HUD view.
    // Apply LegacyUI appearance only to supported volume/ringer HUDs.
    %orig(view);
}

- (void)presentHUDView:(id)view
    autoDismissWithDelay:(double)delay {
    // Apply the same visual customization.
    // Preserve the original auto-dismiss delay.
    %orig(view, delay);
}

%end

Do not modify the HUD lifecycle or suppress system presentation.

HUD classes to identify

SBHUDView
SBVolumeHUDView
SBRingerHUDView

Use runtime class checks before applying the custom appearance.

Volume control

Use the existing system controller:

@interface VolumeControl : NSObject

+ (id)sharedVolumeControl;

- (float)getMediaVolume;
- (void)setMediaVolume:(float)volume;

- (void)increaseVolume;
- (void)decreaseVolume;
- (void)toggleMute;

- (float)volume;

@end

The custom slider must control actual system volume through "VolumeControl".

Do not implement a decorative slider disconnected from the system.

Ringer switch

"SBRingerHUDView" exposes:

@property(nonatomic, getter=isSilent) BOOL silent;

Preserve the physical mute switch behavior. Do not assume that changing media volume also changes ringer state.

---

3. Lock Screen

iOS 6 uses the legacy Away architecture. Do not use iOS 7+ "SBLockScreenViewController" hooks.

Primary classes

SBAwayController
SBAwayView
SBAwayDateView
SBAwayLockBar
SBAwayBulletinListController
SBPasscodeController

Primary integration points

"SBAwayController":

+ (id)sharedAwayController;
- (id)awayView;

"SBAwayView":

- (void)layoutSubviews;

"SBAwayDateView":

- (void)layoutSubviews;

Hook strategy

Use "SBAwayController -awayView" to obtain the existing lock screen view.

Use "SBAwayView -layoutSubviews" as the main layout integration point.

Use "SBAwayDateView -layoutSubviews" for date/time appearance customization.

Example:

%hook SBAwayView

- (void)layoutSubviews {
    %orig;

    // Update LegacyUI lock screen appearance.
    // Do not remove native lock screen controls.
    // Do not interfere with passcode entry.
}

%end

The exact view hierarchy must be inspected on the target iOS 6.1.3 device before inserting additional views.

Security restrictions

Never:

- bypass the passcode;
- modify passcode validation;
- change the device lock state directly;
- disable native lock screen gestures;
- intercept authentication in a way that weakens security.

Only customize the visual interface.

Preserve notifications, media controls, charging indicators, emergency access and passcode UI.

---

4. Control Center

There is no native Control Center in iOS 6.

Do not hook:

- "SBControlCenterController"
- "SBControlCenterViewController"
- other iOS 7+ Control Center classes.

If LegacyUI includes a Control Center-like feature on iOS 6, implement it as an independent component:

ControlCenter/
  LUIIOS6ControlCenterController.h
  LUIIOS6ControlCenterController.m
  LUIIOS6ControlCenterView.h
  LUIIOS6ControlCenterView.m
  Modules/

It must be a custom panel, not a modification of a nonexistent native component.

Implement this only after Dock, Volume HUD and Lock Screen are stable.

---

5. Runtime compatibility requirements

Before installing any hook:

1. Check whether the target class exists.
2. Check whether the target selector is implemented.
3. Check the method signature and argument count.
4. Do not hook a missing selector.
5. Do not assume that an iOS 8 implementation works on iOS 6.
6. Do not call methods introduced in iOS 7 or later.

Use runtime checks such as:

Class cls = objc_getClass("SBIconController");

if (cls && class_getInstanceMethod(cls,
    @selector(dockContainerView))) {
    // Safe to register the corresponding hook.
}

For every hook, preserve "%orig" behavior unless there is a documented and necessary reason not to.

Do not use guessed private API signatures.

If a listed selector is absent on the actual device, record it as unsupported and do not silently substitute another selector.

---

6. Build requirements

Target:

- "armv7"
- minimum iOS 6.0
- iOS 6-compatible SDK and deployment settings.

Do not introduce ARMv6 support for this task.

Do not use:

- UIVisualEffectView
- UIBlurEffect
- iOS 7-only UIKit methods
- Swift runtime dependencies
- modern SpringBoard classes unavailable on iOS 6.

The iOS 8 implementation must remain functional and isolated from the iOS 6 compatibility code.

---

7. Required implementation order

1. Inspect the existing LegacyUI repository and current build configuration.
2. Add the iOS 6 compatibility layer.
3. Implement the Dock hook using "SBIconController -dockContainerView".
4. Implement the Volume HUD hooks using "SBHUDController".
5. Implement the Lock Screen hooks using the legacy "SBAway*" classes.
6. Build the ARMv7 package.
7. Install on the iPhone 3GS running iOS 6.1.3.
8. Test SpringBoard startup, Dock, volume buttons, mute switch, Lock Screen, notifications and passcode.
9. Inspect crash logs and fix regressions.
10. Document every hook actually implemented.

Do not stop after writing documentation or generating placeholder classes. Implement, compile and test the actual code.

If a hook fails, report the exact class, selector, runtime check and error. Do not fabricate successful implementation or test results.