#import "CUIVolumePillView.h"

@interface CUIVolumePillView ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong) NSTimer *dismissTimer;
@end

@implementation CUIVolumePillView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isVisible = NO;
        _volumeLevel = 0.5;

        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];

        _contentView = [[UIView alloc] init];
        _contentView.layer.masksToBounds = YES;
        _contentView.layer.cornerRadius = 16.0;
        _contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:_contentView];

        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_contentView addSubview:_blurView];

        _tintView = [[UIView alloc] init];
        _tintView.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.55];
        [_contentView addSubview:_tintView];

        _iconLabel = [[UILabel alloc] init];
        _iconLabel.text = @"\U0001F50A";
        _iconLabel.font = [UIFont systemFontOfSize:20];
        [_contentView addSubview:_iconLabel];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"Media Volume";
        _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        [_contentView addSubview:_titleLabel];

        _percentLabel = [[UILabel alloc] init];
        _percentLabel.text = @"50%";
        _percentLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
        _percentLabel.textColor = [UIColor whiteColor];
        _percentLabel.textAlignment = NSTextAlignmentRight;
        [_contentView addSubview:_percentLabel];

        _volumeSlider = [[UISlider alloc] init];
        [_volumeSlider setMinimumTrackTintColor:[UIColor whiteColor]];
        [_volumeSlider setMaximumTrackTintColor:[UIColor colorWithWhite:1.0 alpha:0.25]];
        [_volumeSlider setThumbTintColor:[UIColor whiteColor]];
        _volumeSlider.value = _volumeLevel;
        [_volumeSlider addTarget:self action:@selector(sliderValueChanged:)
                forControlEvents:UIControlEventValueChanged];
        [_volumeSlider addTarget:self action:@selector(sliderTouchDown:)
                forControlEvents:UIControlEventTouchDown];
        [_volumeSlider addTarget:self action:@selector(sliderTouchEnded:)
                forControlEvents:UIControlEventTouchUpInside];
        [_volumeSlider addTarget:self action:@selector(sliderTouchEnded:)
                forControlEvents:UIControlEventTouchUpOutside];
        [_volumeSlider addTarget:self action:@selector(sliderTouchEnded:)
                forControlEvents:UIControlEventTouchCancel];
        [_contentView addSubview:_volumeSlider];

        _contentView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
        _contentView.layer.borderWidth = 1.0;

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowOffset = CGSizeMake(0, 8);
        self.layer.shadowRadius = 14.0;

        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, -24);
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 14.0;
    CGFloat width = self.bounds.size.width;

    _contentView.frame = self.bounds;
    _blurView.frame = _contentView.bounds;
    _tintView.frame = _contentView.bounds;

    _iconLabel.frame = CGRectMake(padding, padding, 24, 24);
    _titleLabel.frame = CGRectMake(padding + 30, padding + 5, width - padding * 2 - 30 - 74, 16);
    _percentLabel.frame = CGRectMake(width - padding - 74, padding + 2, 74, 24);
    _volumeSlider.frame = CGRectMake(padding, padding + 34, width - padding * 2, 24);
}

- (void)setVolumeLevel:(float)volumeLevel {
    _volumeLevel = volumeLevel;
    _percentLabel.text = [NSString stringWithFormat:@"%.0f%%", volumeLevel * 100];
    _volumeSlider.value = volumeLevel;
}

- (void)setVolumeTitle:(NSString *)volumeTitle {
    _volumeTitle = [volumeTitle copy];
    _titleLabel.text = _volumeTitle;
}

- (void)updateVolume:(float)level {
    self.volumeLevel = level;
}

#pragma mark - Slider events

- (void)sliderValueChanged:(UISlider *)sender {
    _volumeLevel = sender.value;
    _percentLabel.text = [NSString stringWithFormat:@"%.0f%%", sender.value * 100];
    if (self.onVolumeUserChange) self.onVolumeUserChange(sender.value);
    [self scheduleDismissTimer];
}

- (void)sliderTouchDown:(UISlider *)sender {
    [self invalidateDismissTimer];
}

- (void)sliderTouchEnded:(UISlider *)sender {
    [self scheduleDismissTimer];
}

#pragma mark - Show / hide

- (void)showWithAnimation {
    if (!_isVisible) {
        _isVisible = YES;
        [UIView animateWithDuration:0.35
                              delay:0.0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.alpha = 1.0;
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    [self scheduleDismissTimer];
}

- (void)hideWithAnimation {
    if (!_isVisible) return;
    _isVisible = NO;
    [self invalidateDismissTimer];
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, -24);
    } completion:nil];
}

- (void)scheduleDismissTimer {
    [self invalidateDismissTimer];
    _dismissTimer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                      target:self
                                                    selector:@selector(hideWithAnimation)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)invalidateDismissTimer {
    if (_dismissTimer) {
        [_dismissTimer invalidate];
        _dismissTimer = nil;
    }
}

- (void)dealloc {
    [self invalidateDismissTimer];
}

@end