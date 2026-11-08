#import "CUIControlCenterController.h"
#import "CUIControlCenterView.h"
#import "CUIControlCenterGrabber.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
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
    CUICCSwizzleMenuButton();
    [self installGrabber];
}

- (void)deactivate {
    [_grabber removeFromSuperview];
    _grabber = nil;
    [_panelView closeAnimated:nil];
}

- (void)installGrabber {
    if (_grabber) return;

    UIView *hostView = [self homeScreenHostView];
    if (!hostView) {
        CUICCTrace(@"installGrabber: host nil, retrying");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self activate];
        });
        return;
    }
    CUICCTrace([NSString stringWithFormat:@"installGrabber: host=%@ bounds=%@",
                NSStringFromClass([hostView class]), NSStringFromCGRect(hostView.bounds)]);

    _grabber = [CUIControlCenterGrabber attachToView:hostView];
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
    NSLog(@"[LegacyUI] CC grabber installed on %@", NSStringFromClass([hostView class]));
}

// Verified in iOS 6.1 SBIconController.h: - (id)contentView; the scroll view
// with icon pages is a subview of contentView, so we attach above contentView:
// to its superview when possible (guaranteed top of the home screen stack).
- (UIView *)homeScreenHostView {
    Class controllerClass = NSClassFromString(@"SBIconController");
    if (!controllerClass) {
        CUICCTrace(@"host: SBIconController class nil");
        return nil;
    }
    if (!class_getInstanceMethod(controllerClass, @selector(sharedInstance))) {
        CUICCTrace(@"host: sharedInstance missing");
        return nil;
    }
    id shared = [controllerClass performSelector:@selector(sharedInstance)];
    if (!shared) {
        CUICCTrace(@"host: sharedInstance nil");
        return nil;
    }
    if (![shared respondsToSelector:@selector(contentView)]) {
        CUICCTrace(@"host: contentView missing");
        return nil;
    }
    UIView *contentView = [shared performSelector:@selector(contentView)];
    if (![contentView isKindOfClass:[UIView class]]) {
        CUICCTrace(@"host: contentView not a view");
        return nil;
    }

    if (contentView.superview) {
        return contentView.superview;
    }
    return contentView;
}

#pragma mark - Open / close

- (BOOL)isOpen {
    return _open;
}

- (void)ensurePanelInView:(UIView *)hostView {
    if (_panelView) return;
    CGRect screenFrame = [hostView convertRect:[UIScreen mainScreen].bounds fromView:nil];
    _panelView = [[CUIControlCenterView alloc] initWithFrame:screenFrame];
    _panelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _panelView.hidden = YES;
    _panelView.onOutsideTap = ^{
        [self closeControlCenter];
    };
    _panelView.onGearTap = ^{
        [self openSettings];
    };
    [hostView addSubview:_panelView];
}

- (void)beginInteractiveOpen {
    if (![self moduleWanted]) return;
    UIView *host = [self homeScreenHostView];
    if (!host) return;
    [self ensurePanelInView:host];
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
    _open = YES;
    [_panelView openAnimated:nil];
}

- (void)closeControlCenter {
    if (!_open && (_panelView == nil || _panelView.hidden)) return;
    _open = NO;
    [_panelView closeAnimated:nil];
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