// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKAngleSlider.m
#import "SMKControlsPrefix.h"


@interface SMKAngleSlider : NSControl
{
    float _cachedAngleValue;
}
+ (Class)cellClass;
- (void)setAngle:(CGFloat)aAngle;
- (CGFloat)angle;
- (void)setFloatValue:(float)aValue;
- (float)floatValue;
- (void)keyDown:(id)aDown;
- (BOOL)sendAction:(SEL)aAction to:(id)aTo;
- (id)initWithCoder:(id)aCoder;
- (id)initWithFrame:(NSRect)aFrame;
- (BOOL)acceptsFirstMouse:(id)aMouse;
- (BOOL)isOpaque;
@end

