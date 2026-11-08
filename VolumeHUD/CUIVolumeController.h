#import <Foundation/Foundation.h>

@interface CUIVolumeController : NSObject

+ (instancetype)sharedInstance;

- (void)activate;
- (void)deactivate;
- (void)showVolumePill;
- (void)showMutePillSilent:(BOOL)silent;
- (void)presentVolumeProgress:(float)progress;
- (void)hideVolumePill;
- (void)updateVolume:(float)volume;  // Control Center slider commit
- (float)readSystemVolume;

@end