#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

// Returns a UIVisualEffectView with the given blur style, or nil on iOS 6/7
// where the classes do not exist. Never references the classes statically so
// the dylib loads safely on iOS 6.
typedef enum {
    CUIBlurStyleLight = 1,
    CUIBlurStyleDark = 2
} CUIBlurStyle;

UIView *CUICreateBlurView(CUIBlurStyle style);