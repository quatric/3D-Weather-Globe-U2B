#import "FrameView.h"

@implementation FrameView

- (void)setDrawBackground:(BOOL)aBackground
{
    if (_drawBackground != aBackground) {
        _drawBackground = aBackground;
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)drawBackground
{
    return _drawBackground;
}

// A two-pixel bevelled frame: dark outer line, lighter left/right/bottom edges and a darker top edge.
- (void)drawRect:(NSRect)aRect
{
    NSRect bounds = [self bounds];
    [_color2 set];
    NSRect inner = NSInsetRect(bounds, 2.0, 2.0);
    if (_drawBackground)
        NSRectFill(NSIntersectionRect(aRect, inner));
    else
        NSFrameRect(inner);
    [_color4 set];
    NSFrameRect(NSInsetRect(bounds, 1.0, 1.0));
    CGFloat x = NSMinX(bounds), y = NSMinY(bounds), w = NSWidth(bounds), h = NSHeight(bounds);
    [_color1 set];
    NSFrameRect(NSMakeRect(x, y + 1.0, 1.0, h - 2.0));
    NSFrameRect(NSMakeRect(x + w - 1.0, y + 1.0, 1.0, h - 2.0));
    NSFrameRect(NSMakeRect(x + 1.0, y, w - 2.0, 1.0));
    [_color3 set];
    NSFrameRect(NSMakeRect(x + 1.0, y + h - 1.0, w - 2.0, 1.0));
}

- (void)dealloc
{
    [self _releaseAllColors];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self _createAllColors];
}

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self != nil)
        [self _createAllColors];
    return self;
}

- (void)_createAllColors
{
    [self _releaseAllColors];
    _color1 = [[NSColor colorWithCalibratedRed:0.88 green:0.88 blue:0.88 alpha:1.0] retain];
    _color2 = [[NSColor colorWithCalibratedRed:0.71 green:0.71 blue:0.71 alpha:1.0] retain];
    _color3 = [[NSColor colorWithCalibratedRed:0.58 green:0.58 blue:0.58 alpha:1.0] retain];
    _color4 = [[NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.4 alpha:1.0] retain];
    [self setNeedsDisplay:YES];
}

- (void)_releaseAllColors
{
    [_color1 release];
    [_color2 release];
    [_color3 release];
    [_color4 release];
    _color1 = _color2 = _color3 = _color4 = nil;
}

@end
