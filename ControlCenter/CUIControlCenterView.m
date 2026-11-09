#import "CUIControlCenterView.h"
#import "CUICCIconDrawing.h"
#import "../Core/CUICompatibility.h"
#import "../Core/CUIBlurSupport.h"
#import <math.h>

// MD3 glass palette from ccdemo.html
#define MD3_PURPLE       [UIColor colorWithRed:0xD0/255.0 green:0xBC/255.0 blue:0xFF/255.0 alpha:1.0]
#define MD3_ON_PURPLE    [UIColor colorWithRed:0x38/255.0 green:0x1E/255.0 blue:0x72/255.0 alpha:1.0]
#define MD3_GLASS        [UIColor colorWithWhite:1.0 alpha:0.16]
#define MD3_GLASS_BORDER [UIColor colorWithWhite:1.0 alpha:0.36]
#define MD3_REC_BG       [UIColor colorWithRed:0xFF/255.0 green:0xB4/255.0 blue:0xAB/255.0 alpha:1.0]
#define MD3_REC_ON       [UIColor colorWithRed:0x69/255.0 green:0x00/255.0 blue:0x05/255.0 alpha:1.0]
#define MD3_CREAM        [UIColor colorWithRed:0xE8/255.0 green:0xE0/255.0 blue:0xD4/255.0 alpha:1.0]
#define MD3_DARK         [UIColor colorWithRed:0x1D/255.0 green:0x1B/255.0 blue:0x20/255.0 alpha:1.0]
#define MD3_FILL         [UIColor colorWithWhite:1.0 alpha:0.88]

static const CGFloat kSheetPadX = 10.0;
static const CGFloat kSheetGap = 7.0;

#pragma mark - Tile

@interface CUIMD3Tile : UIView
@property (nonatomic, assign) CUICCIcon icon;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) void (^onTap)(NSString *key);
- (void)setActive:(BOOL)active animated:(BOOL)animated;
- (void)setPressed:(BOOL)pressed;
@end

@implementation CUIMD3Tile {
    UIImageView *_iconView;
    UILabel *_label;
    BOOL _active;
}

- (instancetype)initWithIcon:(CUICCIcon)icon key:(NSString *)key label:(NSString *)text {
    self = [super initWithFrame:CGRectMake(0, 0, 70, 54)];
    if (self) {
        _icon = icon;
        _key = [key copy];
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 16.0;
        self.layer.masksToBounds = YES;

        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _label = [[UILabel alloc] init];
        _label.font = [UIFont systemFontOfSize:10.0];
        _label.textColor = [UIColor whiteColor];
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.adjustsFontSizeToFitWidth = YES;
        _label.minimumFontSize = 7.0;
        [self addSubview:_label];

        [self refreshVisuals];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(fireTap)];
        tap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:tap];
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(pressGesture:)];
        press.cancelsTouchesInView = NO;
        press.minimumPressDuration = 0.0;
        [self addGestureRecognizer:press];

        _label.text = text;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    _iconView.frame = CGRectMake((w - 22) / 2.0, 7.0, 22, 22);
    _label.frame = CGRectMake(1.0, h - 17.0, w - 2.0, 12.0);
    self.layer.cornerRadius = 16.0;
}

- (void)refreshVisuals {
    BOOL rec = [_key isEqualToString:@"rec"];
    self.backgroundColor = _active ? (rec ? MD3_REC_BG : MD3_PURPLE) : [UIColor clearColor];
    UIColor *glyph = _active ? (rec ? MD3_REC_ON : MD3_ON_PURPLE) : [UIColor whiteColor];
    _iconView.image = CUICCIconImage(_icon, _iconView.bounds.size, glyph);
    _label.textColor = glyph;
    self.layer.borderWidth = (_active && !rec) ? 1.0 : 0.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
}

- (void)setActive:(BOOL)active animated:(BOOL)animated {
    if (_active == active) return;
    _active = active;
    if (animated) {
        [UIView animateWithDuration:0.2 delay:0.0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{ [self refreshVisuals]; }
                         completion:nil];
    } else {
        [self refreshVisuals];
    }
}

- (void)setPressed:(BOOL)pressed {
    CGAffineTransform target = pressed
        ? CGAffineTransformMakeScale(0.93, 0.93)
        : CGAffineTransformIdentity;
    [UIView animateWithDuration:0.15 delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction
                     animations:^{ self.transform = target; }
                     completion:nil];
}

- (void)pressGesture:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        [self setPressed:YES];
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled) {
        [self setPressed:NO];
    }
}

- (void)fireTap {
    if (self.onTap) self.onTap(self.key);
}

@end

#pragma mark - Horizontal capsule slider

@interface CUIMD3Slider : UIView
@property (nonatomic, assign) float value; // 0..1
@property (nonatomic, assign) CUICCIcon icon;
@property (nonatomic, copy) void (^onCommit)(float value);
@end

