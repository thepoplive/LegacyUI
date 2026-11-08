#import "CUIControlCenterController.h"
#import "CUIControlCenterView.h"
#import "CUIControlCenterGrabber.h"
#import "CUICCServiceBridge.h"
#import "CUISliderControl.h"
#import "CUIMusicCard.h"
#import "CUIControlCenterItem.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIOverlayWindow.h"
#import "../Core/CUIGlobalState.h"
#import "../VolumeHUD/CUIVolumeController.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Verified in iOS 6.1 & 8.0 SpringBoard.h:
//   - (void)menuButtonDown:(struct __GSEvent *)arg1;
//   - (void)applicationOpenURL:(id)arg1;
static dispatch_once_t g_ccSwizzleOnce;
static IMP g_origMenuButtonDown = NULL;

static void CUICCTrace(NSString *line) {
    NSString *path = @"/var/mobile/legacyui_cc_trace.txt";
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:path
                                                              usedEncoding:NULL error:NULL];
    if (!content) content = [NSMutableString string];
    [content appendFormat:@"[%@] %@\n", [NSDate date], line];
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static void CUICCMenuButtonDownSwizzled(id self, SEL _cmd, void *event);

// Verified in iOS 6.1 SpringBoard.h: - (void)frontDisplayDidChange;
static IMP g_origFrontDisplayDidChange = NULL;

static void CUICCFrontDisplaySwizzled(id self, SEL _cmd) {
    if (g_origFrontDisplayDidChange) {
        ((void (*)(id, SEL))g_origFrontDisplayDidChange)(self, _cmd);
    }
    [[CUIControlCenterController sharedInstance] updateGrabberVisibility];
}

static void CUICCSwizzleFrontDisplay() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class sbClass = NSClassFromString(@"SpringBoard");
        if (!sbClass) return;
        Method method = class_getInstanceMethod(sbClass, @selector(frontDisplayDidChange));
        if (!method) {
            CUICCTrace(@"frontDisplayDidChange unavailable");
            return;
        }
        if (class_addMethod(sbClass, @selector(frontDisplayDidChange),
                            (IMP)CUICCFrontDisplaySwizzled,
                            method_getTypeEncoding(method))) {
            g_origFrontDisplayDidChange = method_getImplementation(method);
        } else {
            g_origFrontDisplayDidChange = method_setImplementation(method,
                                                                    (IMP)CUICCFrontDisplaySwizzled);
        }
        CUICCTrace(@"frontDisplayDidChange swizzled");
    });
}

static void CUICCSwizzleMenuButton() {
    dispatch_once(&g_ccSwizzleOnce, ^{
        Class sbClass = NSClassFromString(@"SpringBoard");
        if (!sbClass) return;
        Method method = class_getInstanceMethod(sbClass, @selector(menuButtonDown:));
        if (!method) {
            NSLog(@"[LegacyUI] menuButtonDown: unavailable — Home close disabled");
            return;
        }
        if (class_addMethod(sbClass, @selector(menuButtonDown:),
                            (IMP)CUICCMenuButtonDownSwizzled,
                            method_getTypeEncoding(method))) {
            g_origMenuButtonDown = method_getImplementation(method);
        } else {
            g_origMenuButtonDown = method_setImplementation(method,
                                                            (IMP)CUICCMenuButtonDownSwizzled);
        }
        NSLog(@"[LegacyUI] menuButtonDown: swizzled");
    });
}

static void CUICCMenuButtonDownSwizzled(id self, SEL _cmd, void *event) {
    if ([[CUIControlCenterController sharedInstance] isOpen]) {
        [[CUIControlCenterController sharedInstance] closeControlCenter];
        return; // swallow: Home closes CC first
    }
    if (g_origMenuButtonDown) {
        ((void (*)(id, SEL, void *))g_origMenuButtonDown)(self, _cmd, event);
    }
}

@interface CUIControlCenterController ()
@property (nonatomic, strong) CUIControlCenterGrabber *grabber;
@property (nonatomic, strong) CUIControlCenterView *panelView;
@property (nonatomic, assign) BOOL open;
@end

@implementation CUIControlCenterController

+ (instancetype)sharedInstance {
    static CUIControlCenterController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CUIControlCenterController alloc] init];
    });
    return instance;
}

