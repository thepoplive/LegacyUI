#import "CUIConfiguration.h"

static NSString * const kSettingsDomain = @"com.legacyui.settings";

static NSDictionary *LUIFileDictionary() {
    NSString *path = [@"/var/mobile/Library/Preferences"
        stringByAppendingPathComponent:[kSettingsDomain stringByAppendingString:@".plist"]];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if ([dict isKindOfClass:[NSDictionary class]]) return dict;
    return nil;
}

static BOOL LUIReadFlag(NSString *key, NSDictionary *fileDict) {
    CFPropertyListRef raw = CFPreferencesCopyAppValue(
        (CFStringRef)key, (CFStringRef)kSettingsDomain);
    if (raw) {
        id value = CFBridgingRelease(raw);
        if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
    }
    id fileValue = fileDict[key];
    if ([fileValue isKindOfClass:[NSNumber class]]) return [fileValue boolValue];
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
    NSDictionary *fileDict = LUIFileDictionary();

    _enabled = LUIReadFlag(@"Enabled", fileDict);
    _lockScreenEnabled = LUIReadFlag(@"LockScreenEnabled", fileDict);
    _adaptiveClockEnabled = LUIReadFlag(@"AdaptiveClockEnabled", fileDict);
    _adaptiveNotificationsEnabled = LUIReadFlag(@"AdaptiveNotificationsEnabled", fileDict);
    _passcodeAppearanceEnabled = LUIReadFlag(@"PasscodeAppearanceEnabled", fileDict);
    _dockEnabled = LUIReadFlag(@"DockEnabled", fileDict);
    _liquidGlassEnabled = LUIReadFlag(@"LiquidGlassEnabled", fileDict);
    _controlCenterEnabled = LUIReadFlag(@"ControlCenterEnabled", fileDict);
    _volumeHUDEnabled = LUIReadFlag(@"VolumeHUDEnabled", fileDict);
    _volumePillEnabled = LUIReadFlag(@"VolumePillEnabled", fileDict);
    _silentHUDEnabled = LUIReadFlag(@"SilentHUDEnabled", fileDict);
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

    [settings writeToFile:[@"/var/mobile/Library/Preferences"
        stringByAppendingPathComponent:[kSettingsDomain stringByAppendingString:@".plist"]]
             atomically:YES];
}

@end