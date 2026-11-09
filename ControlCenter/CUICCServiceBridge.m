#import "CUICCServiceBridge.h"
#import "../Core/CUICompatibility.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <unistd.h>
#import <CoreFoundation/CoreFoundation.h>

#pragma mark iOS 8 native CC module drivers

// iOS 8: Apple's own Control Center toggle drivers (SBCCSettingModule
// subclasses, verified in the 8.0 dumps): state / toggleState / activate.
// Routing through them gives the REAL system behavior for Wi-Fi,
// Bluetooth, DND, flashlight and orientation lock.
static NSMutableDictionary *s_ccModules = nil;

static id CUICCModuleFor(NSString *className) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s_ccModules = [[NSMutableDictionary alloc] init]; });

    @synchronized (s_ccModules) {
        id cached = s_ccModules[className];
        if (cached && cached != [NSNull null]) return cached;
        if (cached == [NSNull null]) return nil;

        Class cls = NSClassFromString(className);
        if (!cls) {
            s_ccModules[className] = [NSNull null];
            return nil;
        }
        id instance = [[cls alloc] init];
        if (!instance) {
            s_ccModules[className] = [NSNull null];
            return nil;
        }
        if ([instance respondsToSelector:@selector(warmup)]) {
            [instance performSelector:@selector(warmup)];
        }
        if ([instance respondsToSelector:@selector(activate)]) {
            [instance performSelector:@selector(activate)];
        }
        s_ccModules[className] = instance;
        return instance;
    }
}

static BOOL CUICCModuleOn(NSString *className) {
    id module = CUICCModuleFor(className);
    if (![module respondsToSelector:@selector(state)]) return NO;
    int state = ((int (*)(id, SEL))objc_msgSend)(module, @selector(state));
    return state != 0;
}

static void CUICCModuleSet(NSString *className, BOOL on) {
    id module = CUICCModuleFor(className);
    if (![module respondsToSelector:@selector(toggleState)]) return;
    BOOL isOn = NO;
    if ([module respondsToSelector:@selector(state)]) {
        isOn = ((int (*)(id, SEL))objc_msgSend)(module, @selector(state)) != 0;
    }
    if (isOn != on) [module performSelector:@selector(toggleState)];
}

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

// Ivar names + offsets of a shared instance (SpringBoard itself) — verifies
// where the live backlight level is stored on this exact firmware.
static void CUICCDumpIvars(NSMutableString *out, NSString *className) {
    Class cls = NSClassFromString(className);
    if (!cls) return;
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    [out appendFormat:@"\n===== ivars of %@ =====\n", className];
    for (unsigned int i = 0; i < count; i++) {
        char *nameBytes = ivar_getName(ivars[i]);
        char *typeBytes = ivar_getTypeEncoding(ivars[i]);
        [out appendFormat:@"  %@ @%lu type=%s\n",
            nameBytes ? [NSString stringWithUTF8String:nameBytes] : @"<unnamed>",
            (unsigned long)ivar_getOffset(ivars[i]),
            typeBytes ? typeBytes : "?"];
    }
    free(ivars);
}

