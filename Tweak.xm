#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Core/CUIConfiguration.h"
#import "Core/CUITheme.h"
#import "Core/CUIGlassView.h"

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
}