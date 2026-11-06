#import "CUIVolumeController.h"
#import "../Core/CUIConfiguration.h"
#import <AVFoundation/AVAudioSession.h>
#import <MediaPlayer/MediaPlayer.h>

static CUIVolumeController *_sharedInstance = nil;
static CUIVolumePillView *_volumePillView = nil;

@interface CUIVolumeController ()
@property (nonatomic, assign) float currentVolume;
@property (nonatomic, assign) BOOL isVolumeHUDVisible;
@end

@implementation CUIVolumeController

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[CUIVolumeController alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentVolume = 0.5;
        _isVolumeHUDVisible = NO;
    }
    return self;
}

- (void)activate {
    CUIConfiguration *config = [CUIConfiguration sharedInstance];
    if (!config.enabled || !config.volumeHUDEnabled || !config.volumePillEnabled) {
        [self deactivate];
        return;
    }

    if (_volumePillView) return;

    [self setupVolumePill];
    [self setupVolumeObserver];

    NSLog(@"[LegacyUI] Volume HUD activated");
}

- (void)deactivate {
    if (_volumePillView) {
        [_volumePillView removeFromSuperview];
        _volumePillView = nil;
    }
    [self removeVolumeObserver];
}

- (void)setupVolumePill {
    if (_volumePillView) return;

    CGFloat screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat pillWidth = MIN(screenWidth - 40, 320);
    CGFloat pillHeight = 80;

    CGRect frame = CGRectMake((screenWidth - pillWidth) / 2, 60, pillWidth, pillHeight);
    _volumePillView = [[CUIVolumePillView alloc] initWithFrame:frame];
    _volumePillView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (keyWindow) {
        [keyWindow addSubview:_volumePillView];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            if (window && !_volumePillView.superview) {
                [window addSubview:_volumePillView];
            }
        });
    }
}

- (void)setupVolumeObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVAudioSessionRouteChangeNotification"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:@"AVAudioSessionInterruptionNotification"
                                               object:nil];

    [self observeVolumeUsingMPVolumeView];
}

- (void)observeVolumeUsingMPVolumeView {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *view in [[[UIApplication sharedApplication] windows] copy]) {
            for (UIView *subview in view.subviews) {
                if ([NSStringFromClass([subview class]) containsString:@"MPVolumeView"]) {
                    [subview setHidden:YES];
                    [self setupVolumeSliderObserver:subview];
                    return;
                }
            }
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self observeVolumeUsingMPVolumeView];
        });
    });
}

- (void)setupVolumeSliderObserver:(UIView *)volumeView {
    for (UIView *slider in volumeView.subviews) {
        if ([slider isKindOfClass:[UISlider class]]) {
            [(UISlider *)slider addTarget:self
                                   action:@selector(systemVolumeChanged:)
                         forControlEvents:UIControlEventValueChanged];
            NSLog(@"[LegacyUI] Volume slider observer attached");
            break;
        }
    }
}

- (void)systemVolumeChanged:(UISlider *)sender {
    _currentVolume = sender.value;
    [self showVolumePill];
    [_volumePillView updateVolume:_currentVolume];
}

- (void)volumeChanged:(NSNotification *)notification {
    [self showVolumePill];
}

- (void)removeVolumeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"AVAudioSessionRouteChangeNotification"
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"AVAudioSessionInterruptionNotification"
                                                  object:nil];
}

- (void)showVolumePill {
    if (!_volumePillView) return;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSString *category = session.category;

    CUIVolumeType volumeType = CUIVolumeTypeMedia;
    if ([category isEqualToString:@"AVAudioSessionCategoryPlayback"]) {
        volumeType = CUIVolumeTypeMedia;
    } else if ([category isEqualToString:@"AVAudioSessionCategoryRingtone"]) {
        volumeType = CUIVolumeTypeRinger;
    } else if ([category isEqualToString:@"AVAudioSessionCategoryVoiceChat"]) {
        volumeType = CUIVolumeTypeCall;
    } else if ([category isEqualToString:@"AVAudioSessionCategoryAlert"]) {
        volumeType = CUIVolumeTypeAlarm;
    }

    _volumePillView.volumeType = volumeType;
    _volumePillView.volumeLevel = _currentVolume;
    [_volumePillView showWithAnimation];
}

- (void)hideVolumePill {
    [_volumePillView hideWithAnimation];
}

- (void)updateVolume:(float)volume {
    _currentVolume = volume;
    if (_volumePillView) {
        [_volumePillView updateVolume:volume];
    }
}

- (void)dealloc {
    [self removeVolumeObserver];
}

@end