#import "CUIControlCenterView.h"
#import "CUIControlCenterItem.h"
#import "CUISliderControl.h"
#import "CUIMusicCard.h"
#import "CUICCIconDrawing.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIBlurSupport.h"

static const CGFloat kPanelCornerRadius = 28.0;
static const CGFloat kPanelHeightRatio = 0.74;

@interface CUIControlCenterView ()
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *handleView;
@property (nonatomic, strong) UIButton *gearButton;
@property (nonatomic, strong) UIButton *lockButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) CUIControlCenterItem *wifiItem;
@property (nonatomic, strong) CUIControlCenterItem *bluetoothItem;
@property (nonatomic, strong) CUIControlCenterItem *dndItem;
@property (nonatomic, strong) CUIControlCenterItem *airplaneItem;
@property (nonatomic, strong) CUISliderControl *brightnessSlider;
@property (nonatomic, strong) CUISliderControl *volumeSlider;
@property (nonatomic, strong) CUIMusicCard *musicCard;
@property (nonatomic, strong) NSArray *staggerViews;
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

        _panelHeight = self.bounds.size.height * kPanelHeightRatio;
        // Fixed open position; movement is transform-only (fast on SGX535).
        _panel = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - _panelHeight,
                                                          self.bounds.size.width, _panelHeight)];
        _panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _panel.backgroundColor = [UIColor clearColor];
        [self addSubview:_panel];

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

        // Screen lock button, mirrored against the gear (opposite corner).
        _lockButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_lockButton setImage:CUICCIconImage(CUICCIconLock, CGSizeMake(24, 24),
                                              [UIColor colorWithWhite:1.0 alpha:0.8])
                   forState:UIControlStateNormal];
        [_lockButton addTarget:self action:@selector(lockTap)
             forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:_lockButton];

        // Track info in the header, centered between the handle and the gear.
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [_panel addSubview:_titleLabel];

        _artistLabel = [[UILabel alloc] init];
        _artistLabel.font = [UIFont systemFontOfSize:11];
        _artistLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
        _artistLabel.backgroundColor = [UIColor clearColor];
        _artistLabel.textAlignment = NSTextAlignmentCenter;
        [_panel addSubview:_artistLabel];

        // Toggle row: Wi-Fi, Bluetooth, DND, Airplane.
        _wifiItem = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconWiFi];
        _bluetoothItem = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconBluetooth];
        _dndItem = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconMoon];
        _airplaneItem = [[CUIControlCenterItem alloc] initWithIcon:CUICCIconAirplane];
        for (UIView *item in @[_wifiItem, _bluetoothItem, _dndItem, _airplaneItem]) {
            [_panel addSubview:item];
        }

        // Controls row: brightness | volume | music square.
        _brightnessSlider = [[CUISliderControl alloc] initWithIcon:CUICCIconSun];
        _volumeSlider = [[CUISliderControl alloc] initWithIcon:CUICCIconSpeaker];
        _musicCard = [[CUIMusicCard alloc] initWithFrame:CGRectZero];
        [_panel addSubview:_brightnessSlider];
        [_panel addSubview:_volumeSlider];
        [_panel addSubview:_musicCard];

        _staggerViews = @[_handleView, _gearButton, _lockButton,
                          _wifiItem, _bluetoothItem, _dndItem, _airplaneItem,
                          _brightnessSlider, _volumeSlider, _musicCard];

        [self layoutPanelSubviews];
        [self applyProgress:0];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _panelHeight = self.bounds.size.height * kPanelHeightRatio;
    _panel.frame = CGRectMake(0, self.bounds.size.height - _panelHeight,
                              self.bounds.size.width, _panelHeight);
    [self layoutPanelSubviews];
    [self applyProgress:_progress];
}

- (void)layoutPanelSubviews {
    CGFloat w = _panel.bounds.size.width;
    CGFloat h = _panel.bounds.size.height;

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
    _lockButton.frame = CGRectMake(14, 14, 34, 34);

    _titleLabel.frame = CGRectMake(52, 16, w - 52 - 52, 15);
    _artistLabel.frame = CGRectMake(52, 33, w - 52 - 52, 13);

    CGFloat side = 56.0;
    CGFloat margin = 24.0;
    CGFloat gap = (w - margin * 2 - side * 4) / 3.0;
    CGFloat rowY = 56.0;
    NSArray *items = @[_wifiItem, _bluetoothItem, _dndItem, _airplaneItem];
    for (int i = 0; i < 4; i++) {
        CGFloat x = margin + i * (side + gap);
        ((UIView *)items[i]).frame = CGRectMake(x, rowY, side, side);
    }

    CGFloat controlH = MIN(h - rowY - side - 40.0, 168.0);
    CGFloat controlGap = 22.0;
    CGFloat controlsW = side * 3 + controlGap * 2;
    CGFloat cx = (w - controlsW) / 2.0;
    CGFloat controlY = rowY + side + 20.0;
    _brightnessSlider.frame = CGRectMake(cx, controlY, side, controlH);
    _volumeSlider.frame = CGRectMake(cx + side + controlGap, controlY, side, controlH);
    _musicCard.frame = CGRectMake(cx + (side + controlGap) * 2, controlY, side, controlH);
}

#pragma mark - Media info

- (void)setMediaTitle:(NSString *)mediaTitle {
    _mediaTitle = [mediaTitle copy];
    _titleLabel.text = _mediaTitle.length ? _mediaTitle : @"Control Center";
}

- (void)setMediaArtist:(NSString *)mediaArtist {
    _mediaArtist = [mediaArtist copy];
    _artistLabel.text = _mediaArtist.length ? _mediaArtist : @"LegacyUI";
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

    // Transform-only movement: the panel frame never changes -> the glass
    // mask never re-renders, keeping the drag smooth on the 3GS GPU.
    _panel.transform = CGAffineTransformMakeTranslation(0, (1.0 - p) * _panelHeight);

    NSUInteger count = [_staggerViews count];
    for (NSUInteger i = 0; i < count; i++) {
        UIView *view = _staggerViews[i];
        CGFloat delay = 0.04 * i;
        CGFloat local = (p - delay) / 0.4;
        if (local < 0) local = 0;
        if (local > 1) local = 1;
        view.alpha = local;
        view.transform = CGAffineTransformMakeTranslation(0, (1 - local) * 10);
    }
}

- (void)openAnimated:(void (^)(void))completion {
    _progress = 1.0;
    CUISpringAnimate(0.4, ^{
        [self applyProgress:1.0];
    }, ^(BOOL finished) {
        if (completion) completion();
    });
}

- (void)closeAnimated:(void (^)(void))completion {
    _progress = 0.0;
    __weak CUIControlCenterView *weakSelf = self;
    CUISpringAnimate(0.35, ^{
        [weakSelf applyProgress:0.0];
    }, ^(BOOL finished) {
        weakSelf.hidden = YES;
        if (completion) completion();
    });
}

#pragma mark - Actions

- (void)gearTap {
    if (self.onGearTap) self.onGearTap();
}

- (void)lockTap {
    if (self.onLockTap) self.onLockTap();
}

- (void)outsideTap {
    if (self.onOutsideTap) self.onOutsideTap();
}

@end