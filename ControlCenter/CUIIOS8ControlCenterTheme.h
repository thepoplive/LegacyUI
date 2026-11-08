#import <Foundation/Foundation.h>

// iOS 8 path: instead of the custom overlay panel (iOS 6 only), restyle the
// NATIVE Control Center into the LegacyUI Liquid Glass look. All native
// functionality (toggles, sliders, media, AirDrop) keeps working — only the
// visuals change. No-ops on iOS 6.
void CUIIOS8InstallControlCenterTheme(void);
