#import "CUIIOS8ControlCenterTheme.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#import <math.h>

// iOS 8 native Control Center restyle — LegacyUI Liquid Glass.
//
// Ground truth (on-device dump, iPhone 4S 8.4.1):
//   SBControlCenterContentContainerView: -layoutSubviews, ivars _contentView
//   SBControlCenterButton (UIControl): full-size UIImageView "plate" is the
//     circle background AND sits ABOVE the glyph UIImageView; the on/off
//     state is the plain UIControl selected flag.
// iOS 8.0-8.1 also had +image factory methods (kept, no-op on 8.4).

#define IOS8_CC_ACCENT   [UIColor colorWithRed:0xD0/255.0 green:0xBC/255.0 blue:0xFF/255.0 alpha:1.0]
#define IOS8_CC_ACTIVE_A [UIColor colorWithRed:0x7A/255.0 green:0x5F/255.0 blue:0xB5/255.0 alpha:1.0]
#define IOS8_CC_ACTIVE_B [UIColor colorWithRed:0x4F/255.0 green:0x37/255.0 blue:0x8B/255.0 alpha:1.0]

static BOOL CUIIOS8CCWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.controlCenterEnabled;
}

#pragma mark - Liquid glass drawing

static CGGradientRef CUIIOS8LinearGradient(CGFloat *components, CGPoint start, CGPoint end) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(
        space, components, NULL, 2);
    CFRelease(space);
    (void)start; (void)end;
    return gradient;
}

// Translucent glass: vertical sheen, specular highlight near the top,
// hairline border. Everything inside the circle clip.
static void CUIIOS8DrawGlassCircle(CGContextRef ctx, CGRect circle) {
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, circle);
    CGContextClip(ctx);

    CGFloat sheen[] = {1, 1, 1, 0.20, 1, 1, 1, 0.04};
    CGGradientRef grad = CUIIOS8LinearGradient(sheen, CGPointZero, CGPointZero);
    CGContextDrawLinearGradient(ctx, grad,
        circle.origin,
        CGPointMake(circle.origin.x, CGRectGetMaxY(circle)),
        kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CFRelease(grad);

    CGFloat spec[] = {1, 1, 1, 0.38, 1, 1, 1, 0.0};
    CGFloat specW = circle.size.width * 0.60;
    CGFloat specH = circle.size.height * 0.26;
    CGRect specRect = CGRectMake(
        CGRectGetMidX(circle) - specW / 2.0,
        circle.origin.y + circle.size.height * 0.10,
        specW, specH);
    CGContextAddEllipseInRect(ctx, specRect);
    CGContextClip(ctx);
    CGGradientRef specGrad = CUIIOS8LinearGradient(spec, CGPointZero, CGPointZero);
    CGContextDrawLinearGradient(ctx, specGrad,
        specRect.origin,
        CGPointMake(specRect.origin.x, CGRectGetMaxY(specRect)), 0);
    CFRelease(specGrad);
    CGContextRestoreGState(ctx);

    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithWhite:1.0 alpha:0.35].CGColor);
    CGContextSetLineWidth(ctx, MAX(1.0, circle.size.width * 0.022));
    CGContextStrokeEllipseInRect(ctx, circle);
}

// Active liquid: violet radial fill with a lit core, specular top,
// accent hairline. The outer glow is a real layer shadow (see StyleButton),
// so nothing is baked/clipped here.
static void CUIIOS8DrawActiveCircle(CGContextRef ctx, CGRect circle) {
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, circle);
    CGContextClip(ctx);

    CGFloat inner[] = {0x7A/255.0, 0x5F/255.0, 0xB5/255.0, 1.0};
    CGFloat outer[] = {0x4F/255.0, 0x37/255.0, 0x8B/255.0, 1.0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColorComponents(
        space, inner, NULL, 1);
    CGGradientRef gradEdge = CGGradientCreateWithColorComponents(
        space, outer, NULL, 1);
    CFRelease(space);

    CGPoint core = CGPointMake(CGRectGetMidX(circle),
                               circle.origin.y + circle.size.height * 0.38);
    // Two-stop radial via edge fill then lighter core overlay.
    CGContextDrawRadialGradient(ctx, gradEdge,
        core, 0, core, circle.size.width * 0.75, 0);
    CGContextDrawRadialGradient(ctx, grad,
        core, 0, core, circle.size.width * 0.45, 0);
    CFRelease(grad);
    CFRelease(gradEdge);

    CGFloat spec[] = {1, 1, 1, 0.30, 1, 1, 1, 0.0};
    CGFloat specW = circle.size.width * 0.55;
    CGFloat specH = circle.size.height * 0.22;
    CGRect specRect = CGRectMake(
        CGRectGetMidX(circle) - specW / 2.0,
        circle.origin.y + circle.size.height * 0.09,
        specW, specH);
    CGContextAddEllipseInRect(ctx, specRect);
    CGContextClip(ctx);
    CGGradientRef specGrad = CUIIOS8LinearGradient(spec, CGPointZero, CGPointZero);
    CGContextDrawLinearGradient(ctx, specGrad,
        specRect.origin,
        CGPointMake(specRect.origin.x, CGRectGetMaxY(specRect)), 0);
    CFRelease(specGrad);
    CGContextRestoreGState(ctx);

    CGContextSetStrokeColorWithColor(ctx,
        [IOS8_CC_ACCENT colorWithAlphaComponent:0.8].CGColor);
    CGContextSetLineWidth(ctx, MAX(1.0, circle.size.width * 0.022));
    CGContextStrokeEllipseInRect(ctx, circle);
}