@implementation CUIMD3Slider {
    UIView *_fillView;
    UIView *_notchView;
    UIImageView *_iconView;
}

- (instancetype)initWithIcon:(CUICCIcon)icon {
    self = [super initWithFrame:CGRectMake(0, 0, 100, 34)];
    if (self) {
        _icon = icon;
        _value = 0.5;
        self.backgroundColor = MD3_GLASS;
        self.layer.cornerRadius = 17.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = MD3_GLASS_BORDER.CGColor;
        self.layer.borderWidth = 1.0;

        _fillView = [[UIView alloc] init];
        _fillView.backgroundColor = MD3_FILL;
        [self addSubview:_fillView];

        _notchView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, 12)];
        _notchView.backgroundColor = [MD3_ON_PURPLE colorWithAlphaComponent:0.5];
        _notchView.layer.cornerRadius = 1.5;
        _notchView.userInteractionEnabled = NO;
        [self addSubview:_notchView];

        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(9, 7, 20, 20)];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.userInteractionEnabled = NO;
        [self addSubview:_iconView];

        [self layoutForValue];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.height / 2.0;
    [self layoutForValue];
}

- (void)layoutForValue {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    if (w < 8) return;
    CGFloat fillW = MAX(0.0, MIN(w * _value, w));
    _fillView.frame = CGRectMake(0, 0, fillW, h);
    _notchView.center = CGPointMake(fillW - 7.0, h / 2.0);
    _notchView.hidden = (fillW < 20.0);
    _iconView.frame = CGRectMake(9, (h - 20) / 2.0, 20, 20);
    _iconView.image = CUICCIconImage(_icon, _iconView.bounds.size,
        _value > 0.14 ? MD3_ON_PURPLE : [UIColor whiteColor]);
}

- (void)setValue:(float)value {
    _value = value < 0 ? 0 : (value > 1 ? 1 : value);
    [self layoutForValue];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self updateWithTouch:[touches anyObject]];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self updateWithTouch:[touches anyObject]];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.onCommit) self.onCommit(_value);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.onCommit) self.onCommit(_value);
}

- (void)updateWithTouch:(UITouch *)touch {
    CGPoint point = [touch locationInView:self];
    _value = point.x / self.bounds.size.width;
    if (_value < 0) _value = 0;
    if (_value > 1) _value = 1;
    [self layoutForValue];
}

@end

#pragma mark - Panel

@interface CUIControlCenterView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UIView *cardView;        // tiles card
@property (nonatomic, strong) UIScrollView *tilesScroll;
@property (nonatomic, strong) NSMutableArray *dots;
@property (nonatomic, strong) NSMutableDictionary *tiles; // key -> CUIMD3Tile
@property (nonatomic, strong) CUIMD3Slider *brightSlider;
@property (nonatomic, strong) CUIMD3Slider *volSlider;
@property (nonatomic, strong) UIView *netView;
@property (nonatomic, strong) UILabel *netIP;
@property (nonatomic, strong) UILabel *netDown;
@property (nonatomic, strong) UILabel *netUp;
@property (nonatomic, strong) UIView *mediaCard;
@property (nonatomic, strong) UIView *artView;
@property (nonatomic, strong) UIView *idleRow;
@property (nonatomic, strong) UILabel *idleTitle;
@property (nonatomic, strong) UILabel *idleSub;
@property (nonatomic, strong) UIButton *openMusicButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *favButton;
@property (nonatomic, strong) UIView *seekArea;
@property (nonatomic, strong) CAShapeLayer *wavePlayed;
@property (nonatomic, strong) CAShapeLayer *waveRemain;
@property (nonatomic, strong) UIView *waveThumb;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIView *handleView;
@property (nonatomic, strong) UIButton *gearButton;
@property (nonatomic, strong) UIButton *powerButton;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) NSTimer *toastTimer;
@property (nonatomic, strong) NSArray *staggerViews;
@property (nonatomic, assign) CGFloat panelHeight;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) BOOL mediaFavourite;
@end

// Tile pages: key|title|iconIndex (icon order below).
static NSArray *CUIPagesConfig(void) {
    static NSArray *pages;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pages = @[
            @[@"wifi|Wi-Fi|0", @"bt|Bluetooth|1", @"vpn|VPN|2", @"air|Авиа|3"],
            @[@"dnd|Не бесп.|4", @"rot|Поворот|5", @"torch|Фонарик|6", @"rec|Запись|7"],
            @[@"timer|Таймер|8", @"calc|Калькул.|9", @"cam|Камера|10"]
        ];
    });
    return pages;
}

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

        _tiles = [NSMutableDictionary dictionary];

        _panelHeight = 320.0;
        _panel = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - _panelHeight,
                                                          self.bounds.size.width, _panelHeight)];
        _panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _panel.backgroundColor = [UIColor clearColor];
        [self addSubview:_panel];

        _blurView = CUICreateBlurView(CUIBlurStyleDark);
        _tintView = [[UIView alloc] init];
        // Sheet gradient from the concept: white .28 top -> .08 mid -> .16 bottom,
        // flattened to one translucent wash (no CGGradient on the 3GS panel path).
        _tintView.backgroundColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.16];
        if (_blurView) [_panel addSubview:_blurView];
        [_panel addSubview:_tintView];

        [self buildTopRow];
        [self buildTilesCard];
        [self buildSliders];
        [self buildNetRow];
        [self buildMediaCard];
        [self buildToast];

        _staggerViews = @[_handleView, _gearButton, _powerButton, _cardView,
                          _brightSlider, _volSlider, _netView, _mediaCard];

        [self layoutPanelSubviews];
        [self applyProgress:0];
    }
    return self;
}

