#import "CUIControlCenterController.h"
#import "CUIControlCenterView.h"
#import "CUIControlCenterGrabber.h"
#import "CUICCServiceBridge.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIOverlayWindow.h"
#import "../Core/CUIGlobalState.h"
#import "../VolumeHUD/CUIVolumeController.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <stdlib.h>

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

// The native CC lives in an SBSecureWindow ABOVE our overlay window; the
// 0.6.2 attempt to swallow beginPresentationWithTouchLocation: left the
// system gesture half-engaged and the empty CC window ate ALL touches.
// Robust approach instead: let the native CC present/dismiss NORMALLY
// (every system state machine stays intact), make it invisible from its
// own content-container layout pass (proven-safe write class from the
// 0.4.x builds), and mirror open/close onto our MD3 sheet which floats
// higher (windowLevel raised in CUIOverlayWindow).
static IMP g_origNativeCCLayout = NULL;

static void CUICCNativeCCLayoutSwizzled(id self, SEL _cmd) {
    if (g_origNativeCCLayout) {
        ((void (*)(id, SEL))g_origNativeCCLayout)(self, _cmd);
    }
    UIView *container = (UIView *)self;

    // Native sheet: fully transparent, its machinery keeps running.
    if (container.alpha > 0.01) container.alpha = 0.0;

    // The native dimming wash lives on the parent container — hide it too,
    // our sheet brings its own dim overlay.
    UIView *parent = container.superview;
    Ivar darkIvar = class_getInstanceVariable([parent class], "_darkeningView");
    if (darkIvar) {
        id darkening = object_getIvar(parent, darkIvar);
        if ([darkening isKindOfClass:[UIView class]] && !((UIView *)darkening).hidden) {
            ((UIView *)darkening).hidden = YES;
        }
    }

    // Our MD3 sheet mirrors the native presentation.
    if ([[CUIControlCenterController sharedInstance] isOpen]) return;
    [[CUIControlCenterController sharedInstance] openControlCenter];
}

static IMP g_origNativeCCDismiss = NULL;
static BOOL g_nativeDrivingClose = NO;

static void CUICCNativeCCDismissSwizzled(id self, SEL _cmd) {
    if (g_origNativeCCDismiss) {
        ((void (*)(id, SEL))g_origNativeCCDismiss)(self, _cmd);
    }
    g_nativeDrivingClose = YES;
    [[CUIControlCenterController sharedInstance] closeControlCenter];
    g_nativeDrivingClose = NO;
}

static void CUICCInstallNativeCCHide() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class containerClass = NSClassFromString(@"SBControlCenterContentContainerView");
        if (!containerClass) {
            CUICCTrace(@"SBControlCenterContentContainerView unavailable");
            return;
        }
        Method layout = class_getInstanceMethod(containerClass, @selector(layoutSubviews));
        if (layout) {
            if (class_addMethod(containerClass, @selector(layoutSubviews),
                                (IMP)CUICCNativeCCLayoutSwizzled,
                                method_getTypeEncoding(layout))) {
                g_origNativeCCLayout = method_getImplementation(layout);
            } else {
                g_origNativeCCLayout = method_setImplementation(layout,
                    (IMP)CUICCNativeCCLayoutSwizzled);
            }
            CUICCTrace(@"native CC layout hook installed");
        }
        Method dismiss = class_getInstanceMethod(containerClass,
                                                  @selector(controlCenterDidDismiss));
        if (dismiss) {
            if (class_addMethod(containerClass, @selector(controlCenterDidDismiss),
                                (IMP)CUICCNativeCCDismissSwizzled,
                                method_getTypeEncoding(dismiss))) {
                g_origNativeCCDismiss = method_getImplementation(dismiss);
            } else {
                g_origNativeCCDismiss = method_setImplementation(dismiss,
                    (IMP)CUICCNativeCCDismissSwizzled);
            }
            CUICCTrace(@"native CC dismiss hook installed");
        }
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
@property (nonatomic, strong) NSTimer *mediaTimer;
@property (nonatomic, assign) BOOL demoVPN;
@property (nonatomic, assign) BOOL demoRotation;
@property (nonatomic, assign) BOOL demoTorch;
@property (nonatomic, assign) BOOL demoRecording;
@property (nonatomic, copy) NSString *deviceIP;
@property (nonatomic, assign) float netDown;
@property (nonatomic, assign) float netUp;
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
    if (!CUIIsiOS6OrEarlier()) {
        // iOS 8 (4S, 8.4.1): the MD3 sheet REPLACES the native Control
        // Center — the system's own swipe-up gesture routes through
        // SBControlCenterController -presentAnimated:, which we swallow and
        // answer with our overlay panel instead (works in apps too, the
        // overlay window floats above everything).
        [CUICCServiceBridge probeClassesIfNeeded]; // 8.4.1 ground truth dump
        CUICCInstallNativeCCHide();
        CUICCSwizzleMenuButton();
        CUICCTrace(@"activate: MD3 sheet (iOS 8)");
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
    _panelView.onPowerTap = ^{
        [self powerTap];
    };
    [self wireControls];
    [hostView addSubview:_panelView];
}

