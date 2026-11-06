#import <Foundation/Foundation.h>

@interface CUIDockController : NSObject

+ (instancetype)sharedInstance;

- (void)activate;
- (void)deactivate;
- (void)reloadDock;

@end