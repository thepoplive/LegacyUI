#import <Foundation/Foundation.h>

// Cross-module state set by the Control Center controller
// (avoids import cycles between VolumeHUD and ControlCenter).
extern BOOL g_ccIsOpen;

// Posted with userInfo[@"value"] = @(float) when hardware volume changes
// while the Control Center is open.
extern NSString * const CUICCVolumeChangedNotification;