- (BOOL)moduleWanted {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.controlCenterEnabled;
}

- (void)activate {
    if (![self moduleWanted]) {
        CUICCTrace(@"activate: module disabled");
        return;
    }
    CUICCTrace(@"activate");
    [CUICCServiceBridge probeClassesIfNeeded];
    CUICCSwizzleMenuButton();
    CUICCSwizzleFrontDisplay();
    [self installGrabber];
}

- (void)deactivate {
    _grabber.hidden = YES;
    [_panelView closeAnimated:nil];
}

// The iOS 6 home screen (SBIconContentView) is a windowless tree driven by
// SB's own GSEvent routing — UIKit touches never reach it. Real UIWindows
// work (the volume pill proves it), so the strip and the panel live in our
// overlay window and are visibility-gated to the home screen only.
- (void)installGrabber {
    if (_grabber) {
        [self updateGrabberVisibility];
        return;
    }

    UIWindow *window = CUISharedOverlayWindow();
    if (!window) {
        CUICCTrace(@"installGrabber: overlay window nil, retrying");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self activate];
        });
        return;
    }

    _grabber = [CUIControlCenterGrabber attachToView:window];
    _grabber.triggerHeight = 300.0;
    _grabber.onGestureStart = ^{
        [self beginInteractiveOpen];
    };
    _grabber.onGestureProgress = ^(float progress) {
        [self updateInteractiveOpen:progress];
    };
    _grabber.onGestureFinish = ^(float progress, float velocity) {
        [self finishInteractiveOpen:progress velocity:velocity];
    };
    CUICCTrace([NSString stringWithFormat:@"grabber installed in window %@ frame=%@",
                NSStringFromClass([window class]), NSStringFromCGRect(_grabber.frame)]);
    [self updateGrabberVisibility];
}

// v1: strip visible only on the home screen (no frontmost app, not locked).
- (void)updateGrabberVisibility {
    if (!_grabber) return;

    BOOL locked = NO;
    id app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(isLocked)]) {
        locked = ((BOOL (*)(id, SEL))objc_msgSend)(app, @selector(isLocked));
    }

    BOOL appFrontmost = NO;
    if ([app respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
        id frontmost = [app performSelector:@selector(_accessibilityFrontMostApplication)];
        appFrontmost = (frontmost != nil);
    }

    BOOL visible = ![self moduleWanted] ? NO : (!locked && !appFrontmost);
    _grabber.hidden = !visible;
}

// Verified in iOS 6.1 SBIconController.h: - (id)contentView; the scroll view
// with icon pages is a subview of contentView, so we attach above contentView:
// to its superview when possible (guaranteed top of the home screen stack).

#pragma mark - Open / close

- (BOOL)isOpen {
    return _open;
}

- (void)ensurePanelInView:(UIView *)hostView {
    if (_panelView) return;
    _panelView = [[CUIControlCenterView alloc] initWithFrame:hostView.bounds];
    _panelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _panelView.hidden = YES;
    _panelView.onOutsideTap = ^{
        [self closeControlCenter];
    };
    _panelView.onGearTap = ^{
        [self closeAndOpenSettings];
    };
    [self wireControls];
    [hostView addSubview:_panelView];
}

- (void)wireControls {
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];

    _panelView.wifiItem.onToggle = ^{
        [bridge setWiFiEnabled:![bridge wiFiEnabled]];
        [self scheduleStateReRefresh];
    };
    _panelView.bluetoothItem.onToggle = ^{
        [bridge setBluetoothEnabled:![bridge bluetoothEnabled]];
        [self scheduleStateReRefresh];
    };
    _panelView.dndItem.onToggle = ^{
        [bridge setDoNotDisturbEnabled:![bridge doNotDisturbEnabled]];
        [self scheduleStateReRefresh];
    };
    _panelView.airplaneItem.onToggle = ^{
        [bridge setAirplaneMode:![bridge airplaneMode]];
        [self scheduleStateReRefresh];
    };

    _panelView.brightnessSlider.onValueCommit = ^(float value) {
        [bridge setBrightness:value];
    };
    _panelView.volumeSlider.onValueCommit = ^(float value) {
        [[CUIVolumeController sharedInstance] updateVolume:value];
    };

    _panelView.musicCard.onPrevious = ^{ [bridge mediaSkip:-1]; [self scheduleStateReRefresh]; };
    _panelView.musicCard.onNext = ^{ [bridge mediaSkip:1]; [self scheduleStateReRefresh]; };
    _panelView.musicCard.onPlayPause = ^{ [bridge mediaTogglePlayPause]; [self scheduleStateReRefresh]; };

    // Hardware volume buttons while CC is open: live-update our slider.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ccVolumeChanged:)
                                                 name:CUICCVolumeChangedNotification
                                               object:nil];
}

