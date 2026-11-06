#import "CUIVolumePillView.h"

@interface CUIVolumePillView ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *tintView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
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
        _contentView.backgroundColor = [UIColor clearColor];
        [self addSubview:_contentView];

        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_contentView addSubview:_blurView];

        _tintView = [[UIView alloc] init];
        _tintView.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.55];
        [_contentView addSubview:_tintView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"Media Volume";
        _titleLabel.font = [UIFont systemFontOfSize:12];
        _titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [_contentView addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.font = [UIFont systemFontOfSize:13];
        _subtitleLabel.textColor = [UIColor whiteColor];
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.hidden = YES;
        [_contentView addSubview:_subtitleLabel];

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

        _contentView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
        _contentView.layer.borderWidth = 1.0;

        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowOffset = CGSizeMake(0, 6);
        self.layer.shadowRadius = 12.0;

        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, -20);
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    _contentView.frame = self.bounds;
    _blurView.frame = _contentView.bounds;
    _tintView.frame = _contentView.bounds;
    _contentView.layer.cornerRadius = height / 2.0;

    if (_volumeSlider.hidden) {
        _titleLabel.frame = CGRectMake(0, height / 2.0 - 20, width, 14);
        _subtitleLabel.frame = CGRectMake(0, height / 2.0 - 1, width, 16);
    } else {
        _titleLabel.frame = CGRectMake(0, 9, width, 13);
        _subtitleLabel.frame = CGRectZero;
        _volumeSlider.frame = CGRectMake(16, 24, width - 32, height - 32);
    }

    self.layer.shadowPath = [UIBezierPath
        bezierPathWithRoundedRect:self.bounds cornerRadius:height / 2.0].CGPath;
}

- (void)setVolumeLevel:(float)volumeLevel {
    _volumeLevel = volumeLevel;
    _volumeSlider.value = volumeLevel;
}

- (void)configureAsVolume {
    _titleLabel.text = @"Media Volume";
    _volumeSlider.hidden = NO;
    _subtitleLabel.hidden = YES;
    [self setNeedsLayout];
}

- (void)configureAsMuteSilent:(BOOL)silent {
    _volumeSlider.hidden = YES;
    _subtitleLabel.hidden = NO;
    if (silent) {
        _titleLabel.text = @"Silent Mode";
        _subtitleLabel.text = @"Sound Off";
    } else {
        _titleLabel.text = @"Ringer";
        _subtitleLabel.text = @"Sound On";
    }
    [self setNeedsLayout];
}

- (void)updateVolume:(float)level {
    self.volumeLevel = level;
}

#pragma mark - Slider events

- (void)sliderValueChanged:(UISlider *)sender {
    _volumeLevel = sender.value;
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
        self.transform = CGAffineTransformMakeTranslation(0, -20);
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