#pragma mark Building

- (UIButton *)circleButtonWithIcon:(CUICCIcon)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.layer.cornerRadius = 15.0;
    button.layer.borderColor = MD3_GLASS_BORDER.CGColor;
    button.layer.borderWidth = 1.0;
    button.backgroundColor = MD3_GLASS;
    [button setImage:CUICCIconImage(icon, CGSizeMake(18, 18), [UIColor whiteColor])
            forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)buildTopRow {
    _gearButton = [self circleButtonWithIcon:CUICCIconGear action:@selector(gearTap)];
    _gearButton.frame = CGRectMake(0, 0, 30, 30);
    [_panel addSubview:_gearButton];

    _handleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 34, 4)];
    _handleView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    _handleView.layer.cornerRadius = 2.0;
    _handleView.userInteractionEnabled = NO;
    [_panel addSubview:_handleView];

    _powerButton = [self circleButtonWithIcon:CUICCIconPower action:@selector(powerTap)];
    _powerButton.frame = CGRectMake(0, 0, 30, 30);
    [_panel addSubview:_powerButton];

    // The handle doubles as the close drag target.
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(handlePan:)];
    [_handleView addGestureRecognizer:pan];
    _handleView.userInteractionEnabled = YES;
}

- (void)buildTilesCard {
    _cardView = [[UIView alloc] init];
    _cardView.backgroundColor = MD3_GLASS;
    _cardView.layer.cornerRadius = 22.0;
    _cardView.layer.borderColor = MD3_GLASS_BORDER.CGColor;
    _cardView.layer.borderWidth = 1.0;
    _cardView.layer.masksToBounds = YES;
    [_panel addSubview:_cardView];

    _tilesScroll = [[UIScrollView alloc] init];
    _tilesScroll.pagingEnabled = YES;
    _tilesScroll.showsHorizontalScrollIndicator = NO;
    _tilesScroll.delegate = self;
    [_cardView addSubview:_tilesScroll];

    _dots = [NSMutableArray array];
    for (int i = 0; i < 3; i++) {
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
        dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.4];
        dot.layer.cornerRadius = 2.5;
        dot.userInteractionEnabled = NO;
        [_cardView addSubview:dot];
        [_dots addObject:dot];
    }
    [self syncDots:0];
}

- (void)buildSliders {
    _brightSlider = [[CUIMD3Slider alloc] initWithIcon:CUICCIconSun];
    _brightSlider.onCommit = ^(float value) {
        if (self.onBrightnessCommit) self.onBrightnessCommit(value);
    };
    [_panel addSubview:_brightSlider];

    _volSlider = [[CUIMD3Slider alloc] initWithIcon:CUICCIconSpeaker];
    _volSlider.onCommit = ^(float value) {
        if (self.onVolumeCommit) self.onVolumeCommit(value);
    };
    [_panel addSubview:_volSlider];
}

- (UILabel *)netLabelWithColor:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont systemFontOfSize:11.0];
    label.textColor = color ?: [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumFontSize = 7.0;
    return label;
}

- (void)buildNetRow {
    _netView = [[UIView alloc] init];
    _netView.backgroundColor = MD3_GLASS;
    _netView.layer.cornerRadius = 16.0;
    _netView.layer.borderColor = MD3_GLASS_BORDER.CGColor;
    _netView.layer.borderWidth = 1.0;
    [_panel addSubview:_netView];

    _netIP = [self netLabelWithColor:nil];
    [_netView addSubview:_netIP];
    _netDown = [self netLabelWithColor:[UIColor colorWithRed:0x8F/255.0 green:0xE3/255.0 blue:0xF0/255.0 alpha:1.0]];
    [_netView addSubview:_netDown];
    _netUp = [self netLabelWithColor:[UIColor colorWithRed:0xFF/255.0 green:0xB4/255.0 blue:0xD0/255.0 alpha:1.0]];
    [_netView addSubview:_netUp];
}

