#import "CUIDockController.h"
#import "CUIDockView.h"
#import "../Core/CUIConfiguration.h"
#import <objc/runtime.h>

static CUIDockController *_sharedInstance = nil;
static CUIDockView *_legacyDockView = nil;

@implementation CUIDockController

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[CUIDockController alloc] init];
    });
    return _sharedInstance;
}

- (void)activate {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.dockEnabled || !config.liquidGlassEnabled) {
        [self deactivate];
        return;
    }

    if (_legacyDockView) return;

    [self performSelector:@selector(installDockView) withObject:nil afterDelay:0.1];
}

- (void)deactivate {
    if (_legacyDockView) {
        [_legacyDockView removeFromSuperview];
        _legacyDockView = nil;
    }
}

- (void)reloadDock {
    [self deactivate];
    [self activate];
}

- (void)installDockView {
    Class sbDockViewClass = NSClassFromString(@"SBDockView");
    if (!sbDockViewClass) {
        NSLog(@"[LegacyUI] SBDockView class not found");
        return;
    }

    UIView *dockView = [self findDockView];
    if (!dockView) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self installDockView];
        });
        return;
    }

    if (_legacyDockView) {
        [_legacyDockView removeFromSuperview];
    }

    CGRect dockFrame = dockView.frame;
    _legacyDockView = [[CUIDockView alloc] initWithFrame:dockFrame];
    _legacyDockView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_legacyDockView applyGlassStyle];

    [dockView.superview insertSubview:_legacyDockView belowSubview:dockView];
    dockView.backgroundColor = [UIColor clearColor];

    NSLog(@"[LegacyUI] Dock glass view installed");
}

- (UIView *)findDockView {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow) return nil;

    Class sbDockViewClass = NSClassFromString(@"SBDockView");

    for (UIView *subview in keyWindow.subviews) {
        if ([subview isKindOfClass:sbDockViewClass]) {
            return subview;
        }

        for (UIView *child in subview.subviews) {
            if ([child isKindOfClass:sbDockViewClass]) {
                return child;
            }
        }
    }

    return nil;
}

@end