static UIImage *CUIIOS8CircleImage(CGSize size, NSUInteger state) {
    BOOL active = (state & UIControlStateSelected) != 0;
    BOOL highlighted = (state & UIControlStateHighlighted) != 0;
    if (size.width < 4 || size.height < 4) size = CGSizeMake(94, 94);

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0, 0, size.width, size.height);
    CGFloat inset = MAX(1.0, size.width * 0.02);
    CGRect circle = CGRectInset(r, inset, inset);

    if (active) {
        CUIIOS8DrawActiveCircle(ctx, circle);
    } else {
        CUIIOS8DrawGlassCircle(ctx, circle);
    }
    if (highlighted) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.10].CGColor);
        CGContextFillEllipseInRect(ctx, circle);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *CUIIOS8TileImage(CGSize size, NSUInteger state) {
    BOOL highlighted = (state & UIControlStateHighlighted) != 0;
    if (size.width < 4 || size.height < 4) size = CGSizeMake(280, 120);

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0, 0, size.width, size.height);
    UIBezierPath *tile = [UIBezierPath bezierPathWithRoundedRect:r
        cornerRadius:MIN(size.width, size.height) * 0.24];

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.09].CGColor);
    CGContextAddPath(ctx, tile.CGPath);
    CGContextFillPath(ctx);
    if (highlighted) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.10].CGColor);
        CGContextAddPath(ctx, tile.CGPath);
        CGContextFillPath(ctx);
    }
    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithWhite:1.0 alpha:0.28].CGColor);
    CGContextSetLineWidth(ctx, MAX(1.0, size.width * 0.008));
    CGContextAddPath(ctx, tile.CGPath);
    CGContextStrokePath(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Legacy 8.0-8.1 image factory swizzles (no-op on 8.4)

static IMP g_origCircleBG = NULL;
static IMP g_origTileBG = NULL;
static int s_circleCalls = 0;
static int s_tileCalls = 0;

static UIImage *CUIIOS8CircleBGSwizzled(id self, SEL _cmd, long state) {
    s_circleCalls++;
    UIImage *orig = NULL;
    if (g_origCircleBG) {
        orig = ((UIImage *(*)(id, SEL, long))g_origCircleBG)(self, _cmd, state);
    }
    if (!CUIIOS8CCWanted()) return orig;
    CGSize size = orig.size;
    if (size.width < 4) size = CGSizeMake(120, 120);
    return CUIIOS8CircleImage(size, (NSUInteger)state);
}

static UIImage *CUIIOS8TileBGSwizzled(id self, SEL _cmd, long state) {
    s_tileCalls++;
    UIImage *orig = NULL;
    if (g_origTileBG) {
        orig = ((UIImage *(*)(id, SEL, long))g_origTileBG)(self, _cmd, state);
    }
    if (!CUIIOS8CCWanted()) return orig;
    CGSize size = orig.size;
    if (size.width < 4) size = CGSizeMake(280, 120);
    return CUIIOS8TileImage(size, (NSUInteger)state);
}

#pragma mark - Toggle restyle (8.4.1 plate swap + state swizzles)

static UIImage *CUIIOS8CachedCircle(CGSize size, NSUInteger state) {
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSMutableDictionary alloc] init]; });
    NSString *key = [NSString stringWithFormat:@"%.0fx%.0f-%lu",
                     size.width, size.height, (unsigned long)state];
    @synchronized (cache) {
        UIImage *hit = cache[key];
        if (hit) return hit;
    }
    UIImage *image = CUIIOS8CircleImage(size, state);
    if (image) {
        @synchronized (cache) { cache[key] = image; }
    }
    return image;
}

static UIImageView *CUIIOS8ButtonPlate(UIControl *button) {
    for (UIView *sub in button.subviews) {
        if (![sub isKindOfClass:[UIImageView class]]) continue;
        if (sub.frame.size.width >= button.bounds.size.width * 0.95 &&
            ABS(sub.frame.size.width - sub.frame.size.height) < 1.0) {
            return (UIImageView *)sub;
        }
    }
    return nil;
}

