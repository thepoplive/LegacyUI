#import "CUISliderControl.h"

#define CUICC_ACCENT [UIColor colorWithRed:0xD0/255.0 green:0xBC/255.0 blue:0xFF/255.0 alpha:1.0]

@interface CUISliderControl ()
@property (nonatomic, strong) UIView *trackView;
@property (nonatomic, strong) UIView *fillView;
@property (nonatomic, strong) UIView *thumbView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) CUICCIcon icon;
@property (nonatomic, assign) CGFloat iconArea;
@end

@implementation CUISliderControl

- (instancetype)initWithIcon:(CUICCIcon)icon {
    self = [super initWithFrame:CGRectMake(0, 0, 56, 132)];
    if (self) {
        _icon = icon;
        _value = 0.5;
        _iconArea = 24.0;
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        self.layer.cornerRadius = self.bounds.size.width / 2.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        self.layer.borderWidth = 1.0;

        _trackView = nil;

        _fillView = [[UIView alloc] init];
        _fillView.backgroundColor = CUICC_ACCENT;
        [self addSubview:_fillView];

        _thumbView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 14)];
        _thumbView.backgroundColor = [UIColor whiteColor];
        _thumbView.layer.cornerRadius = 7.0;
        _thumbView.userInteractionEnabled = NO;
        _thumbView.layer.shadowColor = [UIColor blackColor].CGColor;
        _thumbView.layer.shadowOpacity = 0.35;
        _thumbView.layer.shadowRadius = 3.0;
        _thumbView.layer.shadowOffset = CGSizeMake(0, 1);
        [self addSubview:_thumbView];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 18, 18)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.userInteractionEnabled = NO;
        _iconView.image = CUICCIconImage(icon, _iconView.bounds.size,
                                         [UIColor colorWithWhite:1.0 alpha:0.85]);
        [self addSubview:_iconView];

        [self layoutForValue];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.width / 2.0;

    CGFloat w = self.bounds.size.width;
    _iconView.frame = CGRectMake((w - 18) / 2.0, 10, 18, 18);
    [self layoutForValue];
}

- (CGFloat)minYForThumb {
    return 34.0;
}

- (CGFloat)maxYForThumb {
    return self.bounds.size.height - 20.0;
}

- (void)layoutForValue {
    CGFloat top = [self minYForThumb];
    CGFloat bottom = [self maxYForThumb];
    CGFloat y = bottom - (bottom - top) * _value;
    CGFloat w = self.bounds.size.width;
    CGFloat trackX = 8.0;

    _fillView.frame = CGRectMake(trackX, y, w - trackX * 2, bottom - y + 8);
    _fillView.layer.cornerRadius = (w - trackX * 2) / 2.0;
    _thumbView.center = CGPointMake(w / 2, y);
}

- (void)setValue:(float)value {
    _value = value < 0 ? 0 : (value > 1 ? 1 : value);
    [self layoutForValue];
}

- (void)setValueAnimated:(float)value {
    _value = value < 0 ? 0 : (value > 1 ? 1 : value);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self layoutForValue];
    [CATransaction commit];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self updateWithTouch:[touches anyObject]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self updateWithTouch:[touches anyObject]];
}

- (void)updateWithTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:self];
    CGFloat top = [self minYForThumb];
    CGFloat bottom = [self maxYForThumb];
    float value = (float)((bottom - point.y) / (bottom - top));
    _value = value < 0 ? 0 : (value > 1 ? 1 : value);
    [self layoutForValue];
    if (self.onValueChange) self.onValueChange(_value);
}

@end