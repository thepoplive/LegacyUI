#import <UIKit/UIKit.h>
#import "CUICCIconDrawing.h"

typedef void (^CUICCMediaButtonBlock)(void);

// Square transport module for the controls row: prev / play / next stacked.
@interface CUIMusicCard : UIView

@property (nonatomic, assign, getter=isPlaying) BOOL playing;

@property (nonatomic, copy) CUICCMediaButtonBlock onPrevious;
@property (nonatomic, copy) CUICCMediaButtonBlock onPlayPause;
@property (nonatomic, copy) CUICCMediaButtonBlock onNext;

@end