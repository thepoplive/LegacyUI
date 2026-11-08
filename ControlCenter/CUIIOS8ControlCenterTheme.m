#import "CUIIOS8ControlCenterTheme.h"
#import "../Core/CUIConfiguration.h"
#import "../Core/CUICompatibility.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>

// Verified against the iOS 8.0/8.1 dumps (MP0w/iOS-Headers):
//   SBUIControlCenterButton (SpringBoardUI):
//     + (UIImage *)_circleBackgroundImageForState:(int)state;
//     + (UIImage *)_roundRectBackgroundImageForState:(int)state;
//   SBControlCenterContentContainerView (SpringBoard):
//     - (void)layoutSubviews;  ivars: _backdropView, _contentView

#define IOS8_CC_ACCENT   [UIColor colorWithRed:0xD0/255.0 green:0xBC/255.0 blue:0xFF/255.0 alpha:1.0]
#define IOS8_CC_ACTIVE   [UIColor colorWithRed:0x4F/255.0 green:0x37/255.0 blue:0x8B/255.0 alpha:1.0]
#define IOS8_CC_IDLE     [UIColor colorWithWhite:1.0 alpha:0.10]
#define IOS8_CC_BORDER_A 0.20

static BOOL CUIIOS8CCWanted() {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.controlCenterEnabled;
}

#pragma mark - Image factories

static UIImage *CUIIOS8CircleImage(CGSize size, NSUInteger state) {
    BOOL active = (state & UIControlStateSelected) != 0;
    BOOL highlighted = (state & UIControlStateHighlighted) != 0;
    if (size.width < 4 || size.height < 4) size = CGSizeMake(120, 120);

    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0, 0, size.width, size.height);
    CGFloat inset = size.width * 0.02;
    CGRect circle = CGRectInset(r, inset, inset);

    if (active) {
        // Soft outer glow baked into the padding.
        CGContextSetShadowWithColor(ctx, CGSizeZero, size.width * 0.10,
                                    [IOS8_CC_ACCENT colorWithAlphaComponent:0.55].CGColor);
        CGContextSetFillColorWithColor(ctx, IOS8_CC_ACTIVE.CGColor);
        CGContextFillEllipseInRect(ctx, circle);
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, nil);
    } else {
        CGContextSetFillColorWithColor(ctx, IOS8_CC_IDLE.CGColor);
        CGContextFillEllipseInRect(ctx, circle);
    }

    if (highlighted) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.12].CGColor);
        CGContextFillEllipseInRect(ctx, circle);
    }

    // Thin border ring.
    CGContextSetStrokeColorWithColor(ctx,
        (active ? [IOS8_CC_ACCENT colorWithAlphaComponent:0.7]
                : [UIColor colorWithWhite:1.0 alpha:IOS8_CC_BORDER_A]).CGColor);
    CGContextSetLineWidth(ctx, size.width * 0.02);
    CGContextStrokeEllipseInRect(ctx, circle);

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

    CGContextSetFillColorWithColor(ctx, IOS8_CC_IDLE.CGColor);
    CGContextAddPath(ctx, tile.CGPath);
    CGContextFillPath(ctx);
    if (highlighted) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.10].CGColor);
        CGContextAddPath(ctx, tile.CGPath);
        CGContextFillPath(ctx);
    }
    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithWhite:1.0 alpha:IOS8_CC_BORDER_A].CGColor);
    CGContextSetLineWidth(ctx, size.width * 0.008);
    CGContextAddPath(ctx, tile.CGPath);
    CGContextStrokePath(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

#pragma mark - Swizzles

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

#pragma mark - Panel glass overlay

static char kIOS8CCPanelTintKey;
static char kIOS8CCPanelBorderKey;

// Ground-truth diagnostics: /var/mobile/.legacyui_ccdump -> full native CC
// hierarchy on THIS firmware (8.4.1), plus swizzle status and factory call
// counters, written to /var/mobile/legacyui_ccdump.txt on the next panel
// layout (i.e. the first Control Center open after respring).
static void CUIIOS8DumpView(UIView *view, NSMutableString *out, int depth) {
    for (int i = 0; i < depth; i++) [out appendString:@"  "];
    [out appendFormat:@"%@ frame=%@ alpha=%.2f hidden=%d",
        NSStringFromClass([view class]),
        NSStringFromCGRect(view.frame),
        view.alpha, view.hidden];
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        [out appendFormat:@" image=%@",
            iv.image ? NSStringFromCGSize(iv.image.size) : @"nil"];
    }
    if ([view isKindOfClass:[UIControl class]]) {
        [out appendFormat:@" state=%lu selected=%d highlighted=%d",
            (unsigned long)[(UIControl *)view state],
            [(UIControl *)view isSelected],
            [(UIControl *)view isHighlighted]];
    }
    [out appendString:@"\n"];
    for (UIView *sub in view.subviews) {
        CUIIOS8DumpView(sub, out, depth + 1);
    }
}

