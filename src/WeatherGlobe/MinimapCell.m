#import "MinimapCell.h"

@implementation MinimapCell

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityRoleDescriptionAttribute])
        return [[NSBundle mainBundle] localizedStringForKey:@"Navigation Map" value:@"" table:nil];
    return [super accessibilityAttributeValue:aValue];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (void)stopTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView mouseIsUp:(BOOL)aUp
{
}

- (BOOL)continueTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView
{
    NSRect rect = [self drawingRectForBounds:[aView bounds]];
    [self setWorldRectOriginForPoint:aAt inRect:rect];
    [[self target] performSelector:[self action] withObject:self];
    return YES;
}

- (BOOL)startTrackingAt:(NSPoint)aAt inView:(id)aView
{
    NSRect rect = [self drawingRectForBounds:[aView bounds]];
    BOOL inside = [aView mouse:aAt inRect:rect];
    if (inside) {
        [self setWorldRectOriginForPoint:aAt inRect:rect];
        [[self target] performSelector:[self action] withObject:self];
    }
    return inside;
}

- (void)setWorldRectOriginForPoint:(NSPoint)aPoint inRect:(NSRect)aRect
{
    float x = aPoint.x - aRect.origin.x;
    float y = aPoint.y - aRect.origin.y;
    if (x < 0.0f)
        x = 0.0f;
    else if (x > aRect.size.width)
        x = aRect.size.width;
    if (y < 0.0f)
        y = 0.0f;
    else if (y > aRect.size.height)
        y = aRect.size.height;
    _actualWorldRect.origin.x = x / (aRect.size.height + aRect.size.height) + _actualWorldRect.size.width * -0.5f;
    _actualWorldRect.origin.y = y / aRect.size.height + _actualWorldRect.size.height * -0.5f;
    if (_actualWorldRect.origin.y < 0.0)
        _actualWorldRect.origin.y = 0.0;
    float maxY = 1.0f - _actualWorldRect.size.height;
    if (_actualWorldRect.origin.y > maxY)
        _actualWorldRect.origin.y = maxY;
}

- (BOOL)trackMouse:(id)aMouse inRect:(NSRect)aRect ofView:(id)aView untilMouseUp:(BOOL)aUp
{
    NSPoint last = [aView convertPoint:[aMouse locationInWindow] fromView:nil];
    BOOL tracking = [self startTrackingAt:last inView:aView];
    while (tracking) {
        NSEvent *event = [[aView window] nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
        NSPoint point = [aView convertPoint:[event locationInWindow] fromView:nil];
        if ([event type] == NSEventTypeLeftMouseUp) {
            [self stopTracking:last at:point inView:aView mouseIsUp:YES];
            return YES;
        }
        tracking = [self continueTracking:last at:point inView:aView];
        last = point;
    }
    return NO;
}

- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView
{
    NSRect rect = [self drawingRectForBounds:[aView bounds]];
    [_mapImage drawInRect:NSMakeRect(rect.origin.x, rect.origin.y, [_mapImage size].width, [_mapImage size].height)
                 fromRect:NSZeroRect
                operation:NSCompositingOperationCopy
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];
    float h = rect.size.height;
    NSRect world;
    world.origin.x = (_displayWorldRect.origin.x + _displayWorldRect.origin.x) * h + rect.origin.x + h * -2.0f;
    world.origin.y = h * _displayWorldRect.origin.y + rect.origin.y;
    world.size.width = (_displayWorldRect.size.width + _displayWorldRect.size.width) * h;
    world.size.height = h * _displayWorldRect.size.height;
    // the map wraps horizontally, so draw the frame once per copy of the world
    for (int i = 0; i < 3; i++) {
        NSRect part = NSIntersectionRect(world, rect);
        if (!NSIsEmptyRect(part)) {
            [[NSColor colorWithCalibratedRed:0.4 green:0.6 blue:0.8 alpha:0.4] set];
            NSRectFillUsingOperation(part, NSCompositingOperationSourceOver);
            [[NSColor redColor] set];
            NSFrameRect(NSIntersectionRect(NSInsetRect(part, -1.0, -1.0), rect));
        }
        world.origin.x += h + h;
    }
}

- (void)setAction:(SEL)aAction
{
    _selector = aAction;
}

- (SEL)action
{
    return _selector;
}

- (void)setTarget:(id)aTarget
{
    _target = aTarget;
}

- (id)target
{
    return _target;
}

- (NSRect)worldRect
{
    return _actualWorldRect;
}

- (void)setWorldRect:(NSRect)aRect
{
    _actualWorldRect = aRect;
    _displayWorldRect = aRect;
    [[self controlView] setNeedsDisplay:YES];
}

- (void)dealloc
{
    [_mapImage release];
    [super dealloc];
}

- (id)initWithImage:(id)aImage
{
    self = [super init];
    if (self != nil) {
        _mapImage = [aImage retain];
        [self setImageFrameStyle:NSImageFrameGrayBezel];
    }
    return self;
}

@end
