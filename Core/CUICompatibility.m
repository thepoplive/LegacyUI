#import "CUICompatibility.h"
#import <UIKit/UIKit.h>

BOOL CUIIsiOS6OrEarlier(void) {
    return kCFCoreFoundationVersionNumber < 847.20;
}

void CUISpringAnimate(NSTimeInterval duration,
                      void (^animations)(void),
                      void (^completion)(BOOL finished)) {
    SEL springSelector = @selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:);
    if ([UIView respondsToSelector:springSelector]) {
        [UIView animateWithDuration:duration
                              delay:0.0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:animations
                         completion:completion];
    } else {
        [UIView animateWithDuration:duration
                              delay:0.0
                          options:UIViewAnimationOptionCurveEaseOut
                       animations:animations
                       completion:completion];
    }
}