static void CUIIOS8MaybeDumpCC(UIView *panel) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/.legacyui_ccdump"]) return;

    NSMutableString *dump = [NSMutableString string];
    [dump appendFormat:@"=== LegacyUI iOS8 CC diagnostics ===\n"];
    [dump appendFormat:@"swizzles: circle=%@ tile=%@ panel=%@\n",
        g_origCircleBG ? @"installed" : @"MISSING",
        g_origTileBG ? @"installed" : @"MISSING",
        g_origPanelLayout ? @"installed" : @"MISSING"];
    [dump appendFormat:@"factory calls: circle=%d tile=%d\n", s_circleCalls, s_tileCalls];

    Class buttonClass = NSClassFromString(@"SBUIControlCenterButton");
    [dump appendFormat:@"SBUIControlCenterButton: %@\n", buttonClass ? @"present" : @"ABSENT");
    if (buttonClass) {
        [dump appendFormat:@"  +_circleBackgroundImageForState: %@\n",
            class_getClassMethod(buttonClass, @selector(_circleBackgroundImageForState:))
                ? @"yes" : @"NO"];
        [dump appendFormat:@"  +_roundRectBackgroundImageForState: %@\n",
            class_getClassMethod(buttonClass, @selector(_roundRectBackgroundImageForState:))
                ? @"yes" : @"NO"];
    }
    [dump appendFormat:@"SBCCButtonLikeSectionView: %@\n",
        NSClassFromString(@"SBCCButtonLikeSectionView") ? @"present" : @"ABSENT"];

    // Walk up to the CC root for the full tree.
    UIView *root = panel;
    while (root.superview) root = root.superview;
    [dump appendString:@"\n=== full CC view tree (from window root) ===\n"];
    CUIIOS8DumpView(root, dump, 0);

    [dump writeToFile:@"/var/mobile/legacyui_ccdump.txt"
           atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/.legacyui_ccdump" error:NULL];
    NSLog(@"[LegacyUI] CC hierarchy dumped");
}

static UIView *CUIIOS8IvarView(id view, NSString *ivarName) {
    Ivar ivar = class_getInstanceVariable([view class], [ivarName UTF8String]);
    if (!ivar) return nil;
    id value = object_getIvar(view, ivar);
    return [value isKindOfClass:[UIView class]] ? value : nil;
}

static IMP g_origPanelLayout = NULL;

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
        // Dark glass wash between the native blur and the content.
        tint = [[UIView alloc] init];
        tint.userInteractionEnabled = NO;
        tint.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.30];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        UIView *content = CUIIOS8IvarView(panel, @"_contentView");
        if (content) {
            [panel insertSubview:tint belowSubview:content];
        } else {
            [panel addSubview:tint];
        }
        objc_setAssociatedObject(panel, &kIOS8CCPanelTintKey, tint,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Top corner rounding + hairline border, our 3GS panel geometry.
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

    CUIIOS8MaybeDumpCC(panel);

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
    // A class method lives on the metaclass; swap through the same handle.
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
        if (!buttonClass) {
            NSLog(@"[LegacyUI] SBUIControlCenterButton unavailable — iOS 8 CC theming off");
            return;
        }
        CUIIOS8SwizzleClassMethod(buttonClass,
                                  @selector(_circleBackgroundImageForState:),
                                  (IMP)CUIIOS8CircleBGSwizzled, &g_origCircleBG);
        CUIIOS8SwizzleClassMethod(buttonClass,
                                  @selector(_roundRectBackgroundImageForState:),
                                  (IMP)CUIIOS8TileBGSwizzled, &g_origTileBG);
        NSLog(@"[LegacyUI] SBUIControlCenterButton image factories swizzled");

        Class panelClass = NSClassFromString(@"SBControlCenterContentContainerView");
        if (panelClass && class_getInstanceMethod(panelClass, @selector(layoutSubviews))) {
            CUIIOS8SwizzleMethod(panelClass, @selector(layoutSubviews),
                                 (IMP)CUIIOS8PanelLayoutSwizzled, &g_origPanelLayout);
            NSLog(@"[LegacyUI] SBControlCenterContentContainerView layout swizzled");
        }
    });
}
