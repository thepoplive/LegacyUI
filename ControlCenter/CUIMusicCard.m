#import "CUIMusicCard.h"
#import "../Core/CUICompatibility.h"

@interface CUIMusicCard ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *nextButton;
@end

@implementation CUIMusicCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.06];
        self.layer.cornerRadius = 20.0;
        self.layer.masksToBounds = YES;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.10].CGColor;
        self.layer.borderWidth = 1.0;

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor]; // iOS 6: opaque by default
        _titleLabel.text = @"Music";
        [self addSubview:_titleLabel];

        _artistLabel = [[UILabel alloc] init];
        _artistLabel.font = [UIFont systemFontOfSize:11];
        _artistLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
        _artistLabel.backgroundColor = [UIColor clearColor];
        _artistLabel.text = @"Not playing";
        [self addSubview:_artistLabel];

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
    [button setImage:CUICCIconImage(icon, CGSizeMake(22, 22), [UIColor whiteColor])
            forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat w = self.bounds.size.width;

    CGFloat buttonsRight = 14.0;
    CGFloat bw = 34.0;
    _nextButton.frame = CGRectMake(w - buttonsRight - bw, (h - bw) / 2, bw, bw);
    _playButton.frame = CGRectMake(_nextButton.frame.origin.x - bw - 6, (h - bw) / 2, bw, bw);
    _prevButton.frame = CGRectMake(_playButton.frame.origin.x - bw - 2, (h - bw) / 2, bw, bw);

    CGFloat textX = 18.0;
    CGFloat textW = _prevButton.frame.origin.x - textX - 8.0;
    _titleLabel.frame = CGRectMake(textX, h / 2 - 17, textW, 16);
    _artistLabel.frame = CGRectMake(textX, h / 2 + 1, textW, 14);
}

- (void)setTrackTitle:(NSString *)trackTitle {
    _trackTitle = [trackTitle copy];
    _titleLabel.text = _trackTitle;
}

- (void)setTrackArtist:(NSString *)trackArtist {
    _trackArtist = [trackArtist copy];
    _artistLabel.text = _trackArtist;
}

- (void)setPlaying:(BOOL)playing {
    _playing = playing;
    [_playButton setImage:CUICCIconImage(playing ? CUICCIconPause : CUICCIconPlay,
                                         CGSizeMake(22, 22), [UIColor whiteColor])
                 forState:UIControlStateNormal];
}

- (void)refresh {
    if (!_playing) {
        _titleLabel.text = @"Music";
        _artistLabel.text = @"Not playing";
    }
}

- (void)prevTap { if (self.onPrevious) self.onPrevious(); }
- (void)playTap { if (self.onPlayPause) self.onPlayPause(); }
- (void)nextTap { if (self.onNext) self.onNext(); }

@end