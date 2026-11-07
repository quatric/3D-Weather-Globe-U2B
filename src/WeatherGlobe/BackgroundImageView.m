#import "BackgroundImageView.h"

@implementation BackgroundImageView

- (void)mouseUp:(id)aUp
{
    [[self superview] mouseUp:aUp];
}

- (void)mouseDragged:(id)aDragged
{
    [[self superview] mouseDragged:aDragged];
}

- (void)mouseDown:(id)aDown
{
    [[self superview] mouseDown:aDown];
}

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

@end
