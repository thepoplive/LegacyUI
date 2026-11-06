#import <UIKit/UIKit.h>

@interface CUIDockView : UIView

@property (nonatomic, strong, readonly) UIView *glassBackgroundView;
@property (nonatomic, assign) CGFloat dockHeight;
@property (nonatomic, assign) CGFloat dockCornerRadius;

- (void)applyGlassStyle;
- (void)updateForOrientation:(UIInterfaceOrientation)orientation;

@end