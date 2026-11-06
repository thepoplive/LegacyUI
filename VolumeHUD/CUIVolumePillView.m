#import "CUIVolumePillView.h"
#import "../Core/CUITheme.h"

@interface CUIVolumePillView ()
@property (nonatomic, strong) UIView *glassContainer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *percentLabel;
@property (nonatomic, strong) UIProgressView *volumeProgress;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong) NSTimer *dismissTimer;
@end

@implementation CUIVolumePillView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupViews];
        [self setupDefaultVolumeType];
    }
    return self;
}

- (void)setupDefaultVolumeType {
    _volumeType = CUIVolumeTypeMedia;
    _volumeLevel = 0.5;
    _isVisible = NO;
}

- (void)setupViews {
    _glassContainer = [[UIView alloc] init];
    _glassContainer.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.85];
    _glassContainer.layer.cornerRadius = 16.0;
    _glassContainer.layer.masksToBounds = YES;
    [self addSubview:_glassContainer];

    _iconView = [[UIImageView alloc] init];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = [UIColor whiteColor];
    [_glassContainer addSubview:_iconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _titleLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    _titleLabel.text = @"Media Volume";
    [_glassContainer addSubview:_titleLabel];

    _percentLabel = [[UILabel alloc] init];
    _percentLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightBold];
    _percentLabel.textColor = [UIColor whiteColor];
    _percentLabel.text = @"50%";
    [_glassContainer addSubview:_percentLabel];

    _volumeProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _volumeProgress.progressTintColor = [UIColor whiteColor];
    _volumeProgress.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    _volumeProgress.progress = 0.5;
    [_glassContainer addSubview:_volumeProgress];

    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 12;
    self.layer.shadowOpacity = 0.4;
    self.layer.masksToBounds = NO;
    self.alpha = 0;
    self.transform = CGAffineTransformMakeTranslation(0, -20);
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat padding = 16;
    CGFloat width = self.bounds.size.width;

    _glassContainer.frame = CGRectMake(0, 0, width, self.bounds.size.height);

    _iconView.frame = CGRectMake(padding, padding, 24, 24);
    _titleLabel.frame = CGRectMake(padding + 32, padding + 4, width - 48 - 60, 16);
    _percentLabel.frame = CGRectMake(width - padding - 60, padding, 60, 32);
    _volumeProgress.frame = CGRectMake(padding, padding + 36, width - padding * 2, 4);
}

- (void)setVolumeType:(CUIVolumeType)volumeType {
    _volumeType = volumeType;

    NSString *titleText = @"Media Volume";
    switch (volumeType) {
        case CUIVolumeTypeMedia:
            titleText = @"Media Volume";
            _iconView.image = [UIImage imageNamed:@"Speaker"];
            break;
        case CUIVolumeTypeRinger:
            titleText = @"Ringer Volume";
            _iconView.image = [UIImage imageNamed:@"Ring"];
            break;
        case CUIVolumeTypeCall:
            titleText = @"Call Volume";
            _iconView.image = [UIImage imageNamed:@"Phone"];
            break;
        case CUIVolumeTypeAlarm:
            titleText = @"Alarm Volume";
            _iconView.image = [UIImage imageNamed:@"Alarm"];
            break;
    }

    _titleLabel.text = titleText;
}

- (void)setVolumeLevel:(float)volumeLevel {
    _volumeLevel = volumeLevel;
    _percentLabel.text = [NSString stringWithFormat:@"%.0f%%", volumeLevel * 100];
    _volumeProgress.progress = volumeLevel;
}

- (void)updateVolume:(float)level {
    self.volumeLevel = level;
}

- (void)showWithAnimation {
    if (_isVisible) return;

    _isVisible = YES;
    [self invalidateDismissTimer];

    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];

    [self scheduleDismissTimer];
}

- (void)hideWithAnimation {
    if (!_isVisible) return;

    _isVisible = NO;
    [self invalidateDismissTimer];

    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.alpha = 0;
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