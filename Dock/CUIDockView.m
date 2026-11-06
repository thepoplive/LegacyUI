#import "CUIDockView.h"

@interface CUIDockView ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) CAGradientLayer *highlightLayer;
@end

@implementation CUIDockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;

        _contentView = [[UIView alloc] init];
        _contentView.layer.masksToBounds = YES;
        _contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:_contentView];

        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_contentView addSubview:_blurView];

        _tintView = [[UIView alloc] init];
        _tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.52];
        [_contentView addSubview:_tintView];

        _highlightLayer = [CAGradientLayer layer];
        _highlightLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.55].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.05].CGColor
        ];
        _highlightLayer.locations = @[@0.0, @0.5];
        _highlightLayer.startPoint = CGPointMake(0.5, 0.0);
        _highlightLayer.endPoint = CGPointMake(0.5, 1.0);
        [_contentView.layer addSublayer:_highlightLayer];

        _contentView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.65].CGColor;
        _contentView.layer.borderWidth = 1.0;

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.28;
        self.layer.shadowOffset = CGSizeMake(0, 5);
        self.layer.shadowRadius = 9.0;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _contentView.frame = self.bounds;
    _blurView.frame = _contentView.bounds;
    _tintView.frame = _contentView.bounds;

    CGFloat radius = MIN(self.bounds.size.height / 2.0, 28.0);
    _contentView.layer.cornerRadius = radius;
    _highlightLayer.frame = CGRectMake(0, 0, _contentView.bounds.size.width,
                                       _contentView.bounds.size.height * 0.5);

    self.layer.shadowPath = [UIBezierPath
        bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;
}

@end