- (void)buildMediaCard {
    _mediaCard = [[UIView alloc] init];
    _mediaCard.layer.cornerRadius = 24.0;
    _mediaCard.layer.borderColor = MD3_GLASS_BORDER.CGColor;
    _mediaCard.layer.borderWidth = 1.0;
    _mediaCard.layer.masksToBounds = YES;
    [_panel addSubview:_mediaCard];

    // Album art: layered translucent blobs (safe primitives), concept style.
    _artView = [[UIView alloc] init];
    _artView.backgroundColor = [UIColor colorWithRed:0x17/255.0 green:0x13/255.0 blue:0x1D/255.0 alpha:1.0];
    _artView.userInteractionEnabled = NO;
    [_mediaCard addSubview:_artView];

    UIView *blob1 = [[UIView alloc] init];
    blob1.backgroundColor = [UIColor colorWithRed:0xE2/255.0 green:0x51/255.0 blue:0x8D/255.0 alpha:0.50];
    blob1.layer.cornerRadius = 90.0;
    blob1.userInteractionEnabled = NO;
    blob1.tag = 201;
    [_artView addSubview:blob1];

    UIView *blob2 = [[UIView alloc] init];
    blob2.backgroundColor = [UIColor colorWithRed:0x18/255.0 green:0xB6/255.0 blue:0xC9/255.0 alpha:0.30];
    blob2.layer.cornerRadius = 120.0;
    blob2.userInteractionEnabled = NO;
    blob2.tag = 202;
    [_artView addSubview:blob2];

    // Idle row: "Ничего не играет" + Открыть.
    _idleRow = [[UIView alloc] init];
    _idleRow.userInteractionEnabled = NO;
    [_mediaCard addSubview:_idleRow];

    UIImageView *idleIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 34, 34)];
    idleIcon.contentMode = UIViewContentModeScaleAspectFit;
    idleIcon.image = CUICCIconImage(CUICCIconPlay, idleIcon.bounds.size, [UIColor whiteColor]);
    [_idleRow addSubview:idleIcon];
    _idleRow.userInteractionEnabled = NO;
    idleIcon.tag = 101;

    _idleTitle = [[UILabel alloc] init];
    _idleTitle.font = [UIFont systemFontOfSize:13.0];
    _idleTitle.textColor = [UIColor whiteColor];
    _idleTitle.backgroundColor = [UIColor clearColor];
    [_idleRow addSubview:_idleTitle];
    _idleTitle.text = @"Ничего не играет";

    _idleSub = [[UILabel alloc] init];
    _idleSub.font = [UIFont systemFontOfSize:10.5];
    _idleSub.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    _idleSub.backgroundColor = [UIColor clearColor];
    [_idleRow addSubview:_idleSub];
    _idleSub.text = @"Откройте музыку, чтобы начать";

    _openMusicButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _openMusicButton.backgroundColor = MD3_PURPLE;
    _openMusicButton.titleLabel.font = [UIFont systemFontOfSize:12.0];
    [_openMusicButton setTitle:@"Открыть" forState:UIControlStateNormal];
    [_openMusicButton setTitleColor:MD3_ON_PURPLE forState:UIControlStateNormal];
    _openMusicButton.layer.cornerRadius = 15.0;
    [_openMusicButton addTarget:self action:@selector(openMusicTap)
               forControlEvents:UIControlEventTouchUpInside];
    [_idleRow addSubview:_openMusicButton];
    _idleRow.userInteractionEnabled = YES;

    // Playing layout.
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumFontSize = 9.0;
    [_mediaCard addSubview:_titleLabel];

    _artistLabel = [[UILabel alloc] init];
    _artistLabel.font = [UIFont systemFontOfSize:11.5];
    _artistLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _artistLabel.backgroundColor = [UIColor clearColor];
    _artistLabel.adjustsFontSizeToFitWidth = YES;
    _artistLabel.minimumFontSize = 7.0;
    [_mediaCard addSubview:_artistLabel];

    _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _playButton.backgroundColor = MD3_CREAM;
    _playButton.layer.cornerRadius = 18.0;
    [_playButton addTarget:self action:@selector(playTap)
         forControlEvents:UIControlEventTouchUpInside];
    [_mediaCard addSubview:_playButton];

    _prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_prevButton setImage:CUICCIconImage(CUICCIconPrev, CGSizeMake(18, 18), [UIColor whiteColor])
                  forState:UIControlStateNormal];
    [_prevButton addTarget:self action:@selector(prevTap)
          forControlEvents:UIControlEventTouchUpInside];
    [_mediaCard addSubview:_prevButton];

    _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_nextButton setImage:CUICCIconImage(CUICCIconNext, CGSizeMake(18, 18), [UIColor whiteColor])
                  forState:UIControlStateNormal];
    [_nextButton addTarget:self action:@selector(nextTap)
          forControlEvents:UIControlEventTouchUpInside];
    [_mediaCard addSubview:_nextButton];

    _favButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_favButton addTarget:self action:@selector(favTap)
          forControlEvents:UIControlEventTouchUpInside];
    [_mediaCard addSubview:_favButton];
    [self setMediaFavourite:NO];

    // Wave seekbar.
    _seekArea = [[UIView alloc] init];
    _seekArea.backgroundColor = [UIColor clearColor];
    [_mediaCard addSubview:_seekArea];

    _wavePlayed = [CAShapeLayer layer];
    _wavePlayed.strokeColor = [UIColor whiteColor].CGColor;
    _wavePlayed.fillColor = nil;
    _wavePlayed.lineWidth = 3.0;
    _wavePlayed.lineCap = kCALineCapRound;
    [_seekArea.layer addSublayer:_wavePlayed];

    _waveRemain = [CAShapeLayer layer];
    _waveRemain.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    _waveRemain.fillColor = nil;
    _waveRemain.lineWidth = 3.0;
    _waveRemain.lineCap = kCALineCapRound;
    [_seekArea.layer addSublayer:_waveRemain];

    _waveThumb = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4, 18)];
    _waveThumb.backgroundColor = [UIColor whiteColor];
    _waveThumb.layer.cornerRadius = 2.0;
    _waveThumb.userInteractionEnabled = NO;
    [_seekArea addSubview:_waveThumb];

    UITapGestureRecognizer *seekTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(seekGesture:)];
    [_seekArea addGestureRecognizer:seekTap];
    UIPanGestureRecognizer *seekPan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(seekGesture:)];
    [_seekArea addGestureRecognizer:seekPan];

    _elapsedLabel = [[UILabel alloc] init];
    _elapsedLabel.font = [UIFont systemFontOfSize:9.5];
    _elapsedLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    _elapsedLabel.backgroundColor = [UIColor clearColor];
    [_seekArea addSubview:_elapsedLabel];

    _durationLabel = [[UILabel alloc] init];
    _durationLabel.font = [UIFont systemFontOfSize:9.5];
    _durationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    _durationLabel.backgroundColor = [UIColor clearColor];
    _durationLabel.textAlignment = NSTextAlignmentRight;
    [_seekArea addSubview:_durationLabel];

    _titleLabel.text = @"Нет трека";
    _artistLabel.text = @"";
    [self applyMediaLayout];
}

