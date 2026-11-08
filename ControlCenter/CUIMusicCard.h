#import <UIKit/UIKit.h>
#import "CUICCIconDrawing.h"

typedef void (^CUICCMediaButtonBlock)(void);

@interface CUIMusicCard : UIView

@property (nonatomic, copy) NSString *trackTitle;
@property (nonatomic, copy) NSString *trackArtist;
@property (nonatomic, assign, getter=isPlaying) BOOL playing;

@property (nonatomic, copy) CUICCMediaButtonBlock onPrevious;
@property (nonatomic, copy) CUICCMediaButtonBlock onPlayPause;
@property (nonatomic, copy) CUICCMediaButtonBlock onNext;

- (void)refresh;

@end