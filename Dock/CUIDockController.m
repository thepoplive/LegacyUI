#import "CUIDockController.h"
#import "CUIDockView.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import <objc/runtime.h>
#import <objc/message.h>

static char kDockGlassAssociationKey;
static BOOL g_swizzleInstalled = NO;

static IMP g_origDockLayout = NULL;         // iOS 8: SBDockView layoutSubviews
static IMP g_origDockContainerView = NULL;  // iOS 6: SBIconController dockContainerView
static IMP g_origListLayout = NULL;         // iOS 6: SBDockIconListView layoutSubviews

static dispatch_once_t g_ios8Once;
static dispatch_once_t g_ios6Once;

static BOOL LUIDockWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.dockEnabled && config.liquidGlassEnabled;
}

#pragma mark - Shared view helpers

// Verified in iOS 8.0 SBDockView.h (class-dump): ivars exist on the class,
// so object_getIvar never throws (unlike KVC on a missing key).
static UIView *LUIDockIvarView(id view, NSString *ivarName) {
    Ivar ivar = class_getInstanceVariable([view class], [ivarName UTF8String]);
    if (!ivar) return nil;
    id value = object_getIvar(view, ivar);
    if ([value isKindOfClass:[UIView class]]) return value;
    return nil;
}

static void LUIDockSetBackgroundsHidden(UIView *hostView, BOOL hidden, BOOL useIvars) {
    if (!hidden) {
        if (useIvars) {
            NSArray *backgroundIvars = @[ @"_backgroundView", @"_backgroundImageView", @"_accessibilityBackgroundView" ];
            for (NSString *ivarName in backgroundIvars) {
                UIView *view = LUIDockIvarView(hostView, ivarName);
                if (view) view.hidden = NO;
            }
            return;
        }
    }
    // iOS 6 structural path only hides; restore is done via respring-needing
    // refresh (the container is re-created by SBIconController on relayout).
}

static void LUIDockSetLabelsHiddenRecursive(UIView *view, BOOL hidden) {
    for (UIView *sub in view.subviews) {
        if ([NSStringFromClass([sub class]) rangeOfString:@"IconLabel"].location != NSNotFound) {
            sub.hidden = hidden;
        }
        LUIDockSetLabelsHiddenRecursive(sub, hidden);
    }
}

static UIView *LUIDockFindIconList(UIView *hostView) {
    for (UIView *sub in hostView.subviews) {
        if ([NSStringFromClass([sub class]) rangeOfString:@"IconList"].location != NSNotFound) {
            return sub;
        }
    }
    return nil;
}

// Debug helper: /var/mobile/.legacyui_dump -> write dock hierarchy for on-device diagnosis.
static void LUIDumpView(UIView *view, NSMutableString *out, int depth) {
    for (int i = 0; i < depth; i++) [out appendString:@"  "];
    [out appendFormat:@"%@ frame=%@ alpha=%.2f hidden=%d\n",
        NSStringFromClass([view class]),
        NSStringFromCGRect(view.frame),
        view.alpha, view.hidden];
    for (UIView *sub in view.subviews) {
        LUIDumpView(sub, out, depth + 1);
    }
}

static void LUIDockMaybeDumpHierarchy(UIView *container) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/.legacyui_dump"]) return;
    NSMutableString *dump = [NSMutableString string];
    [dump appendString:@"=== LegacyUI dock hierarchy ===\n"];
    LUIDumpView(container, dump, 0);
    [dump writeToFile:@"/var/mobile/legacyui_dump.txt"
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/.legacyui_dump" error:NULL];
    NSLog(@"[LegacyUI] hierarchy dumped");
}

// iOS 6: the dock background comes from +backgroundImageForOrientation: and is
// drawn via layer contents of the container / icon list (verified header map),
// so hiding UIViews is not enough — clear the drawable layers as well.
static void LUIDockClearDrawableLayers(UIView *view) {
    view.layer.contents = nil;
    view.backgroundColor = [UIColor clearColor];
}

// Union of the actual icon frames inside the dock icon list (container coords).
static CGRect LUIIOS6IconUnionFrame(UIView *iconList) {
    CGRect unionRect = CGRectNull;
    for (UIView *sub in iconList.subviews) {
        if ([NSStringFromClass([sub class]) rangeOfString:@"IconView"].location == NSNotFound) {
            continue;
        }
        if (CGRectIsNull(unionRect)) {
            unionRect = sub.frame;
        } else {
            unionRect = CGRectUnion(unionRect, sub.frame);
        }
    }
    if (CGRectIsNull(unionRect) || CGRectIsEmpty(unionRect)) return CGRectNull;
    return CGRectOffset(unionRect, iconList.frame.origin.x, iconList.frame.origin.y);
}

