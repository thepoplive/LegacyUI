#import "CUITheme.h"

@implementation CUITheme

+ (instancetype)sharedInstance {
    static CUITheme *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CUITheme alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaultTheme];
    }
    return self;
}

- (void)setupDefaultTheme {
    _primaryTextColor = [UIColor whiteColor];
    _secondaryTextColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    _accentColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    _glassSurfaceColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    _clockAccentColor = [UIColor colorWithRed:1.0 green:0.41 blue:0.7 alpha:1.0];

    _cornerRadius = 20.0;
    _borderOpacity = 0.3;
    _blurRadius = 20.0;

    _animationDuration = 0.3;
}

@end