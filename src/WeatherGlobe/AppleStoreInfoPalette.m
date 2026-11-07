#import "AppleStoreInfoPalette.h"

@implementation AppleStoreInfoPalette

- (void)mouseDragged:(id)aDragged
{
    NSRect visible = [[NSScreen mainScreen] visibleFrame];
    NSRect frame = [self frame];
    NSPoint mouse = [self convertPointToScreen:[self mouseLocationOutsideOfEventStream]];
    CGFloat y = mouse.y - _initialLocation.y;
    if (y + NSHeight(frame) > NSMinY(visible) + NSHeight(visible))
        y = NSHeight(visible) - NSHeight(frame) + NSMinY(visible);
    [self setFrameOrigin:NSMakePoint(mouse.x - _initialLocation.x, y)];
}

- (void)mouseDown:(id)aDown
{
    NSRect frame = [self frame];
    NSPoint mouse = [self convertPointToScreen:[aDown locationInWindow]];
    _initialLocation = NSMakePoint(mouse.x - NSMinX(frame), mouse.y - NSMinY(frame));
}

- (BOOL)acceptsFirstResponder
{
    return YES;
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

- (BOOL)resignFirstResponder
{
    [self setAcceptsMouseMovedEvents:NO];
    return [super resignFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    [self setAcceptsMouseMovedEvents:YES];
    return [super becomeFirstResponder];
}

- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer
{
    self = [super initWithContentRect:aRect styleMask:NSWindowStyleMaskUtilityWindow
                              backing:NSBackingStoreBuffered defer:NO];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setAlphaValue:1.0];
    [self setOpaque:NO];
    [self setHasShadow:YES];
    [self setLevel:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    [self setAcceptsMouseMovedEvents:YES];
    return self;
}

@end
