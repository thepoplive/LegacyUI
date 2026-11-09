#import <UIKit/UIKit.h>

@class CUIMD3Tile;

// MD3 glass Control Center (per ccdemo.html concept):
// top row (gear / handle / power), scrollable tile pages with dots,
// brightness+volume capsule pair, network row, media card with wave seek.
@interface CUIControlCenterView : UIView

#pragma mark Machinery (unchanged contract with the controller)

- (void)setOpenProgress:(float)progress;      // interactive drag 0..1
- (void)openAnimated:(void (^)(void))completion;
- (void)closeAnimated:(void (^)(void))completion;
- (void)prepareForOpen;

@property (nonatomic, copy) void (^onGearTap)(void);
@property (nonatomic, copy) void (^onPowerTap)(void);
@property (nonatomic, copy) void (^onOutsideTap)(void);

#pragma mark Tile API

// Tile keys: wifi, bt, vpn, air, dnd, rot, torch, rec,
// timer, calc, cam (launchers).
- (void)setTile:(NSString *)key active:(BOOL)active animated:(BOOL)animated;

@property (nonatomic, copy) void (^onTileTap)(NSString *key);

#pragma mark Media API

@property (nonatomic, copy) NSString *mediaTitle;
@property (nonatomic, copy) NSString *mediaArtist;
@property (nonatomic, assign) BOOL mediaPlaying;
@property (nonatomic, assign) BOOL mediaHasTrack;
@property (nonatomic, assign) float mediaProgress;   // 0..1
@property (nonatomic, copy) NSString *mediaElapsed;  // formatted "m:ss"
@property (nonatomic, copy) NSString *mediaDuration; // formatted "m:ss"

- (void)setMediaFavourite:(BOOL)favourite;

@property (nonatomic, copy) void (^onPlayPause)(void);
@property (nonatomic, copy) void (^onPrevTrack)(void);
@property (nonatomic, copy) void (^onNextTrack)(void);
@property (nonatomic, copy) void (^onSeek)(float progress);
@property (nonatomic, copy) void (^onFavouriteToggle)(BOOL favourite);
@property (nonatomic, copy) void (^onOpenMusic)(void);

#pragma mark Sliders API

// 0..1
@property (nonatomic, assign) float brightnessValue;
@property (nonatomic, assign) float volumeValue;

@property (nonatomic, copy) void (^onBrightnessCommit)(float value);
@property (nonatomic, copy) void (^onVolumeCommit)(float value);

#pragma mark Network row

- (void)setNetworkIP:(NSString *)ip
            download:(NSString *)down
                upload:(NSString *)up;

#pragma mark Toast

- (void)showToast:(NSString *)text;

@end
