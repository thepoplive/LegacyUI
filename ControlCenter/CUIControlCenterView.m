#import "CUIControlCenterView.h"
#import "CUIControlCenterItem.h"
#import "CUISliderControl.h"
#import "CUIMusicCard.h"
#import "CUICCIconDrawing.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIBlurSupport.h"

static const CGFloat kPanelCornerRadius = 28.0;

@interface CUIControlCenterView ()
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *handleView;
@property (nonatomic, strong) UIButton *gearButton;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) CUISliderControl *brightnessSlider;
@property (nonatomic, strong) CUISliderControl *volumeSlider;
@property (nonatomic, strong) CUIMusicCard *musicCard;
@property (nonatomic, assign) CGFloat panelHeight;
@property (nonatomic, assign) float progress;
@end

@implementation CUIControlCenterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _dimView = [[UIView alloc] initWithFrame:self.bounds];
        _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _dimView.backgroundColor = [UIColor blackColor];
        _dimView.alpha = 0.0;
        _dimView.userInteractionEnabled = YES;
        [self addSubview:_dimView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(outsideTap)];
        [_dimView addGestureRecognizer:tap];

        _panelHeight = self.bounds.size.height * 0.65;
        _panel = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height,
                                                          self.bounds.size.width, _panelHeight)];
        _panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _panel.backgroundColor = [UIColor clearColor];
        [self addSubview:_panel];

        // Rounded glass surface (only top corners).
        _blurView = CUICreateBlurView(CUIBlurStyleDark);
        _tintView = [[UIView alloc] init];
        _tintView.backgroundColor = [UIColor colorWithWhite:0.06
                                                      alpha:_blurView ? 0.55 : 0.82];
        if (_blurView) [_panel addSubview:_blurView];

        [_panel addSubview:_tintView];

        _handleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 36, 5)];
        _handleView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        _handleView.layer.cornerRadius = 2.5;
        _handleView.userInteractionEnabled = NO;
        [_panel addSubview:_handleView];

        _gearButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_gearButton setImage:CUICCIconImage(CUICCIconGear, CGSizeMake(24, 24),
                                             [UIColor colorWithWhite:1.0 alpha:0.8])
                     forState:UIControlStateNormal];
        [_gearButton addTarget:self action:@selector(gearTap)
              forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:_gearButton];

        // Toggle row (visual v1 skeleton; service wiring in stage 3).
        CUIControlCenterItem *wifi = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconWiFi];
        CUIControlCenterItem *bt = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconBluetooth];
        CUIControlCenterItem *air = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconAirplane];
        CUIControlCenterItem *dnd = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconMoon];
        _items = @[wifi, bt, air, dnd];
        for (UIView *item in _items) [_panel addSubview:item];

        // Sliders (functional controls; system binding in stage 2).
        _brightnessSlider = [[CUISliderControl alloc] initWithIcon:CUICCIconSun];
        _volumeSlider = [[CUISliderControl alloc] initWithIcon:CUICCIconSpeaker];
        [_panel addSubview:_brightnessSlider];
        [_panel addSubview:_volumeSlider];

        _musicCard = [[CUIMusicCard alloc] initWithFrame:CGRectZero];
        [_panel addSubview:_musicCard];

        [self layoutPanelSubviews];
        [self applyProgress:0];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _panelHeight = self.bounds.size.height * 0.65;
    _panel.frame = CGRectMake(0, self.bounds.size.height,
                              self.bounds.size.width, _panelHeight);
    [self layoutPanelSubviews];
    [self applyProgress:_progress];
}

- (void)layoutPanelSubviews {
    CGFloat w = _panel.bounds.size.width;
    CGFloat h = _panel.bounds.size.height;

    // Glass surface with only top corners rounded.
    _tintView.frame = _panel.bounds;
    if (_blurView) _blurView.frame = _panel.bounds;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:_panel.bounds
                                               byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
                                                     cornerRadii:CGSizeMake(kPanelCornerRadius, kPanelCornerRadius)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    _tintView.layer.mask = mask;
    if (_blurView) _blurView.layer.mask = mask;

    _handleView.center = CGPointMake(w / 2, 9);
    _gearButton.frame = CGRectMake(w - 14 - 34, 14, 34, 34);

    CGFloat side = 56.0;
    CGFloat margin = 24.0;
    CGFloat gap = (w - margin * 2 - side * 4) / 3.0;
    CGFloat rowY = 46.0;
    for (int i = 0; i < (int)_items.count; i++) {
        CGFloat x = margin + i * (side + gap);
        ((UIView *)_items[i]).frame = CGRectMake(x, rowY, side, side);
    }

    CGFloat sliderH = 118.0;
    CGFloat sliderGap = 26.0;
    CGFloat slidersW = side * 2 + sliderGap;
    CGFloat sx = (w - slidersW) / 2.0;
    CGFloat sliderY = rowY + side + 18.0;
    _brightnessSlider.frame = CGRectMake(sx, sliderY, side, sliderH);
    _volumeSlider.frame = CGRectMake(sx + side + sliderGap, sliderY, side, sliderH);

    CGFloat cardY = sliderY + sliderH + 14.0;
    if (cardY + 48 < h - 8) {
        _musicCard.frame = CGRectMake(16, cardY, w - 32, 48);
        _musicCard.hidden = NO;
    } else {
        _musicCard.hidden = YES;
    }
}

#pragma mark - Progress / animation

- (void)prepareForOpen {
    self.hidden = NO;
}

- (void)setOpenProgress:(float)progress {
    _progress = progress;
    [self applyProgress:progress];
}

- (void)applyProgress:(float)p {
    if (p < 0) p = 0;
    if (p > 1) p = 1;

    _dimView.alpha = p * 0.45;

    CGFloat hidden = self.bounds.size.height;
    _panel.transform = CGAffineTransformIdentity;
    _panel.frame = CGRectMake(0, hidden - _panelHeight * p,
                              self.bounds.size.width, _panelHeight);

    // Staggered cascade for rows.
    [self staggerView:_handleView delay:0.00 progress:p];
    [self staggerView:_gearButton delay:0.04 progress:p];
    for (UIView *item in _items) [self staggerView:item delay:0.10 progress:p];
    [self staggerView:_brightnessSlider delay:0.20 progress:p];
    [self staggerView:_volumeSlider delay:0.22 progress:p];
    [self staggerView:_musicCard delay:0.30 progress:p];
}

- (void)staggerView:(UIView *)view delay:(CGFloat)delay progress:(float)p {
    CGFloat window = 0.35;
    CGFloat local = (p - delay) / window;
    if (local < 0) local = 0;
    if (local > 1) local = 1;
    view.alpha = local;
    view.transform = CGAffineTransformMakeTranslation(0, (1 - local) * 12);
}

- (void)openAnimated:(void (^)(void))completion {
    [self animateTo:1.0 completion:completion];
}

- (void)closeAnimated:(void (^)(void))completion {
    __weak CUIControlCenterView *weakSelf = self;
    [self animateTo:0.0 completion:^{
        weakSelf.hidden = YES;
        if (completion) completion();
    }];
}

- (void)animateTo:(float)target completion:(void (^)(void))completion {
    _progress = target;
    CUISpringAnimate(0.4, ^{
        [self applyProgress:target];
    }, ^(BOOL finished) {
        if (completion) completion();
    });
}

#pragma mark - Actions

- (void)gearTap {
    if (self.onGearTap) self.onGearTap();
}

- (void)outsideTap {
    if (self.onOutsideTap) self.onOutsideTap();
}

@end