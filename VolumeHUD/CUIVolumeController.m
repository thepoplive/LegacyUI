#import "CUIVolumeController.h"
#import "CUIVolumePillView.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIOverlayWindow.h"
#import "../Core/CUIGlobalState.h"
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

// iOS 6 SpringBoard volume bridge (per legacyui_ios.md):
//   VolumeControl: +sharedVolumeControl, -getMediaVolume, -setMediaVolume:
static id LUIIOS6SharedVolumeControl() {
    Class volumeControlClass = NSClassFromString(@"VolumeControl");
    if (!volumeControlClass) return nil;
    if (!class_getClassMethod(volumeControlClass, @selector(sharedVolumeControl))) return nil;
    id shared = [volumeControlClass performSelector:@selector(sharedVolumeControl)];
    return shared;
}

static float LUIIOS6GetMediaVolume(id shared) {
    if (!shared) return -1.0f;
    if (!class_getInstanceMethod([shared class], @selector(getMediaVolume))) return -1.0f;
    return ((float (*)(id, SEL))objc_msgSend)(shared, @selector(getMediaVolume));
}

static void LUIIOS6SetMediaVolume(id shared, float volume) {
    if (!shared) return;
    if (!class_getInstanceMethod([shared class], @selector(setMediaVolume:))) return;
    ((void (*)(id, SEL, float))objc_msgSend)(shared, @selector(setMediaVolume:), volume);
}

static dispatch_once_t g_hudSwizzleOnce;
static dispatch_once_t g_progressSwizzleOnce;
static IMP g_origPresentHUD = NULL;
static IMP g_origPresentHUDAuto = NULL;
static IMP g_origSetProgress = NULL;

static BOOL LUIVolumeWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.volumeHUDEnabled && config.volumePillEnabled;
}

static BOOL LUISilentWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.silentHUDEnabled;
}

// Verified against iOS 8.0 headers (MP0w/iOS-Headers):
//   SBHUDController: -presentHUDView:, -presentHUDView:autoDismissWithDelay:
//   SBRingerHUDView: @property(getter=isSilent) BOOL silent
// Returns YES when the system HUD is replaced by our pill (suppress original).
static BOOL LUIHandlePresentedHUD(id hudView) {
    if (!hudView) return NO;

    Class volumeClass = NSClassFromString(@"SBVolumeHUDView");
    Class ringerClass = NSClassFromString(@"SBRingerHUDView");

    if (volumeClass && [hudView isKindOfClass:volumeClass]) {
        if (LUIVolumeWanted()) {
            [[CUIVolumeController sharedInstance] showVolumePill];
            return YES; // suppress system volume HUD
        }
        return NO;
    }

    if (ringerClass && [hudView isKindOfClass:ringerClass]) {
        if (LUISilentWanted()) {
            BOOL silent = NO;
            if (class_getInstanceMethod([hudView class], @selector(isSilent))) {
                NSNumber *silentNumber = [hudView valueForKey:@"silent"];
                if ([silentNumber isKindOfClass:[NSNumber class]]) {
                    silent = [silentNumber boolValue];
                }
            }
            [[CUIVolumeController sharedInstance] showMutePillSilent:silent];
            return YES; // suppress system ringer HUD
        }
        return NO;
    }

    return NO;
}

static void LUIPresentHUDSwizzled(id self, SEL _cmd, id hudView) {
    BOOL suppress = LUIHandlePresentedHUD(hudView);
    if (!suppress && g_origPresentHUD) {
        ((void (*)(id, SEL, id))g_origPresentHUD)(self, _cmd, hudView);
    }
}

static void LUIPresentHUDAutoSwizzled(id self, SEL _cmd, id hudView, double delay) {
    BOOL suppress = LUIHandlePresentedHUD(hudView);
    if (!suppress && g_origPresentHUDAuto) {
        ((void (*)(id, SEL, id, double))g_origPresentHUDAuto)(self, _cmd, hudView, delay);
    }
}

// Verified: SBVolumeHUDView -setProgress:(float) exists on iOS 6.1 and 8.x.
// SpringBoard reuses the HUD view and only calls setProgress: on subsequent
// hardware volume presses, so this drives live pill updates.
static void LUIProgressSwizzled(id self, SEL _cmd, float progress) {
    if (g_origSetProgress) {
        ((void (*)(id, SEL, float))g_origSetProgress)(self, _cmd, progress);
    }
    if (LUIVolumeWanted()) {
        [[CUIVolumeController sharedInstance] presentVolumeProgress:progress];
    }
}