static void LUIDockUpdateGlassInView(UIView *hostView, BOOL hideIvarBackgrounds) {
    CUIDockView *glass = objc_getAssociatedObject(hostView, &kDockGlassAssociationKey);

    if (!LUIDockWanted()) {
        if (glass) {
            [glass removeFromSuperview];
            objc_setAssociatedObject(hostView, &kDockGlassAssociationKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            LUIDockSetLabelsHiddenRecursive(hostView, NO);
            if (hideIvarBackgrounds) {
                LUIDockSetBackgroundsHidden(hostView, NO, YES);
            }
        }
        return;
    }

    LUIDockMaybeDumpHierarchy(hostView);

    UIView *iconList = LUIDockFindIconList(hostView);

    CGRect glassFrame;
    if (hideIvarBackgrounds) {
        // iOS 8 path: hide via verified ivars.
        NSArray *backgroundIvars = @[ @"_backgroundView", @"_backgroundImageView", @"_accessibilityBackgroundView" ];
        for (NSString *ivarName in backgroundIvars) {
            UIView *view = LUIDockIvarView(hostView, ivarName);
            if (view) view.hidden = YES;
        }
        if (iconList && iconList.superview == hostView) {
            iconList.center = CGPointMake(hostView.bounds.size.width / 2.0,
                                          hostView.bounds.size.height / 2.0);
        }
        glassFrame = CGRectInset(hostView.bounds, 5, 3);
    } else {
        // iOS 6 path: the container is dedicated to the dock — hide everything
        // that is not the icon list and not our glass, and clear the native
        // dock background which is drawn via layer contents.
        for (UIView *sub in hostView.subviews) {
            if (sub == glass || sub == iconList) continue;
            sub.hidden = YES;
        }
        LUIDockClearDrawableLayers(hostView);
        if (iconList) {
            LUIDockClearDrawableLayers(iconList);
            // Extra safety: hide any image views nested inside the icon list
            // (icons themselves are SBIconView, not UIImageView).
            for (UIView *sub in iconList.subviews) {
                if ([sub isKindOfClass:[UIImageView class]]) {
                    sub.hidden = YES;
                }
            }
        }

        if (iconList) {
            CGRect unionRect = LUIIOS6IconUnionFrame(iconList);
            if (!CGRectIsNull(unionRect)) {
                // SBIconView frames include the (hidden) label zone at the
                // bottom — trim it so the glass hugs the icon graphics only.
                CGFloat labelTrim = MIN(16.0, unionRect.size.height * 0.25);
                unionRect.size.height -= labelTrim;

                // Classic dock: thin glass tightly around the icon area,
                // slightly raised from the bottom edge of the dock.
                CGFloat padX = 8.0, padY = 6.0;
                glassFrame = CGRectMake(unionRect.origin.x - padX,
                                         unionRect.origin.y - padY,
                                         unionRect.size.width + padX * 2.0,
                                         unionRect.size.height + padY * 2.0);

                // Never exceed the native dock container bounds.
                CGRect dockBounds = CGRectInset(hostView.bounds, 2.0, 0.0);
                CGRect clamped = CGRectIntersection(glassFrame, dockBounds);
                if (!CGRectIsEmpty(clamped)) glassFrame = clamped;
            } else {
                glassFrame = CGRectInset(iconList.frame, -6, -6);
            }
        } else {
            glassFrame = CGRectInset(hostView.bounds, 5, 3);
        }
    }

    LUIDockSetLabelsHiddenRecursive(hostView, YES);

    if (!glass) {
        glass = [[CUIDockView alloc] initWithFrame:glassFrame];

        if (iconList) {
            [hostView insertSubview:glass belowSubview:iconList];
        } else if (hostView.subviews.count > 1) {
            [hostView insertSubview:glass atIndex:1];
        } else {
            [hostView insertSubview:glass atIndex:0];
        }

        objc_setAssociatedObject(hostView, &kDockGlassAssociationKey, glass,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[LegacyUI] Dock glass installed (%@)", NSStringFromClass([hostView class]));
    }

    glass.frame = glassFrame;
}

#pragma mark - iOS 8: SBDockView layoutSubviews

static void LUIDockLayoutSwizzled(id self, SEL _cmd) {
    if (self == nil) return;
    if (g_origDockLayout) {
        ((void (*)(id, SEL))g_origDockLayout)(self, _cmd);
    }
    LUIDockUpdateGlassInView((UIView *)self, YES);
}

static void LUIInstallIOS8Dock() {
    dispatch_once(&g_ios8Once, ^{
        Class dockClass = NSClassFromString(@"SBDockView");
        if (!dockClass || !class_getInstanceMethod(dockClass, @selector(layoutSubviews))) {
            NSLog(@"[LegacyUI] SBDockView layoutSubviews unavailable — iOS 8 dock disabled");
            return;
        }

        Method method = class_getInstanceMethod(dockClass, @selector(layoutSubviews));
        if (class_addMethod(dockClass, @selector(layoutSubviews),
                            (IMP)LUIDockLayoutSwizzled, method_getTypeEncoding(method))) {
            g_origDockLayout = method_getImplementation(method);
        } else {
            g_origDockLayout = method_setImplementation(method, (IMP)LUIDockLayoutSwizzled);
        }

        g_swizzleInstalled = YES;
        NSLog(@"[LegacyUI] SBDockView layoutSubviews swizzled");
    });
}

#pragma mark - iOS 6: SBIconController dockContainerView + SBDockIconListView layoutSubviews

static void LUIIOS6UpdateContainer(UIView *container) {
    if (![container isKindOfClass:[UIView class]]) return;
    LUIDockUpdateGlassInView(container, NO);
}

static __weak UIView *g_ios6KnownContainer = NULL;

static id LUIIOS6DockContainerSwizzled(id self, SEL _cmd) {
    id container = nil;
    if (g_origDockContainerView) {
        container = ((id (*)(id, SEL))g_origDockContainerView)(self, _cmd);
    }
    g_ios6KnownContainer = (UIView *)container;
    LUIIOS6UpdateContainer((UIView *)container);
    return container;
}

static void LUIIOS6ListLayoutSwizzled(id self, SEL _cmd) {
    if (g_origListLayout) {
        ((void (*)(id, SEL))g_origListLayout)(self, _cmd);
    }
    // Only touch the container the getter gave us; never guess the hierarchy.
    UIView *container = g_ios6KnownContainer;
    if (container && ((UIView *)self).superview == container) {
        LUIIOS6UpdateContainer(container);
    }
}

static void LUIInstallIOS6Dock() {
    dispatch_once(&g_ios6Once, ^{
        Class iconControllerClass = NSClassFromString(@"SBIconController");
        if (!iconControllerClass) {
            NSLog(@"[LegacyUI] SBIconController unavailable — iOS 6 dock disabled");
            return;
        }

        Method containerMethod = class_getInstanceMethod(iconControllerClass,
                                                         @selector(dockContainerView));
        if (!containerMethod) {
            NSLog(@"[LegacyUI] SBIconController dockContainerView unsupported — iOS 6 dock disabled");
            return;
        }

        if (class_addMethod(iconControllerClass, @selector(dockContainerView),
                            (IMP)LUIIOS6DockContainerSwizzled,
                            method_getTypeEncoding(containerMethod))) {
            g_origDockContainerView = method_getImplementation(containerMethod);
        } else {
            g_origDockContainerView = method_setImplementation(containerMethod,
                                                               (IMP)LUIIOS6DockContainerSwizzled);
        }

        // Optional layout integration, per spec: only after the runtime check.
        Class listClass = NSClassFromString(@"SBDockIconListView");
        if (listClass) {
            Method listMethod = class_getInstanceMethod(listClass, @selector(layoutSubviews));
            if (listMethod) {
                if (class_addMethod(listClass, @selector(layoutSubviews),
                                    (IMP)LUIIOS6ListLayoutSwizzled,
                                    method_getTypeEncoding(listMethod))) {
                    g_origListLayout = method_getImplementation(listMethod);
                } else {
                    g_origListLayout = method_setImplementation(listMethod,
                                                                (IMP)LUIIOS6ListLayoutSwizzled);
                }
            }
        }

        g_swizzleInstalled = YES;

        // Trigger an immediate attach on the existing controller instance.
        if (class_getInstanceMethod(iconControllerClass, @selector(sharedInstance))) {
            id shared = [iconControllerClass performSelector:@selector(sharedInstance)];
            if (shared) {
                ((void (*)(id, SEL))objc_msgSend)(shared, @selector(dockContainerView));
            }
        }

        NSLog(@"[LegacyUI] iOS 6 dock hooks installed");
    });
}

#pragma mark - Controller

@implementation CUIDockController

+ (instancetype)sharedInstance {
    static CUIDockController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CUIDockController alloc] init];
    });
    return instance;
}

- (void)activate {
    if (CUIIsiOS6OrEarlier()) {
        LUIInstallIOS6Dock();
    } else {
        LUIInstallIOS8Dock();
    }
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

    if (CUIIsiOS6OrEarlier()) {
        Class iconControllerClass = NSClassFromString(@"SBIconController");
        if (iconControllerClass &&
            class_getInstanceMethod(iconControllerClass, @selector(sharedInstance))) {
            id shared = [iconControllerClass performSelector:@selector(sharedInstance)];
            if (shared) {
                ((void (*)(id, SEL))objc_msgSend)(shared, @selector(dockContainerView));
            }
        }
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            [self relayoutIOS6InView:window];
        }
        return;
    }

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

- (void)relayoutIOS6InView:(UIView *)view {
    if ([NSStringFromClass([view class]) rangeOfString:@"IconList"].location != NSNotFound) {
        [view setNeedsLayout];
        return;
    }
    for (UIView *sub in view.subviews) {
        [self relayoutIOS6InView:sub];
    }
}

@end