- (void)buildToast {
    _toastLabel = [[UILabel alloc] init];
    _toastLabel.font = [UIFont systemFontOfSize:11.0];
    _toastLabel.textColor = [UIColor whiteColor];
    _toastLabel.backgroundColor = [UIColor colorWithRed:0x14/255.0 green:0x12/255.0 blue:0x1A/255.0 alpha:0.88];
    _toastLabel.layer.cornerRadius = 12.0;
    _toastLabel.textAlignment = NSTextAlignmentCenter;
    _toastLabel.alpha = 0.0;
    _toastLabel.userInteractionEnabled = NO;
    [_panel addSubview:_toastLabel];
}

#pragma mark Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    _panelHeight = 320.0;
    _panel.frame = CGRectMake(0, self.bounds.size.height - _panelHeight,
                              self.bounds.size.width, _panelHeight);
    [self layoutPanelSubviews];
    [self applyProgress:_progress];
}

- (void)layoutPanelSubviews {
    CGFloat w = _panel.bounds.size.width;
    CGFloat contentW = w - kSheetPadX * 2.0;

    CGRect sheetRect = CGRectMake(0, 0, w, _panelHeight);
    _tintView.frame = sheetRect;
    if (_blurView) _blurView.frame = sheetRect;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:sheetRect
        byRoundingCorners:UIRectCornerTopLeft | UIRectCornerTopRight
        cornerRadii:CGSizeMake(26.0, 26.0)];
    CAShapeLayer *mask = [CAShapeLayer layer];
    mask.path = path.CGPath;
    _tintView.layer.mask = mask;
    if (_blurView) {
        CAShapeLayer *blurMask = [CAShapeLayer layer];
        blurMask.path = path.CGPath;
        _blurView.layer.mask = blurMask;
    }
    _panel.layer.cornerRadius = 26.0; // clip everything to the sheet shape
    _panel.layer.masksToBounds = YES;

    // Top row.
    CGFloat y = 5.0;
    _gearButton.frame = CGRectMake(kSheetPadX, y, 30, 30);
    _powerButton.frame = CGRectMake(w - kSheetPadX - 30, y, 30, 30);
    _handleView.center = CGPointMake(w / 2.0, y + 15.0);
    y += 30 + kSheetGap;

    // Tiles card: page (54) + dots (12) + padding 4*2.
    CGFloat cardH = 54.0 + 12.0 + 8.0;
    _cardView.frame = CGRectMake(kSheetPadX, y, contentW, cardH);
    _tilesScroll.frame = CGRectMake(4, 4, contentW - 8, 54);
    _tilesScroll.contentSize = CGSizeMake(contentW * 3.0, 54.0);
    CGFloat tileW = (contentW - 8.0) / 4.0;
    NSInteger pagesCount = [CUIPagesConfig() count];
    for (int page = 0; page < pagesCount; page++) {
        NSArray *specs = CUIPagesConfig()[page];
        CUICCIcon icons[] = { CUICCIconWiFi, CUICCIconBluetooth, CUICCIconVPN,
                              CUICCIconAirplane, CUICCIconMoon, CUICCIconRotation,
                              CUICCIconTorch, CUICCIconRecord, CUICCIconTimer,
                              CUICCIconCalc, CUICCIconCamera };
        for (int i = 0; i < [specs count]; i++) {
            NSArray *parts = [specs[i] componentsSeparatedByString:@"|"];
            NSString *key = parts[0];
            NSString *title = parts.count > 1 ? parts[1] : key;
            int iconIdx = parts.count > 2 ? [parts[2] intValue] : 0;
            CUIMD3Tile *tile = _tiles[key];
            if (!tile) {
                tile = [[CUIMD3Tile alloc] initWithIcon:icons[iconIdx] key:key label:title];
                __weak CUIControlCenterView *weakSelf = self;
                tile.onTap = ^(NSString *k) {
                    if (weakSelf.onTileTap) weakSelf.onTileTap(k);
                };
                _tiles[key] = tile;
            }
            tile.frame = CGRectMake(page * contentW + i * tileW, 0, tileW, 54.0);
            if (tile.superview != _tilesScroll) [_tilesScroll addSubview:tile];
        }
    }
    NSInteger currentPage = (NSInteger)lround(_tilesScroll.contentOffset.x / contentW);
    CGFloat dotY = 54.0 + 10.0;
    CGFloat dotCx = contentW / 2.0 - 20.0;
    for (int i = 0; i < [_dots count]; i++) {
        BOOL on = (i == currentPage);
        UIView *dot = (UIView *)_dots[i];
        dot.frame = CGRectMake(dotCx + i * 20.0, dotY, on ? 14.0 : 5.0, 5.0);
        dot.backgroundColor = on ? [UIColor whiteColor]
                                 : [UIColor colorWithWhite:1.0 alpha:0.4];
    }
    y += cardH + kSheetGap;

    // Sliders pair.
    CGFloat sliderW = (contentW - 6.0) / 2.0;
    _brightSlider.frame = CGRectMake(kSheetPadX, y, sliderW, 34.0);
    _volSlider.frame = CGRectMake(kSheetPadX + sliderW + 6.0, y, sliderW, 34.0);
    y += 34.0 + kSheetGap;

    // Net row.
    _netView.frame = CGRectMake(kSheetPadX, y, contentW, 26.0);
    _netIP.frame = CGRectMake(6, 4, sliderW, 18.0);
    _netDown.frame = CGRectMake(sliderW + 12, 4, sliderW / 2.0 - 6, 18.0);
    _netUp.frame = CGRectMake(sliderW + sliderW / 2.0 + 18, 4, sliderW / 2.0 - 6, 18.0);
    y += 26.0 + kSheetGap;

    // Media card.
    CGFloat mediaH = _mediaHasTrack ? 104.0 : 56.0;
    _mediaCard.frame = CGRectMake(kSheetPadX, y, contentW, mediaH);
    _artView.frame = _mediaCard.bounds;
    UIView *blob1 = [_artView viewWithTag:201];
    blob1.frame = CGRectMake(_artView.bounds.size.width * 0.30,
                             -_artView.bounds.size.height * 0.30, 180, 180);
    UIView *blob2 = [_artView viewWithTag:202];
    blob2.frame = CGRectMake(-_artView.bounds.size.width * 0.25,
                             _artView.bounds.size.height * 0.20, 220, 220);
    [self applyMediaLayout];

    [self layoutToast];
}

