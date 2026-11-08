#import "CUIControlCenterItem.h"
#import "../Core/CUICompatibility.h"

#define CUICC_ACCENT       [UIColor colorWithRed:0xD0/255.0 green:0xBC/255.0 blue:0xFF/255.0 alpha:1.0]
#define CUICC_ACTIVE_FILL  [UIColor colorWithRed:0x4F/255.0 green:0x37/255.0 blue:0x8B/255.0 alpha:1.0]
#define CUICC_ACTIVE_GLYPH [UIColor colorWithRed:0xEA/255.0 green:0xDD/255.0 blue:0xFF/255.0 alpha:1.0]
#define CUICC_IDLE_FILL    [UIColor colorWithWhite:1.0 alpha:0.08]
#define CUICC_IDLE_GLYPH   [UIColor whiteColor]

@interface CUIControlCenterItem ()
@property (nonatomic, strong) UIView *circleView;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) CUICCIcon icon;
@end

@implementation CUIControlCenterItem

- (instancetype)initWithIcon:(CUICCIcon)iconName {
    self = [super initWithFrame:CGRectMake(0, 0, 56, 56)];
    if (self) {
        _icon = iconName;

        _circleView = [[UIView alloc] initWithFrame:self.bounds];
        _circleView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _circleView.layer.cornerRadius = self.bounds.size.width / 2.0;
        _circleView.layer.masksToBounds = YES;
        _circleView.backgroundColor = CUICC_IDLE_FILL;
        _circleView.userInteractionEnabled = NO;
        [self addSubview:_circleView];

        CGFloat iconSide = 26.0;
        CGRect iconFrame = CGRectMake((self.bounds.size.width - iconSide) / 2.0,
                                      (self.bounds.size.height - iconSide) / 2.0,
                                      iconSide, iconSide);
        _iconView = [[UIImageView alloc] initWithFrame:iconFrame];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];

        [self refreshVisuals];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _circleView.layer.cornerRadius = self.bounds.size.width / 2.0;
}

- (void)refreshVisuals {
    _circleView.backgroundColor = _active ? CUICC_ACTIVE_FILL : CUICC_IDLE_FILL;
    _iconView.image = CUICCIconImage(_icon, _iconView.bounds.size,
                                     _active ? CUICC_ACTIVE_GLYPH : CUICC_IDLE_GLYPH);
    if (_active) {
        _circleView.layer.shadowColor = CUICC_ACCENT.CGColor;
        _circleView.layer.shadowRadius = 10.0;
        _circleView.layer.shadowOffset = CGSizeZero;
        _circleView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;
    } else {
        _circleView.layer.shadowOpacity = 0.0;
    }
}

- (void)setActive:(BOOL)active {
    [self setActive:active animated:NO];
}

- (void)setActive:(BOOL)active animated:(BOOL)animated {
    BOOL changed = (_active != active);
    _active = active;
    if (!changed) return;

    if (animated) {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            [self applyColors];
        } completion:nil];
        if (active) {
            // Activation pulse.
            [UIView animateWithDuration:0.12
                                  delay:0.0
                                options:UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                _circleView.layer.shadowOpacity = 0.8;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.30 delay:0.0
                                    options:UIViewAnimationOptionAllowUserInteraction
                                 animations:^{
                    _circleView.layer.shadowOpacity = 0.55;
                } completion:nil];
            }];
        }
    } else {
        [self applyColors];
    }
}

- (void)applyColors {
    _circleView.backgroundColor = _active ? CUICC_ACTIVE_FILL : CUICC_IDLE_FILL;
    _circleView.layer.shadowOpacity = _active ? 0.55 : 0.0;
    _iconView.image = CUICCIconImage(_icon, _iconView.bounds.size,
                                     _active ? CUICC_ACTIVE_GLYPH : CUICC_IDLE_GLYPH);
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.09 delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = CGAffineTransformMakeScale(0.90, 0.90);
    } completion:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self bounceBack];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self bounceBack];
    if (self.onToggle) self.onToggle();
}

- (void)bounceBack {
    CUISpringAnimate(0.3, ^{
        self.transform = CGAffineTransformIdentity;
    }, nil);
}

@end