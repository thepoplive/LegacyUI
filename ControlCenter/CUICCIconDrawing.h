#import <UIKit/UIKit.h>

// Vector-drawn glyphs (no SF Symbols on iOS 6, no bundled assets).
// Renders into cached UIImages tinted with the given color.
typedef enum {
    CUICCIconWiFi = 0,
    CUICCIconBluetooth,
    CUICCIconAirplane,
    CUICCIconMoon,
    CUICCIconSun,
    CUICCIconSpeaker,
    CUICCIconPlay,
    CUICCIconPause,
    CUICCIconPrev,
    CUICCIconNext,
    CUICCIconGear
} CUICCIcon;

UIImage *CUICCIconImage(CUICCIcon icon, CGSize size, UIColor *color);