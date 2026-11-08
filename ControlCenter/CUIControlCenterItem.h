#import <UIKit/UIKit.h>
#import "CUICCIconDrawing.h"

typedef void (^CUICCToggleBlock)(void);

@interface CUIControlCenterItem : UIView

@property (nonatomic, assign) BOOL active;
@property (nonatomic, copy) CUICCToggleBlock onToggle;

- (instancetype)initWithIcon:(CUICCIcon)iconName;

- (void)setActive:(BOOL)active animated:(BOOL)animated;

@end