// Call verified getters on shared instances and log the returned values —
// resolves "which selector reports the true service state" empirically.
// Returns -1 when the selector does not respond.
static int CUIBoolMessage(id object, NSString *selector) {
    if (!CUICCResponds(object, selector)) return -1;
    return ((int (*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(selector));
}

static void CUICCReadLiveStates(NSMutableString *out) {
    [out appendFormat:@"\n===== live states =====\n"];

    id bt = CUICCSharedInstanceFor(@"BluetoothManager", @"sharedInstance");
    [out appendFormat:@"  BluetoothManager powered=%d enabled=%d available=%d connectable=%d\n",
        CUIBoolMessage(bt, @"powered"),
        CUIBoolMessage(bt, @"enabled"),
        CUIBoolMessage(bt, @"available"),
        CUIBoolMessage(bt, @"connectable")];

    id wifi = CUICCSharedInstanceFor(@"SBWiFiManager", @"sharedInstance");
    [out appendFormat:@"  SBWiFiManager wiFiEnabled=%d isPowered=%d\n",
        CUIBoolMessage(wifi, @"wiFiEnabled"),
        CUIBoolMessage(wifi, @"isPowered")];

    id radios = [[NSClassFromString(@"RadiosPreferences") alloc] init];
    [out appendFormat:@"  RadiosPreferences airplaneMode=%d\n",
        CUIBoolMessage(radios, @"airplaneMode")];

    id media = CUICCSharedInstanceFor(@"SBMediaController", @"sharedInstance");
    [out appendFormat:@"  SBMediaController isPlaying=%d hasTrack=%d\n",
        CUIBoolMessage(media, @"isPlaying"),
        CUIBoolMessage(media, @"hasTrack")];

    // Where does SpringBoard keep its backlight? Direct ivar probe.
    id sb = [UIApplication sharedApplication];
    for (NSString *name in @[@"_currentBacklightLevel"]) {
        Ivar ivar = class_getInstanceVariable([sb class], [name UTF8String]);
        if (!ivar) {
            [out appendFormat:@"  ivar %@ <absent>\n", name];
            continue;
        }
        void *ptr = (void *)((char *)(__bridge void *)sb + ivar_getOffset(ivar));
        unsigned char *b = ptr;
        [out appendFormat:@"  ivar %@ @%lu: float=%.4f double=%.4f int=%d i64=%lld  bytes=%02x %02x %02x %02x %02x %02x %02x %02x\n",
            name,
            (unsigned long)ivar_getOffset(ivar),
            *(float *)ptr,
            *(double *)ptr,
            *(int32_t *)ptr,
            (long long)(*(int64_t *)ptr),
            b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]];
    }

    // Empirical mapping: push a known factor through the verified setter and
    // re-read the ivar raw bytes right after.
    if ([sb respondsToSelector:@selector(setBacklightFactor:)]) {
        ((void (*)(id, SEL, float))objc_msgSend)(sb, @selector(setBacklightFactor:), 0.30f);
        usleep(150000); // 150 ms
        Ivar ivar = class_getInstanceVariable([sb class], "_currentBacklightLevel");
        if (ivar) {
            void *ptr = (void *)((char *)(__bridge void *)sb + ivar_getOffset(ivar));
            unsigned char *b = ptr;
            [out appendFormat:@"  after setBacklightFactor:0.30 -> float=%.4f double=%.4f int=%d bytes=%02x %02x %02x %02x %02x %02x %02x %02x\n",
                *(float *)ptr, *(double *)ptr, *(int32_t *)ptr,
                b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]];
        }
        // restore
        ((void (*)(id, SEL, float))objc_msgSend)(sb, @selector(setBacklightFactor:), 0.70f);
    }

    // SBBrightnessController: the proper iOS 6 brightness path (headers).
    // Does -setBrightnessLevel: move the SpringBoard ivar?
    id brightCtl = CUICCSharedInstanceFor(@"SBBrightnessController", @"sharedBrightnessController");
    if (CUICCResponds(brightCtl, @"setBrightnessLevel:")) {
        ((void (*)(id, SEL, float))objc_msgSend)(brightCtl, @selector(setBrightnessLevel:), 0.30f);
        usleep(800000); // 800 ms: give the controller time to apply
        Ivar ivar = class_getInstanceVariable([sb class], "_currentBacklightLevel");
        float value = ivar
            ? *(float *)((char *)(__bridge void *)sb + ivar_getOffset(ivar))
            : -1.0f;
        [out appendFormat:@"  after SBBrightnessController setBrightnessLevel:0.30 -> ivar=%.4f\n",
            value];
        ((void (*)(id, SEL, float))objc_msgSend)(brightCtl, @selector(setBrightnessLevel:), 0.70f);
    } else {
        [out appendFormat:@"  SBBrightnessController <unavailable or selector missing>\n"];
    }

    // SBStatusBarDataManager: shared instance + quiet mode refresh available?
    id sbdm = CUICCSharedInstanceFor(@"SBStatusBarDataManager", @"sharedDataManager");
    [out appendFormat:@"  SBStatusBarDataManager shared=%@ _updateQuietModeItem=%d\n",
        sbdm ? @"yes" : @"no",
        CUIBoolMessage(sbdm, @"_updateQuietModeItem") != -1];

    // Does a programmatic SBWiFiManager toggle move its state getters?
    id wifiMgr = CUICCSharedInstanceFor(@"SBWiFiManager", @"sharedInstance");
    if (CUIBoolMessage(wifiMgr, @"isPowered") >= 0) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(wifiMgr, @selector(setWiFiEnabled:), NO);
        usleep(1500000); // 1.5 s
        [out appendFormat:@"  after setWiFiEnabled:NO -> wiFiEnabled=%d isPowered=%d\n",
            CUIBoolMessage(wifiMgr, @"wiFiEnabled"),
            CUIBoolMessage(wifiMgr, @"isPowered")];
        usleep(2500000); // +2.5 s
        [out appendFormat:@"  after setWiFiEnabled:NO +4s -> wiFiEnabled=%d isPowered=%d\n",
            CUIBoolMessage(wifiMgr, @"wiFiEnabled"),
            CUIBoolMessage(wifiMgr, @"isPowered")];
        ((void (*)(id, SEL, BOOL))objc_msgSend)(wifiMgr, @selector(setWiFiEnabled:), YES);
        usleep(2000000);
        [out appendFormat:@"  after setWiFiEnabled:YES -> wiFiEnabled=%d isPowered=%d\n",
            CUIBoolMessage(wifiMgr, @"wiFiEnabled"),
            CUIBoolMessage(wifiMgr, @"isPowered")];
    }

    CFPropertyListRef dnd = CFPreferencesCopyAppValue(
        (CFStringRef)@"dndEnabled", (CFStringRef)@"com.apple.DoNotDisturb");
    [out appendFormat:@"  dndEnabled pref = %@\n", dnd ? CFBridgingRelease(dnd) : @"<absent>"];

    // Full DoNotDisturb domain snapshot: reveals every key Settings writes
    // (dndEnabled alone may not be the whole story for the quiet-mode UI).
    CFArrayRef dndKeys = CFPreferencesCopyKeyList(
        (CFStringRef)@"com.apple.DoNotDisturb", kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    if (dndKeys) {
        CFIndex n = CFArrayGetCount(dndKeys);
        [out appendFormat:@"  DoNotDisturb domain (%ld keys):\n", (long)n];
        for (CFIndex i = 0; i < n; i++) {
            NSString *key = (__bridge NSString *)CFArrayGetValueAtIndex(dndKeys, i);
            CFPropertyListRef v = CFPreferencesCopyAppValue(
                (CFStringRef)key, (CFStringRef)@"com.apple.DoNotDisturb");
            [out appendFormat:@"    %@ = %@\n", key, v ? CFBridgingRelease(v) : @"<nil>"];
        }
        CFRelease(dndKeys);
    } else {
        [out appendString:@"  DoNotDisturb domain: <no keys>\n"];
    }
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
    NSArray *classes = @[@"SBWiFiManager", @"BluetoothManager", @"RadiosPreferences",
                         @"SBMediaController", @"VolumeControl", @"SpringBoard",
                         @"SBCCWiFiSetting", @"SBBrightnessController",
                         @"SBStatusBarDataManager", @"SBStatusBarController",
                         @"SBDoNotDisturbController", @"SBDNDState", @"SBUIController"];
    for (NSString *name in classes) CUICCDumpClassMethods(out, name);
    CUICCDumpIvars(out, @"SpringBoard"); // ivar list of the UIApplication singleton class
    CUICCReadLiveStates(out);
    [out writeToFile:@"/var/mobile/legacyui_probe.txt"
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:marker error:NULL];
}

