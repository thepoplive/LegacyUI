#import <UIKit/UIKit.h>
#import "CUICCIconDrawing.h"

typedef void (^CUICCSliderBlock)(float value);

// Vertical capsule slider with a glyph on top (iOS 11 CC style).
@interface CUISliderControl : UIView

@property (nonatomic, assign) float value; // 0..1
@property (nonatomic, copy) CUICCSliderBlock onValueChange;   // live drag
@property (nonatomic, copy) CUICCSliderBlock onValueCommit;   // finger released

- (instancetype)initWithIcon:(CUICCIcon)icon;

@end