- (void)wireControls {
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];
    __weak CUIControlCenterController *weakSelf = self;

    _panelView.onTileTap = ^(NSString *key) {
        [weakSelf handleTileTap:key];
    };

    _panelView.onBrightnessCommit = ^(float value) {
        [bridge setBrightness:value];
    };
    _panelView.onVolumeCommit = ^(float value) {
        [[CUIVolumeController sharedInstance] updateVolume:value];
    };

    _panelView.onPlayPause = ^{ [weakSelf mediaTogglePlayPause]; };
    _panelView.onPrevTrack = ^{ [bridge mediaSkip:-1]; [weakSelf refreshMedia]; };
    _panelView.onNextTrack = ^{ [bridge mediaSkip:1]; [weakSelf refreshMedia]; };
    _panelView.onFavouriteToggle = ^(BOOL favourite) {
        [weakSelf showToast:favourite ? @"Добавлено в избранное" : @"Убрано из избранного"];
    };
    _panelView.onOpenMusic = ^{
        [weakSelf closeControlCenter];
        NSString *musicId = CUIIsiOS6OrEarlier()
            ? @"com.apple.mobileipod" : @"com.apple.Music";
        [weakSelf openApplication:musicId fallbackURL:@"music:" toast:@"Музыка"];
    };
    _panelView.onSeek = ^(float progress) {
        [bridge mediaSetTrackProgress:progress];
        [weakSelf refreshMedia];
    };

    // Hardware volume buttons while CC is open: live-update our slider.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(ccVolumeChanged:)
                                                 name:CUICCVolumeChangedNotification
                                               object:nil];

    // Light 0.5s pulse: media position + demo network speeds (per concept).
    _mediaTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
                                                 selector:@selector(pulseTick)
                                                 userInfo:nil repeats:YES];
}

- (void)handleTileTap:(NSString *)key {
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];

    if ([key isEqualToString:@"wifi"]) {
        BOOL on = ![bridge wiFiEnabled];
        [bridge setWiFiEnabled:on];
        [self refreshStates];
        [self showToast:on ? @"Wi-Fi: вкл" : @"Wi-Fi: выкл"];
        return;
    }
    if ([key isEqualToString:@"bt"]) {
        BOOL on = ![bridge bluetoothEnabled];
        [bridge setBluetoothEnabled:on];
        [self refreshStates];
        [self showToast:on ? @"Bluetooth: вкл" : @"Bluetooth: выкл"];
        return;
    }
    if ([key isEqualToString:@"air"]) {
        BOOL on = ![bridge airplaneMode];
        [bridge setAirplaneMode:on];
        [self refreshStates];
        [self scheduleStateReRefresh];
        [self showToast:on ? @"Авиарежим: вкл" : @"Авиарежим: выкл"];
        return;
    }
    if ([key isEqualToString:@"dnd"]) {
        BOOL on = ![bridge doNotDisturbEnabled];
        [bridge setDoNotDisturbEnabled:on];
        [self refreshStates];
        [self showToast:on ? @"Не беспокоить: вкл" : @"Не беспокоить: выкл"];
        return;
    }
    if ([key isEqualToString:@"vpn"]) {
        _demoVPN = !_demoVPN;
        [_panelView setTile:@"vpn" active:_demoVPN animated:YES];
        [self showToast:_demoVPN ? @"VPN: вкл" : @"VPN: выкл"];
        return;
    }
    if ([key isEqualToString:@"rot"]) {
        BOOL locked = ![bridge orientationLocked];
        [bridge setOrientationLocked:locked];
        [self refreshStates];
        [self showToast:locked ? @"Поворот: заблокирован" : @"Поворот: разблокирован"];
        return;
    }
    if ([key isEqualToString:@"torch"]) {
        BOOL on = ![bridge torchEnabled];
        [bridge setTorchEnabled:on];
        [self refreshStates];
        [self showToast:on ? @"Фонарик: вкл" : @"Фонарик: выкл"];
        return;
    }
    if ([key isEqualToString:@"rec"]) {
        _demoRecording = !_demoRecording;
        [_panelView setTile:@"rec" active:_demoRecording animated:YES];
        [self showToast:_demoRecording ? @"Запись экрана: запись" : @"Запись экрана: остановлена"];
        return;
    }
    if ([key isEqualToString:@"timer"]) {
        [self closeControlCenter];
        [self openApplication:@"com.apple.mobiletimer" fallbackURL:nil toast:@"Таймер"];
        return;
    }
    if ([key isEqualToString:@"calc"]) {
        [self closeControlCenter];
        [self openApplication:@"com.apple.calculator" fallbackURL:nil toast:@"Калькулятор"];
        return;
    }
    if ([key isEqualToString:@"cam"]) {
        [self closeControlCenter];
        [self openApplication:@"com.apple.camera" fallbackURL:nil toast:@"Камера"];
        return;
    }
}

