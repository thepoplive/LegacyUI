#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CUIVolumeType) {
    CUIVolumeTypeMedia,
    CUIVolumeTypeRinger,
    CUIVolumeTypeCall,
    CUIVolumeTypeAlarm
};

@interface CUIVolumePillView : UIView

@property (nonatomic, assign) CUIVolumeType volumeType;
@property (nonatomic, assign) float volumeLevel;
@property (nonatomic, copy) NSString *volumeLabel;

- (void)showWithAnimation;
- (void)hideWithAnimation;
- (void)updateVolume:(float)level;

@end