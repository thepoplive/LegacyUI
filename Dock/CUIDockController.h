#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CUIDockController : NSObject

+ (instancetype)sharedInstance;

- (void)activate;
- (void)deactivate;
- (void)reloadDock;

@end