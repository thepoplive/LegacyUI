#import "CUIDockView.h"
#import "../Core/CUIGlassView.h"
#import "../Core/CUITheme.h"

@interface CUIDockView ()
@property (nonatomic, strong) UIView *glassBackgroundView;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) CAGradientLayer *highlightLayer;
@end

@implementation CUIDockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupGlassBackground];
        [self setupBorder];
        [self setupHighlight];
    }
    return self;
}

- (void)setupGlassBackground {
    _glassBackgroundView = [[UIView alloc] init];
    _glassBackgroundView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.75];
    _glassBackgroundView.userInteractionEnabled = NO;
    [self addSubview:_glassBackgroundView];

    _dockHeight = 95.0;
    _dockCornerRadius = 22.0;
}

- (void)setupBorder {
    _borderView = [[UIView alloc] init];
    _borderView.backgroundColor = [UIColor clearColor];
    _borderView.userInteractionEnabled = NO;
    [self addSubview:_borderView];
}

- (void)setupHighlight {
    _highlightLayer = [CAGradientLayer layer];
    _highlightLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.15].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    _highlightLayer.locations = @[@0.0, @0.4];
    _highlightLayer.startPoint = CGPointMake(0.5, 0);
    _highlightLayer.endPoint = CGPointMake(0.5, 1);
    [self.layer addSublayer:_highlightLayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _glassBackgroundView.frame = bounds;
    _borderView.frame = bounds;
    _highlightLayer.frame = CGRectMake(0, 0, bounds.size.width, bounds.size.height * 0.3);

    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:bounds
                                                      cornerRadius:_dockCornerRadius];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;

    _glassBackgroundView.layer.mask = maskLayer;
    _borderView.layer.mask = maskLayer;

    [self updateBorder];
}

- (void)updateBorder {
    _borderView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    _borderView.layer.borderWidth = 1.0;
}

- (void)applyGlassStyle {
    self.layer.cornerRadius = _dockCornerRadius;
    self.layer.masksToBounds = YES;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, -2);
    self.layer.shadowRadius = 8;
    self.layer.shadowOpacity = 0.35;
    self.layer.masksToBounds = NO;
}

- (void)updateForOrientation:(UIInterfaceOrientation)orientation {
    CGFloat width = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat cornerRadius = 22.0;

    if (UIInterfaceOrientationIsLandscape(orientation)) {
        width = CGRectGetHeight([UIScreen mainScreen].bounds);
    }

    self.frame = CGRectMake(0, 0, width - 20, _dockHeight);
    _dockCornerRadius = cornerRadius;
    [self setNeedsLayout];
}

@end