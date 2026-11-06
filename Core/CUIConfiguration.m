#import "CUIConfiguration.h"

static NSString * const kSettingsFilePath = @"/var/mobile/Library/Preferences/com.legacyui.settings.plist";

@implementation CUIConfiguration

+ (instancetype)sharedInstance {
    static CUIConfiguration *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CUIConfiguration alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSettingsFilePath];

    if (!settings) {
        [self setDefaultSettings];
        return;
    }

    _enabled = [settings[@"Enabled"] boolValue];
    _lockScreenEnabled = [settings[@"LockScreenEnabled"] boolValue];
    _adaptiveClockEnabled = [settings[@"AdaptiveClockEnabled"] boolValue];
    _adaptiveNotificationsEnabled = [settings[@"AdaptiveNotificationsEnabled"] boolValue];
    _passcodeAppearanceEnabled = [settings[@"PasscodeAppearanceEnabled"] boolValue];
    _dockEnabled = [settings[@"DockEnabled"] boolValue];
    _liquidGlassEnabled = [settings[@"LiquidGlassEnabled"] boolValue];
    _controlCenterEnabled = [settings[@"ControlCenterEnabled"] boolValue];
    _volumeHUDEnabled = [settings[@"VolumeHUDEnabled"] boolValue];
    _volumePillEnabled = [settings[@"VolumePillEnabled"] boolValue];
    _silentHUDEnabled = [settings[@"SilentHUDEnabled"] boolValue];
}

- (void)setDefaultSettings {
    _enabled = YES;
    _lockScreenEnabled = YES;
    _adaptiveClockEnabled = YES;
    _adaptiveNotificationsEnabled = YES;
    _passcodeAppearanceEnabled = YES;
    _dockEnabled = YES;
    _liquidGlassEnabled = YES;
    _controlCenterEnabled = YES;
    _volumeHUDEnabled = YES;
    _volumePillEnabled = YES;
    _silentHUDEnabled = YES;
    [self saveSettings];
}

- (void)saveSettings {
    NSDictionary *settings = @{
        @"Enabled": @(_enabled),
        @"LockScreenEnabled": @(_lockScreenEnabled),
        @"AdaptiveClockEnabled": @(_adaptiveClockEnabled),
        @"AdaptiveNotificationsEnabled": @(_adaptiveNotificationsEnabled),
        @"PasscodeAppearanceEnabled": @(_passcodeAppearanceEnabled),
        @"DockEnabled": @(_dockEnabled),
        @"LiquidGlassEnabled": @(_liquidGlassEnabled),
        @"ControlCenterEnabled": @(_controlCenterEnabled),
        @"VolumeHUDEnabled": @(_volumeHUDEnabled),
        @"VolumePillEnabled": @(_volumePillEnabled),
        @"SilentHUDEnabled": @(_silentHUDEnabled)
    };

    [settings writeToFile:kSettingsFilePath atomically:YES];
}

@end