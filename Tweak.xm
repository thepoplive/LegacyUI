#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Core/CUIConfiguration.h"
#import "Core/CUITheme.h"
#import "Core/CUIGlassView.h"
#import "Dock/CUIDockController.h"
#import "VolumeHUD/CUIVolumeController.h"

__attribute__((constructor))
static void initialize() {
    NSLog(@"[LegacyUI] Tweak initialized");

    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled) {
        NSLog(@"[LegacyUI] Tweak disabled via settings");
        return;
    }

    NSLog(@"[LegacyUI] Enabled - Configuration loaded");
    NSLog(@"[LegacyUI] LockScreen: %d, Dock: %d, ControlCenter: %d, VolumeHUD: %d",
          config.lockScreenEnabled, config.dockEnabled,
          config.controlCenterEnabled, config.volumeHUDEnabled);

    if (config.dockEnabled && config.liquidGlassEnabled) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[CUIDockController sharedInstance] activate];
        });
    }

    if (config.volumeHUDEnabled && config.volumePillEnabled) {
        [[CUIVolumeController sharedInstance] activate];
    }
}