#import "CUICCIconDrawing.h"
#import <math.h>

#define RAD(d) ((d) * M_PI / 180.0)

static UIImage *CUICCRender(CGSize size, UIColor *color, void (^draw)(CGContextRef ctx, CGRect rect)) {
    if (size.width < 1 || size.height < 1) return nil;
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [color setStroke];
    [color setFill];
    CGContextSetLineWidth(ctx, size.width * 0.08);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    draw(ctx, CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *CUICCImageForIcon(CUICCIcon icon, CGSize size, UIColor *color) {
    switch (icon) {
        case CUICCIconWiFi: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGPoint c = CGPointMake(r.size.width / 2, r.size.height * 0.78);
                CGFloat radius[3] = {r.size.width * 0.42, r.size.width * 0.28, r.size.width * 0.14};
                for (int i = 0; i < 3; i++) {
                    CGContextAddArc(ctx, c.x, c.y, radius[i], RAD(215), RAD(325), 0);
                    CGContextStrokePath(ctx);
                }
                CGFloat dot = r.size.width * 0.055;
                CGContextFillEllipseInRect(ctx, CGRectMake(c.x - dot, c.y - dot, dot * 2, dot * 2));
            });
        }
        case CUICCIconBluetooth: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width;
                CGFloat h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.13);
                CGFloat xMid = w * 0.55;
                CGFloat xL = w * 0.26, xR = w * 0.80;
                CGFloat yTop = h * 0.10, yMid = h * 0.50, yBot = h * 0.90;
                // Center spine.
                CGContextMoveToPoint(ctx, xMid, yTop + h * 0.06);
                CGContextAddLineToPoint(ctx, xMid, yBot - h * 0.06);
                CGContextStrokePath(ctx);
                // Left chevron through the spine.
                CGContextMoveToPoint(ctx, xR, yTop);
                CGContextAddLineToPoint(ctx, xL, yMid);
                CGContextAddLineToPoint(ctx, xR, yBot);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconAirplane: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                // Paper dart: one bold triangle + fold notch.
                CGFloat cx = r.size.width / 2;
                CGFloat w = r.size.width, h = r.size.height;
                UIBezierPath *p = [UIBezierPath bezierPath];
                [p moveToPoint:CGPointMake(w * 0.92, h * 0.10)];
                [p addLineToPoint:CGPointMake(w * 0.06, h * 0.46)];
                [p addLineToPoint:CGPointMake(w * 0.42, h * 0.54)];
                [p addLineToPoint:CGPointMake(w * 0.52, h * 0.92)];
                [p addLineToPoint:CGPointMake(w * 0.62, h * 0.54)];
                [p addLineToPoint:CGPointMake(w * 0.94, h * 0.50)];
                [p closePath];
                [p fill];
                // Fold line.
                CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut);
                CGContextSetLineWidth(ctx, w * 0.05);
                CGContextMoveToPoint(ctx, cx, h * 0.16);
                CGContextAddLineToPoint(ctx, w * 0.46, h * 0.52);
                CGContextStrokePath(ctx);
                CGContextSetBlendMode(ctx, kCGBlendModeNormal);
            });
        }
        case CUICCIconMoon: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat R = r.size.width * 0.42;
                CGPoint c1 = CGPointMake(r.size.width * 0.48, r.size.height * 0.52);
                CGContextFillEllipseInRect(ctx, CGRectMake(c1.x - R, c1.y - R, R * 2, R * 2));
                // Erase the bite with destination-out (context is transparent).
                CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut);
                CGPoint c2 = CGPointMake(r.size.width * 0.72, r.size.height * 0.34);
                CGContextFillEllipseInRect(ctx, CGRectMake(c2.x - R, c2.y - R, R * 2, R * 2));
                CGContextSetBlendMode(ctx, kCGBlendModeNormal);
            });
        }
        case CUICCIconSun: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGPoint c = CGPointMake(r.size.width / 2, r.size.height / 2);
                CGFloat core = r.size.width * 0.20;
                CGContextFillEllipseInRect(ctx, CGRectMake(c.x - core, c.y - core, core * 2, core * 2));
                CGFloat rayIn = r.size.width * 0.32, rayOut = r.size.width * 0.46;
                CGContextSetLineWidth(ctx, r.size.width * 0.07);
                for (int i = 0; i < 8; i++) {
                    CGFloat angle = (CGFloat)i * M_PI / 4.0;
                    CGContextMoveToPoint(ctx, c.x + rayIn * cosf(angle), c.y + rayIn * sinf(angle));
                    CGContextAddLineToPoint(ctx, c.x + rayOut * cosf(angle), c.y + rayOut * sinf(angle));
                    CGContextStrokePath(ctx);
                }
            });
        }
        case CUICCIconSpeaker: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                UIBezierPath *horn = [UIBezierPath bezierPath];
                [horn moveToPoint:CGPointMake(r.size.width * 0.10, r.size.height * 0.38)];
                [horn addLineToPoint:CGPointMake(r.size.width * 0.28, r.size.height * 0.38)];
                [horn addLineToPoint:CGPointMake(r.size.width * 0.52, r.size.height * 0.14)];
                [horn addLineToPoint:CGPointMake(r.size.width * 0.52, r.size.height * 0.86)];
                [horn addLineToPoint:CGPointMake(r.size.width * 0.28, r.size.height * 0.62)];
                [horn addLineToPoint:CGPointMake(r.size.width * 0.10, r.size.height * 0.62)];
                [horn closePath];
                [horn fill];
                CGPoint c = CGPointMake(r.size.width * 0.52, r.size.height * 0.5);
                CGFloat a[2] = {r.size.width * 0.22, r.size.width * 0.36};
                for (int i = 0; i < 2; i++) {
                    CGContextAddArc(ctx, c.x, c.y, a[i], RAD(-50), RAD(50), 0);
                    CGContextStrokePath(ctx);
                }
            });
        }
        case CUICCIconPlay: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                UIBezierPath *p = [UIBezierPath bezierPath];
                [p moveToPoint:CGPointMake(r.size.width * 0.32, r.size.height * 0.14)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.86, r.size.height * 0.5)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.32, r.size.height * 0.86)];
                [p closePath];
                [p fill];
            });
        }
        case CUICCIconPause: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width * 0.16, h = r.size.height * 0.66;
                CGFloat y = (r.size.height - h) / 2;
                CGContextFillRect(ctx, CGRectMake(r.size.width * 0.30, y, w, h));
                CGContextFillRect(ctx, CGRectMake(r.size.width * 0.58, y, w, h));
            });
        }
        case CUICCIconPrev: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat y = r.size.height * 0.18, h = r.size.height * 0.64;
                CGFloat bw = r.size.width * 0.08;
                CGContextFillRect(ctx, CGRectMake(r.size.width * 0.14, y, bw, h));
                UIBezierPath *p = [UIBezierPath bezierPath];
                [p moveToPoint:CGPointMake(r.size.width * 0.86, y)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.30, y + h / 2)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.86, y + h)];
                [p closePath];
                [p fill];
            });
        }
        case CUICCIconNext: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat y = r.size.height * 0.18, h = r.size.height * 0.64;
                CGFloat bw = r.size.width * 0.08;
                CGContextFillRect(ctx, CGRectMake(r.size.width * 0.78, y, bw, h));
                UIBezierPath *p = [UIBezierPath bezierPath];
                [p moveToPoint:CGPointMake(r.size.width * 0.14, y)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.70, y + h / 2)];
                [p addLineToPoint:CGPointMake(r.size.width * 0.14, y + h)];
                [p closePath];
                [p fill];
            });
        }
        case CUICCIconLock: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                // Shackle arc.
                CGFloat shackle = w * 0.24;
                CGContextSetLineWidth(ctx, w * 0.10);
                CGContextAddArc(ctx, w * 0.5, h * 0.30, shackle, RAD(180), RAD(360), 0);
                CGContextStrokePath(ctx);
                // Body: rounded rect.
                CGFloat bw = w * 0.58, bh = h * 0.40;
                CGFloat bx = (w - bw) / 2.0, by = h * 0.42;
                UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:
                    CGRectMake(bx, by, bw, bh) cornerRadius:w * 0.10];
                CGContextAddPath(ctx, body.CGPath);
                CGContextFillPath(ctx);
                // Keyhole.
                CGFloat k = w * 0.05;
                CGContextFillEllipseInRect(ctx,
                    CGRectMake(w * 0.5 - k, by + bh * 0.35, k * 2, k * 2));
            });
        }
        case CUICCIconVPN: {
            // Shield with a check (concept symbol "vpn").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                UIBezierPath *shield = [UIBezierPath bezierPath];
                [shield moveToPoint:CGPointMake(w * 0.50, h * 0.10)];
                [shield addLineToPoint:CGPointMake(w * 0.84, h * 0.23)];
                [shield addLineToPoint:CGPointMake(w * 0.84, h * 0.48)];
                [shield addCurveToPoint:CGPointMake(w * 0.50, h * 0.90)
                          controlPoint1:CGPointMake(w * 0.84, h * 0.69)
                          controlPoint2:CGPointMake(w * 0.64, h * 0.82)];
                [shield addCurveToPoint:CGPointMake(w * 0.16, h * 0.48)
                          controlPoint1:CGPointMake(w * 0.36, h * 0.82)
                          controlPoint2:CGPointMake(w * 0.16, h * 0.69)];
                [shield addLineToPoint:CGPointMake(w * 0.16, h * 0.23)];
                [shield closePath];
                [shield stroke];
                CGContextSetLineWidth(ctx, w * 0.09);
                CGContextMoveToPoint(ctx, w * 0.35, h * 0.50);
                CGContextAddLineToPoint(ctx, w * 0.46, h * 0.62);
                CGContextAddLineToPoint(ctx, w * 0.67, h * 0.36);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconRotation: {
            // Circular arrow + small lock (concept "rot").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.085);
                CGContextAddArc(ctx, w * 0.50, h * 0.50, w * 0.33,
                               RAD(310), RAD(240), 0);
                CGContextStrokePath(ctx);
                // Arrowhead.
                UIBezierPath *head = [UIBezierPath bezierPath];
                [head moveToPoint:CGPointMake(w * 0.78, h * 0.19)];
                [head addLineToPoint:CGPointMake(w * 0.83, h * 0.36)];
                [head addLineToPoint:CGPointMake(w * 0.66, h * 0.33)];
                [head closePath];
                [head fill];
                // Lock body.
                CGContextAddArc(ctx, w * 0.50, h * 0.475, w * 0.10,
                                RAD(180), RAD(360), 0);
                CGContextStrokePath(ctx);
                CGContextFillRect(ctx, CGRectMake(w * 0.38, h * 0.46, w * 0.24, h * 0.20));
            });
        }
        case CUICCIconTorch: {
            // Flashlight (concept "torch").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                UIBezierPath *body = [UIBezierPath bezierPath];
                [body moveToPoint:CGPointMake(w * 0.33, h * 0.10)];
                [body addLineToPoint:CGPointMake(w * 0.67, h * 0.10)];
                [body addLineToPoint:CGPointMake(w * 0.58, h * 0.27)];
                [body addLineToPoint:CGPointMake(w * 0.58, h * 0.44)];
                [body addLineToPoint:CGPointMake(w * 0.42, h * 0.44)];
                [body addLineToPoint:CGPointMake(w * 0.42, h * 0.27)];
                [body closePath];
                [body fill];
                UIBezierPath *barrel = [UIBezierPath bezierPath];
                [barrel moveToPoint:CGPointMake(w * 0.42, h * 0.46)];
                [barrel addLineToPoint:CGPointMake(w * 0.58, h * 0.46)];
                [barrel addLineToPoint:CGPointMake(w * 0.58, h * 0.88)];
                [barrel addQuadCurveToPoint:CGPointMake(w * 0.42, h * 0.88)
                              controlPoint:CGPointMake(w * 0.50, h * 0.98)];
                [barrel closePath];
                [barrel fill];
                CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut);
                CGContextFillRect(ctx, CGRectMake(w * 0.47, h * 0.52, w * 0.06, h * 0.30));
                CGContextSetBlendMode(ctx, kCGBlendModeNormal);
            });
        }
        case CUICCIconRecord: {
            // Screen record: rounded screen + dot (concept "rec").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                UIBezierPath *screen = [UIBezierPath bezierPathWithRoundedRect:
                    CGRectMake(w * 0.12, h * 0.16, w * 0.76, h * 0.55)
                    cornerRadius:w * 0.10];
                [screen stroke];
                CGContextFillEllipseInRect(ctx, CGRectMake(w * 0.42, h * 0.34, w * 0.16, w * 0.16));
                CGContextSetLineWidth(ctx, w * 0.08);
                CGContextMoveToPoint(ctx, w * 0.33, h * 0.86);
                CGContextAddLineToPoint(ctx, w * 0.67, h * 0.86);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconTimer: {
            // Clock (concept "timer").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.085);
                CGContextAddArc(ctx, w * 0.50, h * 0.57, w * 0.32, RAD(0), RAD(360), 0);
                CGContextStrokePath(ctx);
                CGContextMoveToPoint(ctx, w * 0.50, h * 0.57);
                CGContextAddLineToPoint(ctx, w * 0.65, h * 0.44);
                CGContextStrokePath(ctx);
                CGContextMoveToPoint(ctx, w * 0.40, h * 0.09);
                CGContextAddLineToPoint(ctx, w * 0.60, h * 0.09);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconCalc: {
            // Calculator (concept "calc").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.07);
                UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:
                    CGRectMake(w * 0.20, h * 0.09, w * 0.60, h * 0.82)
                    cornerRadius:w * 0.10];
                [body stroke];
                CGContextFillRect(ctx, CGRectInset(
                    CGRectMake(w * 0.33, h * 0.22, w * 0.34, h * 0.14), w * 0.02, w * 0.02));
                CGFloat dot = w * 0.055;
                for (int row = 0; row < 2; row++) {
                    for (int col = 0; col < 3; col++) {
                        CGContextFillEllipseInRect(ctx, CGRectMake(
                            w * 0.31 + col * w * 0.15 - dot / 2,
                            h * 0.50 + row * h * 0.16 - dot / 2,
                            dot, dot));
                    }
                }
            });
        }
        case CUICCIconCamera: {
            // Camera (concept "cam").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.08);
                UIBezierPath *body = [UIBezierPath bezierPath];
                [body moveToPoint:CGPointMake(w * 0.10, h * 0.36)];
                [body addLineToPoint:CGPointMake(w * 0.26, h * 0.36)];
                [body addLineToPoint:CGPointMake(w * 0.32, h * 0.24)];
                [body addLineToPoint:CGPointMake(w * 0.62, h * 0.24)];
                [body addLineToPoint:CGPointMake(w * 0.68, h * 0.36)];
                [body addLineToPoint:CGPointMake(w * 0.90, h * 0.36)];
                [body addLineToPoint:CGPointMake(w * 0.90, h * 0.80)];
                [body addLineToPoint:CGPointMake(w * 0.10, h * 0.80)];
                [body closePath];
                [body stroke];
                CGContextStrokeEllipseInRect(ctx, CGRectMake(
                    w * 0.36, h * 0.42, w * 0.28, w * 0.28));
            });
        }
        case CUICCIconPower: {
            // Power symbol (concept "pw").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.09);
                CGContextMoveToPoint(ctx, w * 0.50, h * 0.12);
                CGContextAddLineToPoint(ctx, w * 0.50, h * 0.46);
                CGContextStrokePath(ctx);
                CGContextAddArc(ctx, w * 0.50, h * 0.56, w * 0.27,
                               RAD(310), RAD(230), 0);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconHeart: {
            // Heart (concept "heart").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                UIBezierPath *heart = [UIBezierPath bezierPath];
                [heart moveToPoint:CGPointMake(w * 0.50, h * 0.85)];
                [heart addCurveToPoint:CGPointMake(w * 0.06, h * 0.30)
                          controlPoint1:CGPointMake(w * 0.19, h * 0.66)
                          controlPoint2:CGPointMake(w * 0.06, h * 0.48)];
                [heart addCurveToPoint:CGPointMake(w * 0.50, h * 0.32)
                          controlPoint1:CGPointMake(w * 0.06, h * 0.10)
                          controlPoint2:CGPointMake(w * 0.50, h * 0.14)];
                [heart addCurveToPoint:CGPointMake(w * 0.94, h * 0.30)
                          controlPoint1:CGPointMake(w * 0.50, h * 0.14)
                          controlPoint2:CGPointMake(w * 0.94, h * 0.10)];
                [heart addCurveToPoint:CGPointMake(w * 0.50, h * 0.85)
                          controlPoint1:CGPointMake(w * 0.94, h * 0.48)
                          controlPoint2:CGPointMake(w * 0.81, h * 0.66)];
                [heart closePath];
                [heart stroke];
            });
        }
        case CUICCIconBack: {
            // Chevron left (concept "back").
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGFloat w = r.size.width, h = r.size.height;
                CGContextSetLineWidth(ctx, w * 0.11);
                CGContextMoveToPoint(ctx, w * 0.62, h * 0.20);
                CGContextAddLineToPoint(ctx, w * 0.32, h * 0.50);
                CGContextAddLineToPoint(ctx, w * 0.62, h * 0.80);
                CGContextStrokePath(ctx);
            });
        }
        case CUICCIconGear: {
            return CUICCRender(size, color, ^(CGContextRef ctx, CGRect r) {
                CGPoint c = CGPointMake(r.size.width / 2, r.size.height / 2);
                CGFloat outer = r.size.width * 0.30;
                CGContextSetLineWidth(ctx, r.size.width * 0.11);
                CGContextStrokeEllipseInRect(ctx, CGRectMake(c.x - outer, c.y - outer, outer * 2, outer * 2));
                CGFloat rayIn = outer * 0.80, rayOut = r.size.width * 0.46;
                CGContextSetLineWidth(ctx, r.size.width * 0.08);
                for (int i = 0; i < 8; i++) {
                    CGFloat angle = (CGFloat)i * M_PI / 4.0 + M_PI / 8.0;
                    CGContextMoveToPoint(ctx, c.x + rayIn * cosf(angle), c.y + rayIn * sinf(angle));
                    CGContextAddLineToPoint(ctx, c.x + rayOut * cosf(angle), c.y + rayOut * sinf(angle));
                    CGContextStrokePath(ctx);
                }
            });
        }
    }
    return nil;
}

UIImage *CUICCIconImage(CUICCIcon icon, CGSize size, UIColor *color) {
    static NSMutableDictionary *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSMutableDictionary alloc] init]; });

    CGFloat r = 0, g = 0, b = 0, a = 0;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *key = [NSString stringWithFormat:@"%d-%.0f-%.0f-%03d%03d%03d%03d",
                     (int)icon, size.width, size.height,
                     (int)(r * 255), (int)(g * 255), (int)(b * 255), (int)(a * 255)];
    @synchronized (cache) {
        UIImage *cached = cache[key];
        if (cached) return cached;
    }

    UIImage *image = CUICCImageForIcon(icon, size, color);
    if (image) {
        @synchronized (cache) {
            cache[key] = image;
        }
    }
    return image;
}