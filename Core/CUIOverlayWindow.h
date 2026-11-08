#import <UIKit/UIKit.h>

// Shared full-screen overlay window above everything (apps, lock screen).
// Touch-transparent: only views added inside it receive touches.
UIWindow *CUISharedOverlayWindow(void);