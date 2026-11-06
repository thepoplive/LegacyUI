#import <UIKit/UIKit.h>

typedef void (^CUIVolumeChangeBlock)(float volume);

@interface CUIVolumePillView : UIView

@property (nonatomic, assign) float volumeLevel;
@property (nonatomic, copy) NSString *volumeTitle;
@property (nonatomic, copy) CUIVolumeChangeBlock onVolumeUserChange;

- (void)showWithAnimation;
- (void)hideWithAnimation;
- (void)updateVolume:(float)level;

@end