- (void)powerTap {
    // Concept: Питание menu. Phase 1: respring directly.
    [self closeControlCenter];
    [self showToast:@"Респринг…"];
    [self performSelector:@selector(respringDevice) withObject:nil afterDelay:0.5];
}

- (void)respringDevice {
    // killall SpringBoard from within SpringBoard: launchd respawns it.
    system("killall -9 SpringBoard");
}

- (void)openApplication:(NSString *)identifier
            fallbackURL:(NSString *)url
                  toast:(NSString *)toast {
    // iOS 6: launch via SBApplicationController/SBUIController (runtime-checked).
    Class controllerClass = NSClassFromString(@"SBApplicationController");
    id appController = controllerClass
        ? [controllerClass performSelector:@selector(sharedInstance)] : nil;
    id app = nil;
    if (appController && [appController respondsToSelector:@selector(applicationWithDisplayIdentifier:)]) {
        app = [appController performSelector:@selector(applicationWithDisplayIdentifier:)
                                  withObject:identifier];
    }
    if (app) {
        Class uiControllerClass = NSClassFromString(@"SBUIController");
        id ui = uiControllerClass ? [uiControllerClass performSelector:@selector(sharedInstance)] : nil;
        if (ui && [ui respondsToSelector:@selector(activateApplication:)]) {
            ((void (*)(id, SEL, id))objc_msgSend)(ui, @selector(activateApplication:), app);
            return;
        }
    }
    if (url) {
        id springBoard = [UIApplication sharedApplication];
        if ([springBoard respondsToSelector:@selector(openURL:)]) {
            [springBoard performSelector:@selector(openURL:)
                               withObject:[NSURL URLWithString:url]];
        }
        return;
    }

    // iOS 8: SBSLaunchApplicationWithIdentifier (SpringBoardServices).
    static void (*CUILaunchFn)(const char *, BOOL) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CUILaunchFn = (void (*)(const char *, BOOL))dlsym(RTLD_DEFAULT,
            "SBSLaunchApplicationWithIdentifier");
    });
    if (CUILaunchFn) {
        CUILaunchFn([identifier UTF8String], NO);
    } else {
        [self showToast:toast];
    }
}

- (void)mediaTogglePlayPause {
    [[CUICCServiceBridge sharedBridge] mediaTogglePlayPause];
    [self refreshMedia];
}

- (void)showToast:(NSString *)text {
    [_panelView showToast:text];
}

// Demo network speeds per the concept (random walk), real IP via getifaddrs.
- (void)pulseTick {
    [self refreshMedia];
    [self refreshNetwork];

    if (!_open) return;
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];
    _netDown += (arc4random_uniform(100) / 100.0 - 0.5) * 2.4;
    if (_netDown < 0.3) _netDown = 0.3;
    _netUp += (arc4random_uniform(100) / 100.0 - 0.5) * 0.8;
    if (_netUp < 0.2) _netUp = 0.2;
    BOOL airplane = [bridge airplaneMode];
    BOOL wifi = !airplane && [bridge wiFiEnabled];
    [_panelView setNetworkIP:wifi ? _deviceIP : @"—"
                    download:airplane ? nil : [NSString stringWithFormat:@"%.1f",
                                                    wifi ? _netDown : MIN(_netDown, 3.0)]
                      upload:airplane ? nil : [NSString stringWithFormat:@"%.1f",
                                                  wifi ? _netUp : MIN(_netUp, 1.0)]];
}

- (void)refreshNetwork {
    if (_deviceIP) return;
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        for (struct ifaddrs *ifa = interfaces; ifa; ifa = ifa->ifa_next) {
            if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_INET) {
                NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];
                if ([name hasPrefix:@"en"]) {
                    char addrBuf[INET_ADDRSTRLEN];
                    struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
                    if (inet_ntop(AF_INET, &sin->sin_addr, addrBuf, sizeof(addrBuf))) {
                        _deviceIP = [NSString stringWithUTF8String:addrBuf];
                        break;
                    }
                }
            }
        }
        freeifaddrs(interfaces);
    }
    if (!_deviceIP) _deviceIP = @"—";
}

