#import <Foundation/Foundation.h>

@interface CUIControlCenterController : NSObject

+ (instancetype)sharedInstance;

- (void)activate;
- (void)deactivate;

- (BOOL)isOpen;
- (void)openControlCenter;
- (void)closeControlCenter;
- (void)updateGrabberVisibility;

@end