static void LUISwizzleVolumeProgress() {
    dispatch_once(&g_progressSwizzleOnce, ^{
        Class volumeClass = NSClassFromString(@"SBVolumeHUDView");
        if (!volumeClass) return;
        Method method = class_getInstanceMethod(volumeClass, @selector(setProgress:));
        if (!method) {
            NSLog(@"[LegacyUI] SBVolumeHUDView setProgress: unsupported");
            return;
        }
        if (class_addMethod(volumeClass, @selector(setProgress:),
                            (IMP)LUIProgressSwizzled, method_getTypeEncoding(method))) {
            g_origSetProgress = method_getImplementation(method);
        } else {
            g_origSetProgress = method_setImplementation(method, (IMP)LUIProgressSwizzled);
        }
        NSLog(@"[LegacyUI] SBVolumeHUDView setProgress: swizzled");
    });
}

static void LUISwizzleHUDController() {
    dispatch_once(&g_hudSwizzleOnce, ^{
        Class hudClass = NSClassFromString(@"SBHUDController");
        if (!hudClass) {
            NSLog(@"[LegacyUI] SBHUDController not found");
            return;
        }

        Method m1 = class_getInstanceMethod(hudClass, @selector(presentHUDView:));
        if (m1) {
            if (class_addMethod(hudClass, @selector(presentHUDView:),
                                (IMP)LUIPresentHUDSwizzled, method_getTypeEncoding(m1))) {
                g_origPresentHUD = method_getImplementation(m1);
            } else {
                g_origPresentHUD = method_setImplementation(m1, (IMP)LUIPresentHUDSwizzled);
            }
        }

        Method m2 = class_getInstanceMethod(hudClass,
                                            @selector(presentHUDView:autoDismissWithDelay:));
        if (m2) {
            if (class_addMethod(hudClass, @selector(presentHUDView:autoDismissWithDelay:),
                                (IMP)LUIPresentHUDAutoSwizzled, method_getTypeEncoding(m2))) {
                g_origPresentHUDAuto = method_getImplementation(m2);
            } else {
                g_origPresentHUDAuto = method_setImplementation(m2, (IMP)LUIPresentHUDAutoSwizzled);
            }
        }

        NSLog(@"[LegacyUI] SBHUDController swizzled");
    });
}

@interface CUIVolumeController ()
@property (nonatomic, strong) MPVolumeView *volumeViewHack;
@property (nonatomic, strong) UISlider *systemVolumeSlider;
@property (nonatomic, strong) CUIVolumePillView *pill;
@property (nonatomic, assign) float currentVolume;
@end

@implementation CUIVolumeController

+ (instancetype)sharedInstance {
    static CUIVolumeController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CUIVolumeController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentVolume = 0.5;
    }
    return self;
}

- (void)activate {
    LUISwizzleHUDController();
    LUISwizzleVolumeProgress();
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (config.enabled && config.volumeHUDEnabled && config.volumePillEnabled) {
        // iOS 6 reads volume through VolumeControl; iOS 8 uses the MPVolumeView slider.
        if (!CUIIsiOS6OrEarlier()) {
            [self installVolumeObserverIfNeeded];
        } else {
            float volume = LUIIOS6GetMediaVolume(LUIIOS6SharedVolumeControl());
            if (volume >= 0.0f) _currentVolume = volume;
        }
    }
}

- (void)deactivate {
    [self.pill hideWithAnimation];
}

- (UIWindow *)hostWindow {
    UIWindow *key = [[UIApplication sharedApplication] keyWindow];
    if (key) return key;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window) return window;
    }
    return nil;
}

- (void)installVolumeObserverIfNeeded {
    if (_systemVolumeSlider) return;

    UIWindow *window = [self hostWindow];
    if (!window) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self activate];
        });
        return;
    }

    _volumeViewHack = [[MPVolumeView alloc] initWithFrame:CGRectMake(-2000, -2000, 60, 30)];
    [window addSubview:_volumeViewHack];

    for (UIView *sub in _volumeViewHack.subviews) {
        if ([sub isKindOfClass:[UISlider class]]) {
            _systemVolumeSlider = (UISlider *)sub;
            break;
        }
    }

    if (_systemVolumeSlider) {
        _currentVolume = _systemVolumeSlider.value;
        [_systemVolumeSlider addTarget:self
                                action:@selector(systemVolumeChanged:)
                      forControlEvents:UIControlEventValueChanged];
        NSLog(@"[LegacyUI] Volume observer attached");
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self installVolumeObserverIfNeeded];
        });
    }
}