- (void)applyMediaLayout {
    CGFloat w = _mediaCard.bounds.size.width;
    CGFloat h = _mediaCard.bounds.size.height;
    BOOL idle = !_mediaHasTrack;

    _idleRow.hidden = !idle;
    _titleLabel.hidden = idle;
    _artistLabel.hidden = idle;
    _playButton.hidden = idle;
    _prevButton.hidden = idle;
    _nextButton.hidden = idle;
    _favButton.hidden = idle;
    _seekArea.hidden = idle;

    if (idle) {
        _artView.alpha = 0.5;
        _idleRow.frame = CGRectMake(10, 0, w - 20, h);
        UIView *icon = [_idleRow viewWithTag:101];
        icon.frame = CGRectMake(0, (h - 34) / 2.0, 34, 34);
        _idleTitle.frame = CGRectMake(44, h / 2.0 - 16, w - 160, 15);
        _idleSub.frame = CGRectMake(44, h / 2.0 - 1, w - 160, 14);
        _openMusicButton.frame = CGRectMake(w - 92, (h - 30) / 2.0, 82, 30);
        return;
    }
    _artView.alpha = 1.0;

    _titleLabel.frame = CGRectMake(12, 10, w - 12 - 70, 20);
    _artistLabel.frame = CGRectMake(12, 31, w - 12 - 70, 15);
    _playButton.frame = CGRectMake(w - 58 - 12, 10, 58, 44);

    CGFloat cy = h - 34.0; // controls row
    _prevButton.frame = CGRectMake(12, cy, 30, 34);
    _nextButton.frame = CGRectMake(w - 30 - 12 - 34, cy, 30, 34);
    _favButton.frame = CGRectMake(w - 30 - 12, cy, 30, 34);
    _seekArea.frame = CGRectMake(48, cy - 2, w - 48 - 80, 38);
    _elapsedLabel.frame = CGRectMake(0, 22, 44, 12);
    _durationLabel.frame = CGRectMake(_seekArea.bounds.size.width - 44, 22, 44, 12);

    [self redrawWave];
}

