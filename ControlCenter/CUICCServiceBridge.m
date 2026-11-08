#import "CUICCServiceBridge.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>

static id CUICCSharedInstanceFor(NSString *className, NSString *sharedSelector) {
    Class cls = NSClassFromString(className);
    if (!cls) return nil;
    SEL sel = NSSelectorFromString(sharedSelector);
    if (!class_getClassMethod(cls, sel)) return nil;
    return [cls performSelector:sel];
}

static BOOL CUICCResponds(id object, NSString *selector) {
    if (!object) return NO;
    return [object respondsToSelector:NSSelectorFromString(selector)];
}

#pragma mark - Runtime probe

static void CUICCDumpClassMethods(NSMutableString *out, NSString *className) {
    Class cls = NSClassFromString(className);
    [out appendFormat:@"\n===== %@ =====\n", className];
    if (!cls) {
        [out appendString:@"  <class not found>\n"];
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(object_getClass(cls), &count); // class methods
    [out appendString:@"  + class methods:\n"];
    for (unsigned int i = 0; i < count; i++) {
        [out appendFormat:@"    + %@\n", NSStringFromSelector(method_getName(methods[i]))];
    }
    free(methods);

    methods = class_copyMethodList(cls, &count); // instance methods
    [out appendString:@"  - instance methods:\n"];
    for (unsigned int i = 0; i < count; i++) {
        [out appendFormat:@"    - %@\n", NSStringFromSelector(method_getName(methods[i]))];
    }
    free(methods);
}

@implementation CUICCServiceBridge

+ (instancetype)sharedBridge {
    static CUICCServiceBridge *bridge = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ bridge = [[CUICCServiceBridge alloc] init]; });
    return bridge;
}

+ (void)probeClassesIfNeeded {
    NSString *marker = @"/var/mobile/.legacyui_probe";
    if (![[NSFileManager defaultManager] fileExistsAtPath:marker]) return;

    NSMutableString *out = [NSMutableString string];
    NSArray *classes = @[@"WiFiManager", @"SBWiFiManager", @"BluetoothManager",
                         @"RadiosPreferences", @"SBMediaController", @"VolumeControl",
                         @"SpringBoard", @"SBCCWiFiSetting"];
    for (NSString *name in classes) CUICCDumpClassMethods(out, name);
    [out writeToFile:@"/var/mobile/legacyui_probe.txt"
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:marker error:NULL];
}

#pragma mark Bluetooth (verified: BluetoothManager.h iOS 6.1)

- (BOOL)bluetoothEnabled {
    id manager = CUICCSharedInstanceFor(@"BluetoothManager", @"sharedInstance");
    if (!CUICCResponds(manager, @"powered")) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, @selector(powered));
}

- (void)setBluetoothEnabled:(BOOL)enabled {
    id manager = CUICCSharedInstanceFor(@"BluetoothManager", @"sharedInstance");
    if (!CUICCResponds(manager, @"setPowered:")) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, @selector(setPowered:), enabled);
}

#pragma mark Airplane (verified: RadiosPreferences.h AppSupport iOS 6.1)

- (BOOL)airplaneMode {
    // No shared instance — create fresh, read, release (ARC).
    Class cls = NSClassFromString(@"RadiosPreferences");
    if (!cls) return NO;
    id prefs = [[cls alloc] init];
    if (![prefs respondsToSelector:@selector(airplaneMode)]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(prefs, @selector(airplaneMode));
}

- (void)setAirplaneMode:(BOOL)enabled {
    Class cls = NSClassFromString(@"RadiosPreferences");
    if (!cls) return;
    id prefs = [[cls alloc] init];
    if (![prefs respondsToSelector:@selector(setAirplaneMode:)]) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(prefs, @selector(setAirplaneMode:), enabled);
    if ([prefs respondsToSelector:@selector(synchronize)]) {
        [prefs performSelector:@selector(synchronize)];
    }
}

#pragma mark Wi-Fi (wiring pending on-device probe)

- (BOOL)wiFiEnabled {
    return NO;
}

- (void)setWiFiEnabled:(BOOL)enabled {
    (void)enabled;
}

#pragma mark Do Not Disturb (iOS 6: com.apple.DoNotDisturb dndEnabled preference)

- (BOOL)doNotDisturbEnabled {
    CFPropertyListRef value = CFPreferencesCopyAppValue(
        (CFStringRef)@"dndEnabled", (CFStringRef)@"com.apple.DoNotDisturb");
    if (value) {
        id number = CFBridgingRelease(value);
        if ([number isKindOfClass:[NSNumber class]]) return [number boolValue];
    }
    return NO;
}

- (void)setDoNotDisturbEnabled:(BOOL)enabled {
    CFPreferencesSetValue(
        (CFStringRef)@"dndEnabled", (CFPropertyListRef)@(enabled),
        (CFStringRef)@"com.apple.DoNotDisturb", kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
    CFPreferencesSynchronize(
        (CFStringRef)@"com.apple.DoNotDisturb", kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (CFStringRef)@"com.apple.DoNotDisturb.changed", NULL, NULL, TRUE);
}

#pragma mark Brightness (verified: SpringBoard setBacklightFactor: / _currentBacklightLevel)

- (float)brightness {
    id app = [UIApplication sharedApplication];
    Ivar ivar = class_getInstanceVariable([app class], "_currentBacklightLevel");
    if (!ivar) return 0.5;
    // float ivar: read raw memory to avoid broken object bridging.
    void *ptr = (void *)((char *)(__bridge void *)app + ivar_getOffset(ivar));
    return *(float *)ptr;
}

- (void)setBrightness:(float)level {
    id app = [UIApplication sharedApplication];
    if (![app respondsToSelector:@selector(setBacklightFactor:)]) return;
    ((void (*)(id, SEL, float))objc_msgSend)(app, @selector(setBacklightFactor:), level);
}

#pragma mark Media (verified: SBMediaController.h iOS 6.1)

- (id)mediaController {
    return CUICCSharedInstanceFor(@"SBMediaController", @"sharedInstance");
}

- (NSString *)mediaTitle {
    id controller = [self mediaController];
    if (CUICCResponds(controller, @"nowPlayingTitle")) {
        return [controller performSelector:@selector(nowPlayingTitle)];
    }
    return nil;
}

- (NSString *)mediaArtist {
    id controller = [self mediaController];
    if (CUICCResponds(controller, @"nowPlayingArtist")) {
        return [controller performSelector:@selector(nowPlayingArtist)];
    }
    return nil;
}

- (BOOL)mediaPlaying {
    id controller = [self mediaController];
    // -isPlaying verified by the on-device runtime probe (real method list).
    if (CUICCResponds(controller, @"isPlaying")) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(controller, @selector(isPlaying));
    }
    Ivar ivar = class_getInstanceVariable([controller class], "_lastNowPlayingAppIsPlaying");
    if (!ivar) return NO;
    void *ptr = (void *)((char *)(__bridge void *)controller + ivar_getOffset(ivar));
    return *(BOOL *)ptr;
}

- (void)mediaTogglePlayPause {
    id controller = [self mediaController];
    if (CUICCResponds(controller, @"togglePlayPause")) {
        [controller performSelector:@selector(togglePlayPause)];
    }
}

- (void)mediaSkip:(int)direction {
    id controller = [self mediaController];
    if (CUICCResponds(controller, @"changeTrack:")) {
        ((void (*)(id, SEL, int))objc_msgSend)(controller, @selector(changeTrack:), direction);
    }
}

@end