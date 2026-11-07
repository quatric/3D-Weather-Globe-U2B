#import "RemoteControlWindow.h"

@implementation RemoteControlWindow

- (void)performZoom:(id)aZoom
{
    [_parentWindow performZoom:aZoom];
}

- (void)performMiniaturize:(id)aMiniaturize
{
    [_parentWindow performMiniaturize:aMiniaturize];
}

- (void)performClose:(id)aClose
{
    [_parentWindow performClose:aClose];
}

- (BOOL)validateMenuItem:(id)aItem
{
    SEL action = [aItem action];
    if (action == @selector(performClose:) || action == @selector(performMiniaturize:) || action == @selector(performZoom:))
        return [_parentWindow validateMenuItem:aItem];
    return [super validateMenuItem:aItem];
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)keyDown:(id)aDown
{
    // Escape is swallowed.
    if ([aDown keyCode] != 0x35)
        [super keyDown:aDown];
}

- (id)initWithParentWindow:(id)aWindow
{
    self = [self init];
    if (self != nil)
        _parentWindow = aWindow;
    return self;
}

- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer
{
    self = [super initWithContentRect:aRect styleMask:NSWindowStyleMaskUtilityWindow
                              backing:NSBackingStoreBuffered defer:NO];
    [self setFloatingPanel:YES];
    [self setLevel:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    [self setHasShadow:YES];
    [self setHidesOnDeactivate:YES];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:NO];
    [self setMovableByWindowBackground:YES];
    [self setAlphaValue:1.0];
    return self;
}

@end
