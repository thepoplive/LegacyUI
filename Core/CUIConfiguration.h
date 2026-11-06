#import <Foundation/Foundation.h>

@interface CUIConfiguration : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL lockScreenEnabled;
@property (nonatomic, assign) BOOL adaptiveClockEnabled;
@property (nonatomic, assign) BOOL adaptiveNotificationsEnabled;
@property (nonatomic, assign) BOOL passcodeAppearanceEnabled;
@property (nonatomic, assign) BOOL dockEnabled;
@property (nonatomic, assign) BOOL liquidGlassEnabled;
@property (nonatomic, assign) BOOL controlCenterEnabled;
@property (nonatomic, assign) BOOL volumeHUDEnabled;
@property (nonatomic, assign) BOOL volumePillEnabled;
@property (nonatomic, assign) BOOL silentHUDEnabled;

- (void)loadSettings;
- (void)saveSettings;

@end