#pragma mark Bluetooth (verified: BluetoothManager.h iOS 6.1)

- (BOOL)bluetoothEnabled {
    if (!CUIIsiOS6OrEarlier()) return CUICCModuleOn(@"SBCCBluetoothSetting");
    id manager = CUICCSharedInstanceFor(@"BluetoothManager", @"sharedInstance");
    if (!CUICCResponds(manager, @"powered")) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, @selector(powered));
}

- (void)setBluetoothEnabled:(BOOL)enabled {
    if (!CUIIsiOS6OrEarlier()) {
        CUICCModuleSet(@"SBCCBluetoothSetting", enabled);
        return;
    }
    id manager = CUICCSharedInstanceFor(@"BluetoothManager", @"sharedInstance");
    if (!CUICCResponds(manager, @"setPowered:")) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, @selector(setPowered:), enabled);
}

#pragma mark Airplane (verified: RadiosPreferences.h AppSupport iOS 6.1)

- (BOOL)airplaneMode {
    if (!CUIIsiOS6OrEarlier()) return CUICCModuleOn(@"SBCCAirplaneModeSetting");
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

#pragma mark Wi-Fi (verified by on-device probe: SBWiFiManager
//   +sharedInstance, -wiFiEnabled, -setWiFiEnabled:)

- (id)wiFiManager {
    return CUICCSharedInstanceFor(@"SBWiFiManager", @"sharedInstance");
}

- (BOOL)wiFiEnabled {
    if (!CUIIsiOS6OrEarlier()) return CUICCModuleOn(@"SBCCWiFiSetting");
    id manager = [self wiFiManager];
    if (!CUICCResponds(manager, @"wiFiEnabled")) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, @selector(wiFiEnabled));
}

