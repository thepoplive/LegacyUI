#import <UIKit/UIKit.h>

@interface CUITheme : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, strong) UIColor *primaryTextColor;
@property (nonatomic, strong) UIColor *secondaryTextColor;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong) UIColor *glassSurfaceColor;
@property (nonatomic, strong) UIColor *clockAccentColor;

@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderOpacity;
@property (nonatomic, assign) CGFloat blurRadius;

@property (nonatomic, assign) NSTimeInterval animationDuration;

@end