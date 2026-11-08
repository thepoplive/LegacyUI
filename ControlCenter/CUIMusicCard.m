#import "CUIMusicCard.h"

@interface CUIMusicCard ()
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *nextButton;
@end

@implementation CUIMusicCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        self.layer.cornerRadius = self.bounds.size.width / 2.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        self.layer.borderWidth = 1.0;

        _prevButton = [self buttonWithIcon:CUICCIconPrev action:@selector(prevTap)];
        _playButton = [self buttonWithIcon:CUICCIconPlay action:@selector(playTap)];
        _nextButton = [self buttonWithIcon:CUICCIconNext action:@selector(nextTap)];
        [self addSubview:_prevButton];
        [self addSubview:_playButton];
        [self addSubview:_nextButton];
    }
    return self;
}

- (UIButton *)buttonWithIcon:(CUICCIcon)icon action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:CUICCIconImage(icon, CGSizeMake(20, 20), [UIColor whiteColor])
            forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    self.layer.cornerRadius = w / 2.0;

    CGFloat bw = w - 16.0;
    _prevButton.frame = CGRectMake(8, h / 6.0 - 17, bw, 34);
    _playButton.frame = CGRectMake(8, h / 2.0 - 20, bw, 40);
    _nextButton.frame = CGRectMake(8, h - h / 6.0 - 17, bw, 34);
}

- (void)setPlaying:(BOOL)playing {
    _playing = playing;
    [_playButton setImage:CUICCIconImage(playing ? CUICCIconPause : CUICCIconPlay,
                                         CGSizeMake(24, 24), [UIColor whiteColor])
                 forState:UIControlStateNormal];
}

- (void)prevTap { if (self.onPrevious) self.onPrevious(); }
- (void)playTap { if (self.onPlayPause) self.onPlayPause(); }
- (void)nextTap { if (self.onNext) self.onNext(); }

@end