- (void)systemVolumeChanged:(UISlider *)sender {
    if (!LUIVolumeWanted()) return;
    _currentVolume = sender.value;
    if (LUIVolumePillSuppressedByCC(_currentVolume)) return;
    [self presentPill:^(CUIVolumePillView *pill) {
        [pill configureAsVolume];
        pill.volumeLevel = _currentVolume;
    }];
}

- (CGRect)pillFrameInWindow {
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat width = MIN(bounds.size.width - 40.0, 200.0);
    return CGRectMake((bounds.size.width - width) / 2.0, 22.0, width, 54.0);
}

// While the Control Center is open the hardware volume buttons must not pop
// up the pill — the CC volume slider follows them instead (the CC controller
// listens for CUICCVolumeChangedNotification and refreshes its slider).
// Volume paths only — the ringer/mute pill still shows while CC is open.
static BOOL LUIVolumePillSuppressedByCC(float volume) {
    if (!g_ccIsOpen) return NO;
    [[NSNotificationCenter defaultCenter]
         postNotificationName:CUICCVolumeChangedNotification
                       object:nil
                     userInfo:@{@"value": @(volume)}];
    return YES;
}

- (void)presentPill:(void (^)(CUIVolumePillView *pill))configure {
    if (!LUIVolumeWanted() && !LUISilentWanted()) return;

    // Own high-level window: the pill stays visible over apps and the lock screen.
    UIWindow *window = CUISharedOverlayWindow();
    if (!window) return;

    if (!_pill) {
        _pill = [[CUIVolumePillView alloc] initWithFrame:[self pillFrameInWindow]];

        __weak CUIVolumeController *weakSelf = self;
        _pill.onVolumeUserChange = ^(float volume) {
            [weakSelf setSystemVolume:volume];
        };
    }

    if (_pill.superview != window) {
        [_pill removeFromSuperview];
        [window addSubview:_pill];
    }

    window.frame = [UIScreen mainScreen].bounds;
    _pill.frame = [self pillFrameInWindow];
    if (configure) configure(_pill);
    [_pill showWithAnimation];
}

- (float)readSystemVolume {
    if (CUIIsiOS6OrEarlier()) {
        float volume = LUIIOS6GetMediaVolume(LUIIOS6SharedVolumeControl());
        if (volume >= 0.0f) return volume;
        return _currentVolume;
    }
    if (_systemVolumeSlider) return _systemVolumeSlider.value;
    return _currentVolume;
}

- (void)showVolumePill {
    _currentVolume = [self readSystemVolume];
    if (LUIVolumePillSuppressedByCC(_currentVolume)) return;
    [self presentPill:^(CUIVolumePillView *pill) {
        [pill configureAsVolume];
        pill.volumeLevel = _currentVolume;
    }];
}

- (void)presentVolumeProgress:(float)progress {
    if (progress < 0.0f || progress > 1.0f) return;
    _currentVolume = progress;
    if (LUIVolumePillSuppressedByCC(_currentVolume)) return;
    [self presentPill:^(CUIVolumePillView *pill) {
        [pill configureAsVolume];
        pill.volumeLevel = progress;
    }];
}

- (void)showMutePillSilent:(BOOL)silent {
    if (!LUISilentWanted()) return;
    [self presentPill:^(CUIVolumePillView *pill) {
        [pill configureAsMuteSilent:silent];
    }];
}

- (void)hideVolumePill {
    [_pill hideWithAnimation];
}

- (void)setSystemVolume:(float)volume {
    if (fabsf(volume - _currentVolume) < 0.001) return;
    _currentVolume = volume;

    if (CUIIsiOS6OrEarlier()) {
        LUIIOS6SetMediaVolume(LUIIOS6SharedVolumeControl(), volume);
    } else if (_systemVolumeSlider) {
        _systemVolumeSlider.value = volume;
    }
}

// Control Center volume slider (commit on release): route through the real
// setter so the change reaches the system (VolumeControl on iOS 6, the hidden
// MPVolumeView slider on iOS 8).
- (void)updateVolume:(float)volume {
    if (CUIIsiOS6OrEarlier()) {
        // The MPVolumeView observer below is iOS-8-only; iOS 6 goes straight
        // to VolumeControl -setMediaVolume:.
    } else if (!_systemVolumeSlider) {
        [self installVolumeObserverIfNeeded];
    }
    [self setSystemVolume:volume]; // sets _currentVolume and pushes to system
    if (_pill) _pill.volumeLevel = _currentVolume; // CC is overriding the pill value
}

@end