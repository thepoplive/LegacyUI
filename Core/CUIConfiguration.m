#import "CUIConfiguration.h"

static NSString * const kSettingsDomain = @"com.legacyui.settings";

static BOOL CUIBoolWithDefault(NSDictionary *dict, NSString *key) {
    id value = dict[key];
    if (value) return [value boolValue];
    return YES;
}

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
    NSDictionary *settings = CFBridgingRelease(
        CFPreferencesCopyAppValue(
            (CFStringRef)@"*",
            (CFStringRef)kSettingsDomain
        )
    );

    if (![settings isKindOfClass:[NSDictionary class]] || settings.count == 0) {
        settings = [NSDictionary dictionaryWithContentsOfFile:
            [@"/var/mobile/Library/Preferences" stringByAppendingPathComponent:[kSettingsDomain stringByAppendingString:@".plist"]]];
    }

    if (![settings isKindOfClass:[NSDictionary class]]) {
        [self setDefaultSettings];
        return;
    }

    _enabled = CUIBoolWithDefault(settings, @"Enabled");
    _lockScreenEnabled = CUIBoolWithDefault(settings, @"LockScreenEnabled");
    _adaptiveClockEnabled = CUIBoolWithDefault(settings, @"AdaptiveClockEnabled");
    _adaptiveNotificationsEnabled = CUIBoolWithDefault(settings, @"AdaptiveNotificationsEnabled");
    _passcodeAppearanceEnabled = CUIBoolWithDefault(settings, @"PasscodeAppearanceEnabled");
    _dockEnabled = CUIBoolWithDefault(settings, @"DockEnabled");
    _liquidGlassEnabled = CUIBoolWithDefault(settings, @"LiquidGlassEnabled");
    _controlCenterEnabled = CUIBoolWithDefault(settings, @"ControlCenterEnabled");
    _volumeHUDEnabled = CUIBoolWithDefault(settings, @"VolumeHUDEnabled");
    _volumePillEnabled = CUIBoolWithDefault(settings, @"VolumePillEnabled");
    _silentHUDEnabled = CUIBoolWithDefault(settings, @"SilentHUDEnabled");
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
    CFPreferencesSetValue(
        (CFStringRef)@"Enabled", (CFPropertyListRef)@(_enabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"LockScreenEnabled", (CFPropertyListRef)@(_lockScreenEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"AdaptiveClockEnabled", (CFPropertyListRef)@(_adaptiveClockEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"AdaptiveNotificationsEnabled", (CFPropertyListRef)@(_adaptiveNotificationsEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"PasscodeAppearanceEnabled", (CFPropertyListRef)@(_passcodeAppearanceEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"DockEnabled", (CFPropertyListRef)@(_dockEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"LiquidGlassEnabled", (CFPropertyListRef)@(_liquidGlassEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"ControlCenterEnabled", (CFPropertyListRef)@(_controlCenterEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"VolumeHUDEnabled", (CFPropertyListRef)@(_volumeHUDEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"VolumePillEnabled", (CFPropertyListRef)@(_volumePillEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSetValue(
        (CFStringRef)@"SilentHUDEnabled", (CFPropertyListRef)@(_silentHUDEnabled),
        (CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost
    );
    CFPreferencesSynchronize((CFStringRef)kSettingsDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
}

@end