// Restyle one button: swap the plate image ONLY (idempotent — safe inside
// the layout pass, proven stable in 0.4.2). The glyph reorder is once per
// button and deferred. Glow lives in the setSelected: swizzle (once per
// actual state change) — assigning shadow paths on every layout pass is
// what watchdog-killed SpringBoard (120s hang, on-device stacks).
static char kIOS8CCOrderKey;

static void CUIIOS8StyleButton(UIControl *button) {
    static Class buttonClass = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ buttonClass = NSClassFromString(@"SBControlCenterButton"); });
    if (!buttonClass || ![button isKindOfClass:buttonClass]) return;

    UIImageView *plate = CUIIOS8ButtonPlate(button);
    if (!plate) return;

    if (!objc_getAssociatedObject(button, &kIOS8CCOrderKey)) {
        objc_setAssociatedObject(button, &kIOS8CCOrderKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImageView *plateNow = CUIIOS8ButtonPlate(button);
            if (!plateNow) return;
            for (UIView *sub in button.subviews) {
                if (sub != plateNow) [button bringSubviewToFront:sub];
            }
        });
    }

    NSUInteger state = 0;
    if (button.selected) state |= UIControlStateSelected;
    if (button.highlighted) state |= UIControlStateHighlighted;
    UIImage *styled = CUIIOS8CachedCircle(button.bounds.size, state);
    if (styled && plate.image != styled) plate.image = styled;
}

// Soft violet glow around active circles — applied ONLY on real state
// transitions, never from a layout pass.
static void CUIIOS8ApplyGlow(UIControl *button, BOOL active) {
    button.layer.shadowColor = IOS8_CC_ACCENT.CGColor;
    button.layer.shadowRadius = 9.0;
    button.layer.shadowOffset = CGSizeZero;
    button.layer.shadowOpacity = active ? 0.45 : 0.0;
    button.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:
        CGRectInset(button.bounds, 2.0, 2.0)].CGPath;
}

static void CUIIOS8StyleButtonsInTree(UIView *view) {
    if ([view isKindOfClass:[UIControl class]]) {
        CUIIOS8StyleButton((UIControl *)view);
    }
    for (UIView *sub in view.subviews) {
        CUIIOS8StyleButtonsInTree(sub);
    }
}

#pragma mark State swizzles (stable subset)

static IMP g_origSetSelected = NULL;

static void CUIIOS8SetSelectedSwizzled(id self, SEL _cmd, BOOL selected) {
    BOOL was = ((UIControl *)self).selected;
    if (g_origSetSelected) {
        ((void (*)(id, SEL, BOOL))g_origSetSelected)(self, _cmd, selected);
    }
    if (!CUIIOS8CCWanted()) return;
    UIControl *button = (UIControl *)self;
    CUIIOS8StyleButton(button);
    if (was != selected) {
        CUIIOS8ApplyGlow(button, selected);
        if (selected) {
            // One-shot glow pulse on activation.
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
            pulse.fromValue = @0.85;
            pulse.toValue = @0.45;
            pulse.duration = 0.5;
            pulse.timingFunction = [CAMediaTimingFunction functionWithName:
                kCAMediaTimingFunctionEaseOut];
            [button.layer addAnimation:pulse forKey:@"glowPulse"];
        }
    }
}

static IMP g_origSetHighlighted = NULL;

static void CUIIOS8SetHighlightedSwizzled(id self, SEL _cmd, BOOL highlighted) {
    if (g_origSetHighlighted) {
        ((void (*)(id, SEL, BOOL))g_origSetHighlighted)(self, _cmd, highlighted);
    }
    if (CUIIOS8CCWanted()) {
        CUIIOS8StyleButton((UIControl *)self); // image swap only, idempotent
    }
}

#pragma mark - Panel glass overlay

static IMP g_origPanelLayout = NULL;

static char kIOS8CCPanelTintKey;
static char kIOS8CCPanelBorderKey;

static UIView *CUIIOS8IvarView(id view, NSString *ivarName) {
    Ivar ivar = class_getInstanceVariable([view class], [ivarName UTF8String]);
    if (!ivar) return nil;
    id value = object_getIvar(view, ivar);
    return [value isKindOfClass:[UIView class]] ? value : nil;
}

