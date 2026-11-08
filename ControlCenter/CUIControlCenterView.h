#import <UIKit/UIKit.h>

@class CUIControlCenterItem;
@class CUISliderControl;
@class CUIMusicCard;

@interface CUIControlCenterView : UIView

@property (nonatomic, readonly) CUIControlCenterItem *wifiItem;
@property (nonatomic, readonly) CUIControlCenterItem *bluetoothItem;
@property (nonatomic, readonly) CUIControlCenterItem *dndItem;
@property (nonatomic, readonly) CUIControlCenterItem *airplaneItem;
@property (nonatomic, readonly) CUISliderControl *brightnessSlider;
@property (nonatomic, readonly) CUISliderControl *volumeSlider;
@property (nonatomic, readonly) CUIMusicCard *musicCard;

@property (nonatomic, copy) NSString *mediaTitle;
@property (nonatomic, copy) NSString *mediaArtist;

- (void)setOpenProgress:(float)progress;      // interactive drag 0..1
- (void)openAnimated:(void (^)(void))completion;
- (void)closeAnimated:(void (^)(void))completion;
- (void)prepareForOpen;

@property (nonatomic, copy) void (^onGearTap)(void);
@property (nonatomic, copy) void (^onLockTap)(void);
@property (nonatomic, copy) void (^onOutsideTap)(void);

@end