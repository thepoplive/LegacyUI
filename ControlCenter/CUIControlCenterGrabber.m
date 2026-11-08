#import "CUIControlCenterGrabber.h"
#import <QuartzCore/QuartzCore.h>

@interface CUIControlCenterGrabber ()
@property (nonatomic, assign) BOOL tracking;
@property (nonatomic, assign) CGFloat startY;
@property (nonatomic, assign) CGFloat lastY;
@property (nonatomic, assign) CFTimeInterval lastTime;
@property (nonatomic, assign) CGFloat velocity;
@end

@implementation CUIControlCenterGrabber

+ (instancetype)attachToView:(UIView *)hostView {
    CUIControlCenterGrabber *grabber = [[CUIControlCenterGrabber alloc]
        initWithFrame:CGRectMake(0, hostView.bounds.size.height - 16.0,
                                 hostView.bounds.size.width, 16.0)];
    grabber.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    grabber.backgroundColor = [UIColor clearColor];
    grabber.triggerHeight = 300.0;
    [hostView addSubview:grabber];
    return grabber;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) {
        self.triggerHeight = self.superview.bounds.size.height * 0.65;
    }
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.superview];
    _tracking = YES;
    _startY = point.y;
    _lastY = point.y;
    _lastTime = CACurrentMediaTime();
    _velocity = 0;
    if (self.onGestureStart) self.onGestureStart();
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_tracking) return;
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.superview];

    CFTimeInterval now = CACurrentMediaTime();
    CGFloat dt = (CGFloat)(now - _lastTime);
    if (dt > 0.01) {
        CGFloat dy = _lastY - point.y;
        _velocity = (CGFloat)(dy / dt);
        _lastY = point.y;
        _lastTime = now;
    }

    CGFloat travel = _startY - point.y;
    float progress = (float)(travel / _triggerHeight);
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    if (self.onGestureProgress) self.onGestureProgress(progress);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self finish];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self finish];
}

- (void)finish {
    if (!_tracking) return;
    _tracking = NO;
    CGFloat travel = _startY - _lastY;
    float progress = (float)(travel / _triggerHeight);
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    if (self.onGestureFinish) self.onGestureFinish(progress, _velocity);
}

@end