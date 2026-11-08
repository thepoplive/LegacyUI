#import <Foundation/Foundation.h>

// iOS 7.0 = CoreFoundation 847.20 (see CoreFoundation Version Table).
BOOL CUIIsiOS6OrEarlier(void);

// Safe animation wrapper: uses spring damping on iOS 7+, plain animation on iOS 6.
void CUISpringAnimate(NSTimeInterval duration,
                      void (^animations)(void),
                      void (^completion)(BOOL finished));