static void CUIIOS8PanelLayoutSwizzled(id self, SEL _cmd) {
    if (g_origPanelLayout) {
        ((void (*)(id, SEL))g_origPanelLayout)(self, _cmd);
    }
    UIView *panel = (UIView *)self;

    UIView *tint = objc_getAssociatedObject(panel, &kIOS8CCPanelTintKey);
    if (!CUIIOS8CCWanted()) {
        if (tint) {
            [tint removeFromSuperview];
            objc_setAssociatedObject(panel, &kIOS8CCPanelTintKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UIView *border = objc_getAssociatedObject(panel, &kIOS8CCPanelBorderKey);
            [border removeFromSuperview];
            objc_setAssociatedObject(panel, &kIOS8CCPanelBorderKey, nil,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    if (!tint) {
        tint = [[UIView alloc] init];
        tint.userInteractionEnabled = NO;
        tint.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.28];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        UIView *content = CUIIOS8IvarView(panel, @"_contentView");
        if (content) {
            [panel insertSubview:tint belowSubview:content];
        } else {
            [panel addSubview:tint];
        }
        objc_setAssociatedObject(panel, &kIOS8CCPanelTintKey, tint,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UIView *border = [[UIView alloc] init];
        border.userInteractionEnabled = NO;
        border.backgroundColor = [UIColor clearColor];
        border.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
        border.layer.borderWidth = 1.0;
        border.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [panel addSubview:border];
        objc_setAssociatedObject(panel, &kIOS8CCPanelBorderKey, border,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        NSLog(@"[LegacyUI] iOS 8 CC panel glass installed");
    }

    UIView *border = objc_getAssociatedObject(panel, &kIOS8CCPanelBorderKey);
    tint.frame = panel.bounds;
    border.frame = panel.bounds;

    CGFloat radius = 24.0;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:panel.bounds
        byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
        cornerRadii:CGSizeMake(radius, radius)];
    CAShapeLayer *tintMask = [CAShapeLayer layer];
    tintMask.path = path.CGPath;
    tint.layer.mask = tintMask;
    CAShapeLayer *borderMask = [CAShapeLayer layer];
    borderMask.path = path.CGPath;
    border.layer.mask = borderMask;

    // Catch-all for freshly created buttons: image swaps only, fully
    // idempotent — synchronous like the proven-stable 0.4.2 pass.
    CUIIOS8StyleButtonsInTree(panel);
}

#pragma mark - Install

static void CUIIOS8SwizzleMethod(Class cls, SEL sel, IMP newImp, IMP *origOut) {
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) return;
    if (class_addMethod(cls, sel, newImp, method_getTypeEncoding(method))) {
        *origOut = method_getImplementation(method);
    } else {
        *origOut = method_setImplementation(method, newImp);
    }
}

static void CUIIOS8SwizzleClassMethod(Class cls, SEL sel, IMP newImp, IMP *origOut) {
    Method method = class_getClassMethod(cls, sel);
    if (!method) return;
    if (class_addMethod(object_getClass(cls), sel, newImp, method_getTypeEncoding(method))) {
        *origOut = method_getImplementation(method);
    } else {
        *origOut = method_setImplementation(method, newImp);
    }
}

static dispatch_once_t g_ios8CCOnce;

void CUIIOS8InstallControlCenterTheme(void) {
    dispatch_once(&g_ios8CCOnce, ^{
        Class buttonClass = NSClassFromString(@"SBUIControlCenterButton");
        if (buttonClass) {
            // iOS 8.0-8.1 factories (absent on 8.4.1 — verified on device).
            CUIIOS8SwizzleClassMethod(buttonClass,
                                      @selector(_circleBackgroundImageForState:),
                                      (IMP)CUIIOS8CircleBGSwizzled, &g_origCircleBG);
            CUIIOS8SwizzleClassMethod(buttonClass,
                                      @selector(_roundRectBackgroundImageForState:),
                                      (IMP)CUIIOS8TileBGSwizzled, &g_origTileBG);
        }

        // iOS 8.4.1 path: plate swap + glow on real state changes.
        Class ccButtonClass = NSClassFromString(@"SBControlCenterButton");
        if (ccButtonClass) {
            CUIIOS8SwizzleMethod(ccButtonClass, @selector(setSelected:),
                                 (IMP)CUIIOS8SetSelectedSwizzled, &g_origSetSelected);
            CUIIOS8SwizzleMethod(ccButtonClass, @selector(setHighlighted:),
                                 (IMP)CUIIOS8SetHighlightedSwizzled, &g_origSetHighlighted);
            NSLog(@"[LegacyUI] SBControlCenterButton state swizzles installed");
        }

        Class panelClass = NSClassFromString(@"SBControlCenterContentContainerView");
        if (panelClass && class_getInstanceMethod(panelClass, @selector(layoutSubviews))) {
            CUIIOS8SwizzleMethod(panelClass, @selector(layoutSubviews),
                                 (IMP)CUIIOS8PanelLayoutSwizzled, &g_origPanelLayout);
            NSLog(@"[LegacyUI] SBControlCenterContentContainerView layout swizzled");
        }
    });
}
