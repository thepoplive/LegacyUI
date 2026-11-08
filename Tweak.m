#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import "Core/CUIConfiguration.h"
#import "Core/CUITheme.h"
#import "Core/CUIGlassView.h"
#import "Dock/CUIDockController.h"
#import "VolumeHUD/CUIVolumeController.h"
#import "ControlCenter/CUIControlCenterController.h"

static void LUIApplyModules() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];

    if (config.enabled && config.dockEnabled && config.liquidGlassEnabled) {
        [[CUIDockController sharedInstance] activate];
    } else {
        [[CUIDockController sharedInstance] deactivate];
    }

    if (config.enabled && config.volumeHUDEnabled && config.volumePillEnabled) {
        [[CUIVolumeController sharedInstance] activate];
    } else {
        [[CUIVolumeController sharedInstance] deactivate];
    }

    if (config.enabled && config.controlCenterEnabled) {
        [[CUIControlCenterController sharedInstance] activate];
    } else {
        [[CUIControlCenterController sharedInstance] deactivate];
    }
}

static void LUIConfigChangedCallback(CFNotificationCenterRef center,
                                     void *observer,
                                     CFStringRef name,
                                     const void *object,
                                     CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[LegacyUI] Settings changed, reloading configuration");
        [[CUIConfiguration sharedInstance] loadSettings];
        LUIApplyModules();
    });
}

__attribute__((constructor))
static void LegacyUIInitialize() {
    NSLog(@"[LegacyUI] Tweak initialized");

    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled) {
        NSLog(@"[LegacyUI] Tweak disabled via settings");
    } else {
        NSLog(@"[LegacyUI] Enabled — Dock: %d, ControlCenter: %d, VolumeHUD: %d, LockScreen: %d",
              config.dockEnabled, config.controlCenterEnabled,
              config.volumeHUDEnabled, config.lockScreenEnabled);
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LUIApplyModules();
    });

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        LUIConfigChangedCallback,
        CFSTR("com.legacyui.settings.changed"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}