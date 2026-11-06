#import "CUIGlassView.h"
#import "CUITheme.h"
#import <objc/runtime.h>

@interface CUIGlassView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) CAGradientLayer *highlightLayer;
@property (nonatomic, strong) UIView *fallbackBackground;
@end

@implementation CUIGlassView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    _glassOpacity = 0.7;
    _blurRadius = 20.0;
    _cornerRadiusValue = 20.0;
    _showBorder = YES;
    _showHighlight = YES;

    [self setupFallbackBackground];
    [self setupBorderView];
    [self setupHighlightLayer];
    [self setupBlurView];
}

- (void)setupFallbackBackground {
    _fallbackBackground = [[UIView alloc] init];
    _fallbackBackground.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    _fallbackBackground.userInteractionEnabled = NO;
    [self addSubview:_fallbackBackground];
}

- (void)setupBorderView {
    _borderView = [[UIView alloc] init];
    _borderView.backgroundColor = [UIColor clearColor];
    _borderView.userInteractionEnabled = NO;
    [self addSubview:_borderView];
}

- (void)setupHighlightLayer {
    _highlightLayer = [CAGradientLayer layer];
    _highlightLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.2].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    _highlightLayer.locations = @[@0.0, @0.5];
    _highlightLayer.startPoint = CGPointMake(0.5, 0);
    _highlightLayer.endPoint = CGPointMake(0.5, 1);
    [self.layer addSublayer:_highlightLayer];
}

- (void)setupBlurView {
    if (NSClassFromString(@"UIVisualEffectView")) {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        _blurView.userInteractionEnabled = NO;
        [self insertSubview:_blurView atIndex:0];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _fallbackBackground.frame = self.bounds;
    _borderView.frame = self.bounds;
    _blurView.frame = self.bounds;

    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                      cornerRadius:_cornerRadiusValue];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = maskPath.CGPath;
    _fallbackBackground.layer.mask = maskLayer;
    _blurView.layer.mask = maskLayer;
    _borderView.layer.mask = maskLayer;
    _highlightLayer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height * 0.3);

    [self updateBorder];
}

- (void)updateBorder {
    if (_showBorder) {
        _borderView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
        _borderView.layer.borderWidth = 1.0;
    } else {
        _borderView.layer.borderWidth = 0;
    }
}

- (void)applyGlassStyle {
    self.layer.cornerRadius = _cornerRadiusValue;
    self.layer.masksToBounds = YES;

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8;
    self.layer.shadowOpacity = 0.3;
    self.layer.masksToBounds = NO;
}

- (void)setShowBorder:(BOOL)showBorder {
    _showBorder = showBorder;
    [self setNeedsLayout];
}

- (void)setShowHighlight:(BOOL)showHighlight {
    _showHighlight = showHighlight;
    _highlightLayer.hidden = !showHighlight;
}

- (void)setCornerRadiusValue:(CGFloat)cornerRadiusValue {
    _cornerRadiusValue = cornerRadiusValue;
    [self setNeedsLayout];
}

@end