#import <Foundation/Foundation.h>

// Service bridge for the Control Center (iOS 6 first, iOS 8 where possible).
// All private classes are resolved at runtime; every selector is checked
// against the verified iOS 6.1 / 8.0 class-dump headers.

@interface CUICCServiceBridge : NSObject

+ (instancetype)sharedBridge;

// One-shot runtime verification: /var/mobile/.legacyui_probe marker ->
// dumps real method lists of the service classes to
// /var/mobile/legacyui_probe.txt (ground truth from the actual binary).
+ (void)probeClassesIfNeeded;

#pragma mark Radios

- (BOOL)bluetoothEnabled;
- (void)setBluetoothEnabled:(BOOL)enabled;

- (BOOL)airplaneMode;
- (void)setAirplaneMode:(BOOL)enabled;

- (BOOL)wiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
- (BOOL)wiFiPowered; // live radio power (glow source)

- (BOOL)doNotDisturbEnabled;
- (void)setDoNotDisturbEnabled:(BOOL)enabled;

- (BOOL)torchEnabled;          // iOS 8 CC driver; NO on iOS 6 (no LED)
- (void)setTorchEnabled:(BOOL)enabled;

- (BOOL)orientationLocked;     // iOS 8 CC driver; NO on iOS 6
- (void)setOrientationLocked:(BOOL)locked;

#pragma mark Brightness (verified: SpringBoard setBacklightFactor:, ivar _currentBacklightLevel)

- (float)brightness;
- (void)setBrightness:(float)level;

#pragma mark Media (verified: SBMediaController)

- (NSString *)mediaTitle;
- (NSString *)mediaArtist;
- (BOOL)mediaPlaying;
- (void)mediaTogglePlayPause;
- (void)mediaSkip:(int)direction; // -1 previous, +1 next
- (float)mediaTrackProgress;                 // 0..1
- (void)mediaSetTrackProgress:(float)progress;
- (NSString *)mediaTrackElapsedString;       // "m:ss"
- (NSString *)mediaTrackDurationString;      // "m:ss"

@end