- (void)setWiFiEnabled:(BOOL)enabled {
    if (!CUIIsiOS6OrEarlier()) {
        CUICCModuleSet(@"SBCCWiFiSetting", enabled);
        return;
    }
    id manager = [self wiFiManager];
    if (!CUICCResponds(manager, @"setWiFiEnabled:")) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, @selector(setWiFiEnabled:), enabled);
}

// -isPowered verified by the on-device probe: actual Wi-Fi radio power.
// SBWiFiManager -wiFiEnabled tracks the Settings switch state and did not
// reflect programmatic toggles, so the glow is driven from the radio state.
- (BOOL)wiFiPowered {
    id manager = [self wiFiManager];
    if (!CUICCResponds(manager, @"isPowered")) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, @selector(isPowered));
}

#pragma mark Do Not Disturb (iOS 6: com.apple.DoNotDisturb dndEnabled preference)

// Settings.app writes the mobile user domain; SpringBoard does NOT re-read
// the AnyUser (root) file, so the status-bar moon never shows. Match Settings.
- (BOOL)doNotDisturbEnabled {
    if (!CUIIsiOS6OrEarlier()) return CUICCModuleOn(@"SBCCDoNotDisturbSetting");
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
        (CFStringRef)@"com.apple.DoNotDisturb", kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    CFPreferencesSynchronize(
        (CFStringRef)@"com.apple.DoNotDisturb", kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (CFStringRef)@"com.apple.DoNotDisturb.changed", NULL, NULL, TRUE);

    // The iOS 6 status-bar moon (quiet mode item) re-reads prefs here —
    // verified +sharedDataManager, -_updateQuietModeItem AND -_quietModeChange
    // (the notification handler itself) in the on-device dump of
    // SBStatusBarDataManager. Belt and suspenders: the handler re-reads the
    // pref and re-posts status bar data; the update method refreshes the item.
    id manager = CUICCSharedInstanceFor(@"SBStatusBarDataManager", @"sharedDataManager");
    if (CUICCResponds(manager, @"_quietModeChange")) {
        [manager performSelector:@selector(_quietModeChange)];
    }
    if (CUICCResponds(manager, @"_updateQuietModeItem")) {
        [manager performSelector:@selector(_updateQuietModeItem)];
    }
}

#pragma mark Brightness (verified: SBBrightnessController iOS 6.1 headers)

// The SpringBoard ivar _currentBacklightLevel is NOT updated by
// setBacklightFactor: on-device (probe: stays 0.0), so the getter tracks the
// last pushed level; when the ivar shows a live value it wins.
static float s_lastBrightness = 0.0;

- (id)brightnessController {
    return CUICCSharedInstanceFor(@"SBBrightnessController", @"sharedBrightnessController");
}