- (void)ccVolumeChanged:(NSNotification *)note {
    if (!_open) return;
    NSNumber *value = note.userInfo[@"value"];
    if ([value isKindOfClass:[NSNumber class]]) {
        _panelView.volumeSlider.value = [value floatValue];
    }
}

- (void)refreshStates {
    if (!_panelView) return;
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];

    [_panelView.bluetoothItem setActive:[bridge bluetoothEnabled] animated:NO];
    [_panelView.dndItem setActive:[bridge doNotDisturbEnabled] animated:NO];
    [_panelView.airplaneItem setActive:[bridge airplaneMode] animated:NO];
    // Radio state drives the Wi-Fi glow: SBWiFiManager -wiFiEnabled tracks the
    // Settings switch and lags/ignores programmatic toggles (probe), while
    // -isPowered reflects actual radio power.
    [_panelView.wifiItem setActive:[bridge wiFiPowered] animated:NO];

    _panelView.volumeSlider.value = [[CUIVolumeController sharedInstance] readSystemVolume];
    _panelView.brightnessSlider.value = [bridge brightness];

    _panelView.mediaTitle = [bridge mediaTitle];
    _panelView.mediaArtist = [bridge mediaArtist];
    _panelView.musicCard.playing = [bridge mediaPlaying];
}

// Radio state (Bluetooth power, airplane switch-over) and media state apply
// asynchronously — a single read right after a toggle or exactly at panel
// open can be stale, which showed up as wrong glow on iOS 6. Re-read shortly
// after; consecutive identical re-reads are no-ops for the items.
- (void)scheduleStateReRefresh {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self refreshStates];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self refreshStates];
    });
}

- (void)beginInteractiveOpen {
    if (![self moduleWanted]) return;
    UIWindow *window = CUISharedOverlayWindow();
    if (!window) return;
    [self ensurePanelInView:window];
    [self refreshStates];
    [_panelView prepareForOpen];
}

- (void)updateInteractiveOpen:(float)progress {
    if (!_panelView || _panelView.hidden) return;
    [_panelView setOpenProgress:progress];
}

- (void)finishInteractiveOpen:(float)progress velocity:(float)velocity {
    if (!_panelView || _panelView.hidden) return;
    BOOL shouldOpen = (progress > 0.35) || (velocity > 500.0);
    if (shouldOpen) {
        [self openControlCenter];
    } else {
        [self closeControlCenter];
    }
}

- (void)openControlCenter {
    if (_open) return;
    _open = YES;
    g_ccIsOpen = YES;
    [self refreshStates];
    [self scheduleStateReRefresh]; // async radio/media state convergence
    [_panelView openAnimated:nil];
}

- (void)closeControlCenter {
    if (!_open && (_panelView == nil || _panelView.hidden)) return;
    _open = NO;
    g_ccIsOpen = NO;
    [_panelView closeAnimated:nil];
}

- (void)closeAndOpenSettings {
    BOOL wasOpen = _open;
    [self closeControlCenter];
    if (wasOpen) {
        [self performSelector:@selector(openSettings)
                   withObject:nil
                   afterDelay:0.45];
    } else {
        [self openSettings];
    }
}

- (void)openSettings {
    // Verified in iOS 6.1 & 8.0 SpringBoard.h: - (void)applicationOpenURL:(id)arg1;
    id app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(applicationOpenURL:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(app, @selector(applicationOpenURL:),
                                              [NSURL URLWithString:@"prefs://"]);
    } else {
        [app openURL:[NSURL URLWithString:@"prefs://"]];
    }
}

@end