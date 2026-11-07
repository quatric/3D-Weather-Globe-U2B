#import "CIPaletteWindow.h"

static BOOL __wasDragged;

@implementation CIPaletteWindow

- (void)setTitleOffset:(CGFloat)aOffset
{
    _titleOffset = aOffset;
}

- (void)mouseUp:(id)aUp
{
    if (!__wasDragged)
        [CityInfoView setSelectedView:nil];
}

// Drags the palette by its background, keeping its top on the screen.
- (void)mouseDragged:(id)aDragged
{
    NSRect visible = [[self screen] visibleFrame];
    NSRect frame = [self frame];
    NSPoint mouse = [self convertPointToScreen:[aDragged locationInWindow]];
    CGFloat y = mouse.y - _initialLocation.y;
    if (y + NSHeight(frame) > NSMinY(visible) + NSHeight(visible))
        y = NSHeight(visible) - NSHeight(frame) + NSMinY(visible);
    [self setFrameOrigin:NSMakePoint(mouse.x - _initialLocation.x, y)];
    __wasDragged = YES;
}

- (void)mouseDown:(id)aDown
{
    NSRect frame = [self frame];
    NSPoint mouse = [self convertPointToScreen:[aDown locationInWindow]];
    _initialLocation = NSMakePoint(mouse.x - NSMinX(frame), mouse.y - NSMinY(frame));
    __wasDragged = NO;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)performClose:(id)aClose
{
    if ([self delegate] != nil && ![[self delegate] windowShouldClose:aClose]) {
        NSBeep();
        return;
    }
    [self close];
}

- (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(performClose:))
        return YES;
    return [super validateMenuItem:aItem];
}

- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer
{
    self = [super initWithContentRect:aRect
                            styleMask:NSWindowStyleMaskUtilityWindow | NSWindowStyleMaskNonactivatingPanel
                              backing:NSBackingStoreBuffered defer:NO];
    [self setBackgroundColor:[NSColor colorWithDeviceWhite:0.92 alpha:[Preferences paletteTransparencyLevel]]];
    [self setAlphaValue:1.0];
    [self setOpaque:NO];
    [self setHasShadow:YES];
    [self setHidesOnDeactivate:NO];
    [self setLevel:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    [self setMovableByWindowBackground:YES];
    return self;
}

@end