- (float)brightness {
    if (!CUIIsiOS6OrEarlier()) {
        float value = (float)[UIScreen mainScreen].brightness;
        if (value > 0.001f) return value;
        return s_lastBrightness > 0.0f ? s_lastBrightness : 0.5f;
    }
    id app = [UIApplication sharedApplication];
    Ivar ivar = class_getInstanceVariable([app class], "_currentBacklightLevel");
    if (ivar) {
        float value = *(float *)((char *)(__bridge void *)app + ivar_getOffset(ivar));
        if (value > 0.001f && value <= 1.0f) return value;
    }
    return s_lastBrightness > 0.0f ? s_lastBrightness : 0.75f;
}

- (void)setBrightness:(float)level {
    if (!CUIIsiOS6OrEarlier()) {
        [UIScreen mainScreen].brightness = level;
        s_lastBrightness = level;
        return;
    }
    id controller = [self brightnessController];
    // _setBrightnessLevel:showHUD: / setBrightnessLevel: verified in
    // SBBrightnessController.h (iOS 6.1) — the system path SpringBoard uses
    // itself; setBacklightFactor: froze touch handling on the 3GS.
    if (CUICCResponds(controller, @"setBrightnessLevel:")) {
        ((void (*)(id, SEL, float))objc_msgSend)(controller, @selector(setBrightnessLevel:), level);
    } else {
        id sb = [UIApplication sharedApplication];
        if (![sb respondsToSelector:@selector(setBacklightFactor:)]) return;
        ((void (*)(id, SEL, float))objc_msgSend)(sb, @selector(setBacklightFactor:), level);
    }
    s_lastBrightness = level;
}

#pragma mark Torch / rotation lock (iOS 8 CC drivers; no-op on iOS 6)

- (BOOL)torchEnabled {
    if (CUIIsiOS6OrEarlier()) return NO; // 3GS has no LED flash
    return CUICCModuleOn(@"SBCCFlashlightSetting");
}

- (void)setTorchEnabled:(BOOL)enabled {
    if (CUIIsiOS6OrEarlier()) return;
    CUICCModuleSet(@"SBCCFlashlightSetting", enabled);
}

- (BOOL)orientationLocked {
    if (CUIIsiOS6OrEarlier()) return NO;
    return CUICCModuleOn(@"SBCCOrientationLockSetting");
}

- (void)setOrientationLocked:(BOOL)locked {
    if (CUIIsiOS6OrEarlier()) return;
    CUICCModuleSet(@"SBCCOrientationLockSetting", locked);
}

#pragma mark Media (verified: SBMediaController.h iOS 6.1 + 8.0)

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

// Verified by the on-device probe: -trackElapsedTime, -trackDuration,
// -setCurrentTrackTime:.
static NSString *CUICCFormatSeconds(double seconds) {
    if (seconds < 0 || seconds > 3600 * 24) return @"0:00";
    int total = (int)lround(seconds);
    return [NSString stringWithFormat:@"%d:%02d", total / 60, total % 60];
}

- (double)mediaTrackDuration {
    id controller = [self mediaController];
    if (!CUICCResponds(controller, @"trackDuration")) return 0.0;
    return ((double (*)(id, SEL))objc_msgSend)(controller, @selector(trackDuration));
}

- (double)mediaTrackElapsed {
    id controller = [self mediaController];
    if (!CUICCResponds(controller, @"trackElapsedTime")) return 0.0;
    return ((double (*)(id, SEL))objc_msgSend)(controller, @selector(trackElapsedTime));
}

- (float)mediaTrackProgress {
    double duration = [self mediaTrackDuration];
    if (duration <= 1.0) return 0.0;
    double progress = [self mediaTrackElapsed] / duration;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    return (float)progress;
}

- (void)mediaSetTrackProgress:(float)progress {
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    double duration = [self mediaTrackDuration];
    if (duration <= 0) return;
    id controller = [self mediaController];
    if (CUICCResponds(controller, @"setCurrentTrackTime:")) {
        ((void (*)(id, SEL, double))objc_msgSend)(controller,
            @selector(setCurrentTrackTime:), duration * progress);
    }
}

- (NSString *)mediaTrackElapsedString {
    return CUICCFormatSeconds([self mediaTrackElapsed]);
}

- (NSString *)mediaTrackDurationString {
    return CUICCFormatSeconds([self mediaTrackDuration]);
}

@end