#import <Foundation/Foundation.h>

@interface CUIVolumeController : NSObject

+ (instancetype)sharedInstance;

- (void)activate;
- (void)deactivate;
- (void)showVolumePill;
- (void)hideVolumePill;
- (void)updateVolume:(float)volume;

@end