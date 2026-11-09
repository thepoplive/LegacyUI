#import "CUIOverlayWindow.h"

@interface CUIOverlayWindow : UIWindow
@end

@implementation CUIOverlayWindow

// Touch-transparent window: touches outside our subviews fall through
// to the app / SpringBoard windows below.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) return nil;
    return hit;
}

@end

UIWindow *CUISharedOverlayWindow(void) {
    static UIWindow *window = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        window = [[CUIOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        // Above the CC SBSecureWindow (StatusBar + 2) so the MD3 sheet both
        // renders above the (invisible) native CC and receives its touches.
        window.windowLevel = UIWindowLevelStatusBar + 100.0;
        window.backgroundColor = [UIColor clearColor];
        window.userInteractionEnabled = YES;
        window.hidden = NO;
    });
    return window;
}