#import <UIKit/UIKit.h>

@class CUIControlCenterView;

@interface CUIControlCenterView : UIView

@property (nonatomic, readonly) NSArray *toggleItems;
@property (nonatomic, readonly) UIView *volumeSliderHost;
@property (nonatomic, readonly) UIView *brightnessSliderHost;

- (void)setOpenProgress:(float)progress;      // interactive drag 0..1
- (void)openAnimated:(void (^)(void))completion;
- (void)closeAnimated:(void (^)(void))completion;
- (void)prepareForOpen;

@property (nonatomic, copy) void (^onGearTap)(void);
@property (nonatomic, copy) void (^onOutsideTap)(void);
@property (nonatomic, copy) void (^onDragDown)(float progress, BOOL finished, float velocity);

@end