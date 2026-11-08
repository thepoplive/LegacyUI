#import <UIKit/UIKit.h>

typedef void (^CUICCGestureStart)(void);
typedef void (^CUICCGestureProgress)(float progress); // 0..1
typedef void (^CUICCGestureFinish)(float progress, float velocity); // >0 upward

// Invisible strip along the bottom edge tracking an upward swipe.
// Custom touch tracking: UIScreenEdgePanGestureRecognizer is iOS 7+.
@interface CUIControlCenterGrabber : UIView

@property (nonatomic, assign) CGFloat triggerHeight;
@property (nonatomic, copy) CUICCGestureStart onGestureStart;
@property (nonatomic, copy) CUICCGestureProgress onGestureProgress;
@property (nonatomic, copy) CUICCGestureFinish onGestureFinish;

+ (instancetype)attachToView:(UIView *)hostView;

- (void)trace:(NSString *)line;

@end