- (void)layoutToast {
    CGSize textSize = [_toastLabel.text sizeWithFont:_toastLabel.font];
    CGFloat tw = MAX(60.0, textSize.width + 24.0);
    _toastLabel.frame = CGRectMake((_panel.bounds.size.width - tw) / 2.0, 2.0, tw, 22.0);
}

#pragma mark Wave seek

- (void)redrawWave {
    CGFloat w = _seekArea.bounds.size.width;
    if (w < 10) return;
    CGFloat midY = 10.0;
    CGFloat amp = 3.0;
    CGFloat x = _mediaProgress * w;

    UIBezierPath *played = [UIBezierPath bezierPath];
    [played moveToPoint:CGPointMake(0, midY)];
    for (CGFloat px = 0; px <= x; px += 2.0) {
        CGFloat yy = midY + amp * sinf(px / 16.0 * 6.2832);
        [played addLineToPoint:CGPointMake(px, yy)];
    }
    _wavePlayed.path = played.CGPath;

    UIBezierPath *remain = [UIBezierPath bezierPath];
    CGFloat rx = MIN(w, x + 6.0);
    [remain moveToPoint:CGPointMake(rx, midY)];
    [remain addLineToPoint:CGPointMake(w, midY)];
    _waveRemain.path = remain.CGPath;

    _waveThumb.frame = CGRectMake(MAX(0, x - 2), 1.0, 4, 18);
}

- (void)seekGesture:(UIGestureRecognizer *)g {
    CGPoint point = [g locationInView:_seekArea];
    float progress = point.x / _seekArea.bounds.size.width;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;
    _mediaProgress = progress;
    [self redrawWave];
    if (self.onSeek) self.onSeek(progress);
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat pageW = scrollView.bounds.size.width;
    if (pageW < 1) return;
    NSInteger page = (NSInteger)lround(scrollView.contentOffset.x / pageW);
    for (int i = 0; i < [_dots count]; i++) {
        BOOL on = (i == page);
        UIView *dot = (UIView *)_dots[i];
        CGRect f = dot.frame;
        f.size.width = on ? 14.0 : 5.0;
        dot.frame = f;
        dot.backgroundColor = on ? [UIColor whiteColor]
                                 : [UIColor colorWithWhite:1.0 alpha:0.4];
    }
}

- (void)syncDots:(NSInteger)page {
    for (int i = 0; i < [_dots count]; i++) {
        BOOL on = (i == page);
        UIView *dot = (UIView *)_dots[i];
        CGRect f = dot.frame;
        f.size.width = on ? 14.0 : 5.0;
        dot.frame = f;
        dot.backgroundColor = on ? [UIColor whiteColor]
                                 : [UIColor colorWithWhite:1.0 alpha:0.4];
    }
}

#pragma mark Public setters

- (void)setTile:(NSString *)key active:(BOOL)active animated:(BOOL)animated {
    CUIMD3Tile *tile = _tiles[key];
    [tile setActive:active animated:animated];
}

- (void)setMediaTitle:(NSString *)mediaTitle {
    _mediaTitle = [mediaTitle copy];
    _titleLabel.text = _mediaTitle.length ? _mediaTitle : @"Нет трека";
}

- (void)setMediaArtist:(NSString *)mediaArtist {
    _mediaArtist = [mediaArtist copy];
    _artistLabel.text = _mediaArtist.length ? _mediaArtist : @"";
}

- (void)setMediaPlaying:(BOOL)playing {
    _mediaPlaying = playing;
    UIImage *icon = CUICCIconImage(playing ? CUICCIconPause : CUICCIconPlay,
                                   CGSizeMake(22, 22), MD3_DARK);
    [_playButton setImage:icon forState:UIControlStateNormal];
}

