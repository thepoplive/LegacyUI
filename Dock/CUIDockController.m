#import "CUIDockController.h"
#import "CUIDockView.h"
#import "../Core/CUIConfiguration.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char kDockGlassAssociationKey;
static dispatch_once_t g_swizzleOnce;
static BOOL g_swizzleInstalled = NO;
static IMP g_origDockLayout = NULL;

static BOOL LUIDockWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.dockEnabled && config.liquidGlassEnabled;
}

static void LUIDockUpdateGlass(UIView *dockView) {
    CUIDockView *glass = objc_getAssociatedObject(dockView, &kDockGlassAssociationKey);

    if (!LUIDockWanted()) {
        if (glass) {
            [glass removeFromSuperview];
            objc_setAssociatedObject(dockView, &kDockGlassAssociationKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    if (!glass) {
        glass = [[CUIDockView alloc] initWithFrame:CGRectInset(dockView.bounds, 5, 3)];

        UIView *iconList = nil;
        for (UIView *sub in dockView.subviews) {
            if ([NSStringFromClass([sub class]) rangeOfString:@"IconList"].location != NSNotFound) {
                iconList = sub;
                break;
            }
        }
        if (iconList) {
            [dockView insertSubview:glass belowSubview:iconList];
        } else if (dockView.subviews.count > 1) {
            [dockView insertSubview:glass atIndex:1];
        } else {
            [dockView insertSubview:glass atIndex:0];
        }

        objc_setAssociatedObject(dockView, &kDockGlassAssociationKey, glass,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[LegacyUI] Dock glass installed on %@",
              NSStringFromClass([dockView class]));
    }

    glass.frame = CGRectInset(dockView.bounds, 5, 3);
}

static void LUIDockLayoutSwizzled(id self, SEL _cmd) {
    if (self == nil) return;
    @try {
        if (g_origDockLayout) {
            ((void (*)(id, SEL))g_origDockLayout)(self, _cmd);
        }
        LUIDockUpdateGlass((UIView *)self);
    } @catch (NSException *exception) {
        NSLog(@"[LegacyUI] dock layout exception: %@", exception);
    }
}

@implementation CUIDockController

+ (instancetype)sharedInstance {
    static CUIDockController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CUIDockController alloc] init];
    });
    return instance;
}

- (void)installSwizzle {
    dispatch_once(&g_swizzleOnce, ^{
        Class dockClass = NSClassFromString(@"SBDockView");
        if (!dockClass) {
            NSLog(@"[LegacyUI] SBDockView not found — dock module disabled");
            return;
        }

        Method method = class_getInstanceMethod(dockClass, @selector(layoutSubviews));
        if (!method) {
            NSLog(@"[LegacyUI] SBDockView layoutSubviews not found");
            return;
        }

        if (class_addMethod(dockClass, @selector(layoutSubviews),
                            (IMP)LUIDockLayoutSwizzled, method_getTypeEncoding(method))) {
            // SBDockView did not override layoutSubviews; call the inherited one.
            g_origDockLayout = method_getImplementation(method);
        } else {
            g_origDockLayout = method_setImplementation(method, (IMP)LUIDockLayoutSwizzled);
        }

        g_swizzleInstalled = YES;
        NSLog(@"[LegacyUI] SBDockView layoutSubviews swizzled");
    });
}

- (void)activate {
    [self installSwizzle];
    [self relayoutDocks];
}

- (void)deactivate {
    [self relayoutDocks];
}

- (void)reloadDock {
    [self relayoutDocks];
}

- (void)relayoutDocks {
    if (!g_swizzleInstalled) return;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        [self relayoutInView:window];
    }
}

- (void)relayoutInView:(UIView *)view {
    if ([view isKindOfClass:NSClassFromString(@"SBDockView")]) {
        [view setNeedsLayout];
        return;
    }
    for (UIView *sub in view.subviews) {
        [self relayoutInView:sub];
    }
}

@end