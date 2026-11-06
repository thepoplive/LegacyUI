#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>

#import "Core/CUIConfiguration.h"
#import "Core/CUITheme.h"
#import "Core/CUIGlassView.h"

%group LegacyUICore

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled) {
        NSLog(@"[LegacyUI] Tweak disabled");
        return;
    }
    NSLog(@"[LegacyUI] Initialized successfully");
}
%end

%end

%group LegacyUIDock

%hook SBDockView
- (void)setBackgroundView:(id)view {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (config.enabled && config.dockEnabled && config.liquidGlassEnabled) {
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.dockEnabled || !config.liquidGlassEnabled) {
        return;
    }
}
%end

%end

%group LegacyUIVolumeHUD

%hook SBVolumeHUDView
- (void)setLevel:(float)level {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.volumeHUDEnabled) {
        return;
    }
}

- (void)showHUD {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.volumeHUDEnabled) {
        return;
    }
}

- (void)hideHUD {
    %orig;
}
%end

%end

%group LegacyUILockScreen

%hook SBBacklightController
- (void)lightUpScreen:(int)options {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.lockScreenEnabled) {
        return;
    }
}

- (void)autoLock {
    %orig;
}
%end

%hook SBLockScreenViewController
- (void)viewDidLoad {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.lockScreenEnabled) {
        return;
    }
}

- (void)setCustomLockScreenView:(id)view {
    %orig;
}
%end

%end

%group LegacyUIControlCenter

%hook SBControlCenterController
- (void)openControlCenter {
    %orig;
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.controlCenterEnabled) {
        return;
    }
}

- (void)closeControlCenter {
    %orig;
}

- (void)handleStatusBarTap:(id)tap {
    %orig;
}
%end

%end

%ctor {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];

    if (config.enabled) {
        %init(LegacyUICore);
    }

    if (config.enabled && config.dockEnabled) {
        %init(LegacyUIDock);
    }

    if (config.enabled && config.volumeHUDEnabled) {
        %init(LegacyUIVolumeHUD);
    }

    if (config.enabled && config.lockScreenEnabled) {
        %init(LegacyUILockScreen);
    }

    if (config.enabled && config.controlCenterEnabled) {
        %init(LegacyUIControlCenter);
    }
}