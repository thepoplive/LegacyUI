#import <UIKit/UIKit.h>
#import "CUICCIconDrawing.h"

typedef void (^CUICCSliderBlock)(float value);

// Vertical capsule slider with a glyph on top (iOS 11 CC style).
@interface CUISliderControl : UIView

@property (nonatomic, assign) float value; // 0..1
@property (nonatomic, copy) CUICCSliderBlock onValueChange;

- (instancetype)initWithIcon:(CUICCIcon)icon;

@end