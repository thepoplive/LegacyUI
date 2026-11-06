#import <UIKit/UIKit.h>

@interface CUIGlassView : UIView

@property (nonatomic, assign) CGFloat glassOpacity;
@property (nonatomic, assign) CGFloat blurRadius;
@property (nonatomic, assign) CGFloat cornerRadiusValue;
@property (nonatomic, assign) BOOL showBorder;
@property (nonatomic, assign) BOOL showHighlight;

- (void)applyGlassStyle;

@end