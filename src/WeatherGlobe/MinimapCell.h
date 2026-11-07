#import "WeatherGlobePrefix.h"


@interface MinimapCell : NSImageCell
{
    NSImage *_mapImage;
    NSRect _actualWorldRect;
    NSRect _displayWorldRect;
    id _target;
    SEL _selector;
}
- (id)accessibilityAttributeValue:(id)aValue;
- (BOOL)accessibilityIsIgnored;
- (void)stopTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView mouseIsUp:(BOOL)aUp;
- (BOOL)continueTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView;
- (BOOL)startTrackingAt:(NSPoint)aAt inView:(id)aView;
- (void)setWorldRectOriginForPoint:(NSPoint)aPoint inRect:(NSRect)aRect;
- (BOOL)trackMouse:(id)aMouse inRect:(NSRect)aRect ofView:(id)aView untilMouseUp:(BOOL)aUp;
- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView;
- (void)setAction:(SEL)aAction;
- (SEL)action;
- (void)setTarget:(id)aTarget;
- (id)target;
- (NSRect)worldRect;
- (void)setWorldRect:(NSRect)aRect;
- (void)dealloc;
- (id)initWithImage:(id)aImage;
@end