- (void)setMediaHasTrack:(BOOL)hasTrack {
    BOOL changed = (_mediaHasTrack != hasTrack);
    _mediaHasTrack = hasTrack;
    if (changed) [self layoutPanelSubviews];
}

- (void)setMediaProgress:(float)progress {
    _mediaProgress = progress < 0 ? 0 : (progress > 1 ? 1 : progress);
    [self redrawWave];
}

- (void)setMediaElapsed:(NSString *)elapsed {
    _mediaElapsed = [elapsed copy];
    _elapsedLabel.text = elapsed ?: @"0:00";
}

- (void)setMediaDuration:(NSString *)duration {
    _mediaDuration = [duration copy];
    _durationLabel.text = duration ?: @"0:00";
}

- (void)setMediaFavourite:(BOOL)favourite {
    _mediaFavourite = favourite;
    UIColor *tint = favourite
        ? [UIColor colorWithRed:0xFF/255.0 green:0xB4/255.0 blue:0xC8/255.0 alpha:1.0]
        : [UIColor whiteColor];
    [_favButton setImage:CUICCIconImage(CUICCIconHeart, CGSizeMake(18, 18), tint)
                forState:UIControlStateNormal];
}

- (void)setBrightnessValue:(float)value {
    _brightnessValue = value;
    _brightSlider.value = value;
}

- (void)setVolumeValue:(float)value {
    _volumeValue = value;
    _volSlider.value = value;
}

- (void)setNetworkIP:(NSString *)ip download:(NSString *)down upload:(NSString *)up {
    _netIP.text = [NSString stringWithFormat:@"IP %@", ip ?: @"—"];
    _netDown.text = down ? [NSString stringWithFormat:@"↓ %@ Мбит/с", down] : @"↓ —";
    _netUp.text = up ? [NSString stringWithFormat:@"↑ %@ Мбит/с", up] : @"↑ —";
}

#pragma mark Toast

- (void)showToast:(NSString *)text {
    _toastLabel.text = text;
    [self layoutToast];
    [_toastLabel.layer removeAllAnimations];
    _toastLabel.alpha = 0.0;
    [UIView animateWithDuration:0.25 delay:0.0 options:0
                     animations:^{ _toastLabel.alpha = 1.0; }
                     completion:nil];
    [_toastTimer invalidate];
    _toastTimer = [NSTimer scheduledTimerWithTimeInterval:1.2 target:self
                                                  selector:@selector(hideToast)
                                                  userInfo:nil repeats:NO];
}

- (void)hideToast {
    [UIView animateWithDuration:0.25 delay:0.0 options:0
                     animations:^{ _toastLabel.alpha = 0.0; }
                     completion:nil];
}

#pragma mark Actions

- (void)gearTap { if (self.onGearTap) self.onGearTap(); }
- (void)powerTap { if (self.onPowerTap) self.onPowerTap(); }
- (void)outsideTap { if (self.onOutsideTap) self.onOutsideTap(); }
- (void)playTap { if (self.onPlayPause) self.onPlayPause(); }
- (void)prevTap { if (self.onPrevTrack) self.onPrevTrack(); }
- (void)nextTap { if (self.onNextTrack) self.onNextTrack(); }
- (void)openMusicTap { if (self.onOpenMusic) self.onOpenMusic(); }

- (void)favTap {
    _mediaFavourite = !_mediaFavourite;
    [self setMediaFavourite:_mediaFavourite];
    if (self.onFavouriteToggle) self.onFavouriteToggle(_mediaFavourite);
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        if (self.onOutsideTap) self.onOutsideTap(); // drag the handle down = close
    }
}

#pragma mark Progress / animation

static void CUIDumpView(UIView *view, NSMutableString *out, int depth) {
    for (int i = 0; i < depth; i++) [out appendString:@"  "];
    [out appendFormat:@"%@ frame=%@ alpha=%.2f hidden=%d tag=%ld\n",
        NSStringFromClass([view class]), NSStringFromCGRect(view.frame),
        view.alpha, view.hidden, (long)view.tag];
    for (UIView *sub in view.subviews) CUIDumpView(sub, out, depth + 1);
}

- (void)prepareForOpen {
    self.hidden = NO;
    static BOOL dumped = NO;
    if (!dumped) {
        dumped = YES;
        NSMutableString *out = [NSMutableString string];
        [out appendFormat:@"window=%@ level=%.1f selfFrame=%@ hidden=%d\n",
            NSStringFromClass([self.window class]), self.window.windowLevel,
            NSStringFromCGRect(self.frame), self.hidden];
        CUIDumpView(self, out, 1);
        [out writeToFile:@"/var/mobile/legacyui_panel.txt"
              atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}

- (void)setOpenProgress:(float)progress {
    _progress = progress;
    [self applyProgress:progress];
}

- (void)applyProgress:(float)p {
    if (p < 0) p = 0;
    if (p > 1) p = 1;

    _dimView.alpha = p * 0.22;

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

@end
