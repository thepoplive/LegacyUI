#import <UIKit/UIKit.h>

@interface CUIDockView : UIView

// YES -> corner radius is exactly height/2 (perfect capsule, iOS 6 dock style).
@property (nonatomic, assign) BOOL capsuleShape;

@end