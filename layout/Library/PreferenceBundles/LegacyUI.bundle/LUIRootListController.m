#import "LUIRootListController.h"
#import "../Core/CUIConfiguration.h"

@implementation LUIRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"LegacyUI";
}

- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [super tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)setPreferenceValue:(id)value forSpecifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value forSpecifier:specifier];

    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"Enabled"]) {
        [CUIConfiguration sharedInstance].enabled = [value boolValue];
    } else if ([key isEqualToString:@"LockScreenEnabled"]) {
        [CUIConfiguration sharedInstance].lockScreenEnabled = [value boolValue];
    } else if ([key isEqualToString:@"AdaptiveClockEnabled"]) {
        [CUIConfiguration sharedInstance].adaptiveClockEnabled = [value boolValue];
    } else if ([key isEqualToString:@"AdaptiveNotificationsEnabled"]) {
        [CUIConfiguration sharedInstance].adaptiveNotificationsEnabled = [value boolValue];
    } else if ([key isEqualToString:@"PasscodeAppearanceEnabled"]) {
        [CUIConfiguration sharedInstance].passcodeAppearanceEnabled = [value boolValue];
    } else if ([key isEqualToString:@"DockEnabled"]) {
        [CUIConfiguration sharedInstance].dockEnabled = [value boolValue];
    } else if ([key isEqualToString:@"LiquidGlassEnabled"]) {
        [CUIConfiguration sharedInstance].liquidGlassEnabled = [value boolValue];
    } else if ([key isEqualToString:@"ControlCenterEnabled"]) {
        [CUIConfiguration sharedInstance].controlCenterEnabled = [value boolValue];
    } else if ([key isEqualToString:@"VolumeHUDEnabled"]) {
        [CUIConfiguration sharedInstance].volumeHUDEnabled = [value boolValue];
    } else if ([key isEqualToString:@"VolumePillEnabled"]) {
        [CUIConfiguration sharedInstance].volumePillEnabled = [value boolValue];
    } else if ([key isEqualToString:@"SilentHUDEnabled"]) {
        [CUIConfiguration sharedInstance].silentHUDEnabled = [value boolValue];
    }

    [[CUIConfiguration sharedInstance] saveSettings];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    CUIConfiguration *config = [CUIConfiguration sharedInstance];

    if ([key isEqualToString:@"Enabled"]) {
        return @(config.enabled);
    } else if ([key isEqualToString:@"LockScreenEnabled"]) {
        return @(config.lockScreenEnabled);
    } else if ([key isEqualToString:@"AdaptiveClockEnabled"]) {
        return @(config.adaptiveClockEnabled);
    } else if ([key isEqualToString:@"AdaptiveNotificationsEnabled"]) {
        return @(config.adaptiveNotificationsEnabled);
    } else if ([key isEqualToString:@"PasscodeAppearanceEnabled"]) {
        return @(config.passcodeAppearanceEnabled);
    } else if ([key isEqualToString:@"DockEnabled"]) {
        return @(config.dockEnabled);
    } else if ([key isEqualToString:@"LiquidGlassEnabled"]) {
        return @(config.liquidGlassEnabled);
    } else if ([key isEqualToString:@"ControlCenterEnabled"]) {
        return @(config.controlCenterEnabled);
    } else if ([key isEqualToString:@"VolumeHUDEnabled"]) {
        return @(config.volumeHUDEnabled);
    } else if ([key isEqualToString:@"VolumePillEnabled"]) {
        return @(config.volumePillEnabled);
    } else if ([key isEqualToString:@"SilentHUDEnabled"]) {
        return @(config.silentHUDEnabled);
    }

    return [super readPreferenceValue:specifier];
}

@end