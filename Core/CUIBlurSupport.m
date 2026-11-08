#import "CUIBlurSupport.h"

UIView *CUICreateBlurView(CUIBlurStyle style) {
    Class blurEffectClass = NSClassFromString(@"UIBlurEffect");
    Class visualEffectClass = NSClassFromString(@"UIVisualEffectView");
    if (!blurEffectClass || !visualEffectClass) return nil;

    id effect = ((id (*)(id, SEL, NSInteger))objc_msgSend)(
        blurEffectClass, @selector(effectWithStyle:), (NSInteger)style);
    if (!effect) return nil;

    id view = ((id (*)(id, SEL))objc_msgSend)(visualEffectClass, @selector(alloc));
    if (!view) return nil;
    view = ((id (*)(id, SEL, id))objc_msgSend)(view, @selector(initWithEffect:), effect);
    return view;
}