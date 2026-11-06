#import "CUIGlassView.h"
#import "CUITheme.h"

@interface CUIGlassView ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) CAGradientLayer *highlightLayer;
@end

@implementation CUIGlassView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _cornerRadiusValue = 20.0;
        _glassOpacity = 0.55;

        self.userInteractionEnabled = NO;

        _contentView = [[UIView alloc] init];
        _contentView.backgroundColor = [UIColor clearColor];
        _contentView.layer.masksToBounds = YES;
        [self addSubview:_contentView];

        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_contentView addSubview:_blurView];

        _tintView = [[UIView alloc] init];
        _tintView.backgroundColor = [UIColor colorWithWhite:0.09 alpha:_glassOpacity];
        [_contentView addSubview:_tintView];

        _highlightLayer = [CAGradientLayer layer];
        _highlightLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.14].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        _highlightLayer.locations = @[@0.0, @0.5];
        _highlightLayer.startPoint = CGPointMake(0.5, 0.0);
        _highlightLayer.endPoint = CGPointMake(0.5, 1.0);
        [_contentView.layer addSublayer:_highlightLayer];

        _contentView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
        _contentView.layer.borderWidth = 1.0;

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.35;
        self.layer.shadowOffset = CGSizeMake(0, 6);
        self.layer.shadowRadius = 10.0;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _contentView.frame = self.bounds;
    _blurView.frame = _contentView.bounds;
    _tintView.frame = _contentView.bounds;

    _contentView.layer.cornerRadius = _cornerRadiusValue;
    _highlightLayer.frame = CGRectMake(0, 0, _contentView.bounds.size.width,
                                       _contentView.bounds.size.height * 0.45);

    self.layer.shadowPath = [UIBezierPath
        bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadiusValue].CGPath;
}

- (void)setCornerRadiusValue:(CGFloat)cornerRadiusValue {
    _cornerRadiusValue = cornerRadiusValue;
    [self setNeedsLayout];
}

- (void)setGlassOpacity:(CGFloat)glassOpacity {
    _glassOpacity = glassOpacity;
    _tintView.backgroundColor = [UIColor colorWithWhite:0.09 alpha:glassOpacity];
}

- (void)setShowBorder:(BOOL)showBorder {
    _showBorder = showBorder;
    _contentView.layer.borderWidth = showBorder ? 1.0 : 0.0;
}

- (void)setShowHighlight:(BOOL)showHighlight {
    _showHighlight = showHighlight;
    _highlightLayer.hidden = !showHighlight;
}

- (void)applyGlassStyle {
    [self setNeedsLayout];
}

@end