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

- (void)trace:(NSString *)line {
    NSString *path = @"/var/mobile/legacyui_cc_trace.txt";
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:path
                                                               usedEncoding:NULL error:NULL];
    if (!content) content = [NSMutableString string];
    [content appendFormat:@"[%@] %@\n",
        [NSDate date], line];
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

+ (instancetype)attachToView:(UIView *)hostView {
    // Prefer the window itself: guaranteed top of the home screen stack.
    UIView *host = hostView.window;
    if (!host) host = hostView;

    CUIControlCenterGrabber *grabber = [[CUIControlCenterGrabber alloc]
        initWithFrame:CGRectMake(0, 0, 320, 16)];
    grabber.backgroundColor = [UIColor clearColor];

    // Position strictly in screen coordinates.
    CGRect screenStrip = CGRectMake(0, [UIScreen mainScreen].bounds.size.height - 16.0,
                                    [UIScreen mainScreen].bounds.size.width, 16.0);
    CGRect frameInHost = [host convertRect:screenStrip fromView:nil];
    grabber.frame = frameInHost;
    grabber.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:grabber
                                                                           action:@selector(tapOpen)];
    [grabber addGestureRecognizer:tap];

    [host addSubview:grabber];

    [(CUIControlCenterGrabber *)grabber trace:[NSString stringWithFormat:
        @"grabber attached host=%@ hostBounds=%@ frame=%@",
        NSStringFromClass([host class]),
        NSStringFromCGRect(host.bounds),
        NSStringFromCGRect(grabber.frame)]];

    return grabber;
}

- (void)tapOpen {
    [self trace:@"tap on strip"];
    _tracking = YES;
    _startY = 0;
    _lastY = -300.0;
    _velocity = 0;
    [self finish];
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
    [self trace:[NSString stringWithFormat:@"touch began at %@", NSStringFromCGPoint(point)]];
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
    float progress = (float)(travel / 300.0);
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    if (self.onGestureProgress) self.onGestureProgress(progress);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self finish];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self trace:@"touch cancelled"];
    [self finish];
}

- (void)finish {
    if (!_tracking) return;
    _tracking = NO;
    CGFloat travel = _startY - _lastY;
    float progress = (float)(travel / 300.0);
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    [self trace:[NSString stringWithFormat:@"touch finish progress=%.2f velocity=%.0f",
        progress, _velocity]];
    if (self.onGestureFinish) self.onGestureFinish(progress, _velocity);
}

@end