- (void)ccVolumeChanged:(NSNotification *)note {
    if (!_open) return;
    NSNumber *value = note.userInfo[@"value"];
    if ([value isKindOfClass:[NSNumber class]]) {
        _panelView.volumeValue = [value floatValue];
    }
}

- (void)refreshStates {
    if (!_panelView) return;
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];

    [_panelView setTile:@"wifi" active:[bridge wiFiEnabled] animated:NO];
    [_panelView setTile:@"bt" active:[bridge bluetoothEnabled] animated:NO];
    [_panelView setTile:@"air" active:[bridge airplaneMode] animated:NO];
    [_panelView setTile:@"dnd" active:[bridge doNotDisturbEnabled] animated:NO];
    [_panelView setTile:@"vpn" active:_demoVPN animated:NO];
    [_panelView setTile:@"rot" active:[bridge orientationLocked] animated:NO];
    [_panelView setTile:@"torch" active:[bridge torchEnabled] animated:NO];
    [_panelView setTile:@"rec" active:_demoRecording animated:NO];

    _panelView.volumeValue = [[CUIVolumeController sharedInstance] readSystemVolume];
    _panelView.brightnessValue = [bridge brightness];

    [self refreshMedia];
}

- (void)refreshMedia {
    if (!_panelView) return;
    CUICCServiceBridge *bridge = [CUICCServiceBridge sharedBridge];

    NSString *title = [bridge mediaTitle];
    BOOL hasTrack = (title.length > 0);
    _panelView.mediaHasTrack = hasTrack;
    _panelView.mediaTitle = hasTrack ? title : @"Ничего не играет";
    _panelView.mediaArtist = [bridge mediaArtist];
    _panelView.mediaPlaying = [bridge mediaPlaying];

    float progress = [bridge mediaTrackProgress];
    _panelView.mediaProgress = progress;
    _panelView.mediaElapsed = [bridge mediaTrackElapsedString];
    _panelView.mediaDuration = [bridge mediaTrackDurationString];
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
    UIWindow *window = CUISharedOverlayWindow();
    if (window) [self ensurePanelInView:window];
    if (!_panelView) {
        CUICCTrace(@"openControlCenter: no host window yet");
        return;
    }
    _open = YES;
    g_ccIsOpen = YES;
    [_panelView prepareForOpen]; // unhide: this path is called cold on iOS 8
    [self refreshStates];
    [self scheduleStateReRefresh]; // async radio/media state convergence
    [_panelView openAnimated:nil];
}

- (void)closeControlCenter {
    if (!_open && (_panelView == nil || _panelView.hidden)) return;
    _open = NO;
    g_ccIsOpen = NO;
    [_panelView closeAnimated:nil];

    // If the USER closed our sheet, the invisible native CC must close too
    // (verified selector from the 8.0 dump: -dismissAnimated:).
    if (!g_nativeDrivingClose) {
        Class ccClass = NSClassFromString(@"SBControlCenterController");
        id cc = ccClass ? [ccClass performSelector:@selector(sharedInstance)] : nil;
        if (cc && [cc respondsToSelector:@selector(dismissAnimated:)]) {
            [cc performSelector:@selector(dismissAnimated:) withObject:@YES];
        }
    }
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

#pragma mark Screen lock

- (void)closeAndLock {
    [self closeControlCenter];
    [self performSelector:@selector(lockDeviceNow) withObject:nil afterDelay:0.35];
}

// Verifies against the 6.1 dumps (SBUIController -lockFromSource:) and falls
// back to the GraphicsServices GSEvent lock the power button itself feeds.
- (void)lockDeviceNow {
    Class uiControllerClass = NSClassFromString(@"SBUIController");
    id uiController = uiControllerClass
        ? [uiControllerClass performSelector:@selector(sharedInstance)]
        : nil;
    if ([uiController respondsToSelector:@selector(lockFromSource:)]) {
        ((void (*)(id, SEL, int))objc_msgSend)(uiController,
                                               @selector(lockFromSource:), 0);
        return;
    }

    static void (*CUILockDeviceFn)(void) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        CUILockDeviceFn = (void (*)(void))dlsym(RTLD_DEFAULT, "GSEventLockDevice");
    });
    if (CUILockDeviceFn) CUILockDeviceFn();
}

@end