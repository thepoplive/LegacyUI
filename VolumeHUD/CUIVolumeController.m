#import "CUIVolumeController.h"
#import "CUIVolumePillView.h"
#import "../Core/CUIConfiguration.h"
#import <MediaPlayer/MediaPlayer.h>
#import <math.h>

@interface CUIVolumeController ()
@property (nonatomic, strong) MPVolumeView *volumeViewHack;
@property (nonatomic, strong) UISlider *systemVolumeSlider;
@property (nonatomic, strong) CUIVolumePillView *pill;
@property (nonatomic, assign) float currentVolume;
@end

@implementation CUIVolumeController

+ (instancetype)sharedInstance {
    static CUIVolumeController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CUIVolumeController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentVolume = 0.5;
    }
    return self;
}

- (BOOL)moduleWanted {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    return config.enabled && config.volumeHUDEnabled && config.volumePillEnabled;
}

- (void)activate {
    if (![self moduleWanted]) {
        [self deactivate];
        return;
    }
    [self installVolumeObserverIfNeeded];
}

- (void)deactivate {
    [self.pill hideWithAnimation];
}

- (UIWindow *)hostWindow {
    UIWindow *key = [[UIApplication sharedApplication] keyWindow];
    if (key) return key;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window) return window;
    }
    return nil;
}

- (void)installVolumeObserverIfNeeded {
    if (_systemVolumeSlider) return;

    UIWindow *window = [self hostWindow];
    if (!window) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self activate];
        });
        return;
    }

    _volumeViewHack = [[MPVolumeView alloc] initWithFrame:CGRectMake(-2000, -2000, 60, 30)];
    [window addSubview:_volumeViewHack];

    for (UIView *sub in _volumeViewHack.subviews) {
        if ([sub isKindOfClass:[UISlider class]]) {
            _systemVolumeSlider = (UISlider *)sub;
            break;
        }
    }

    if (_systemVolumeSlider) {
        _currentVolume = _systemVolumeSlider.value;
        [_systemVolumeSlider addTarget:self
                                action:@selector(systemVolumeChanged:)
                      forControlEvents:UIControlEventValueChanged];
        NSLog(@"[LegacyUI] Volume observer attached");
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self installVolumeObserverIfNeeded];
        });
    }
}

- (void)systemVolumeChanged:(UISlider *)sender {
    _currentVolume = sender.value;
    [self presentPill];
}

- (void)presentPill {
    if (![self moduleWanted]) return;

    UIWindow *window = [self hostWindow];
    if (!window) return;

    if (!_pill) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        CGFloat width = MIN(bounds.size.width - 40.0, 320.0);
        _pill = [[CUIVolumePillView alloc] initWithFrame:CGRectMake(
            (bounds.size.width - width) / 2.0, 52.0, width, 84.0)];

        __weak CUIVolumeController *weakSelf = self;
        _pill.onVolumeUserChange = ^(float volume) {
            [weakSelf setSystemVolume:volume];
        };
    }

    if (_pill.superview != window) {
        [_pill removeFromSuperview];
        [window addSubview:_pill];
    }

    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat width = MIN(bounds.size.width - 40.0, 320.0);
    _pill.frame = CGRectMake((bounds.size.width - width) / 2.0, 52.0, width, 84.0);

    _pill.volumeLevel = _currentVolume;
    [_pill showWithAnimation];
}

- (void)setSystemVolume:(float)volume {
    if (fabsf(volume - _currentVolume) < 0.001) return;
    _currentVolume = volume;
    if (_systemVolumeSlider) {
        _systemVolumeSlider.value = volume;
    }
}

- (void)showVolumePill {
    [self presentPill];
}

- (void)hideVolumePill {
    [_pill hideWithAnimation];
}

- (void)updateVolume:(float)volume {
    _currentVolume = volume;
    _pill.volumeLevel = volume;
}

@end