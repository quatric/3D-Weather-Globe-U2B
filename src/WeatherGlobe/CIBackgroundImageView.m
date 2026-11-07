#import "CIBackgroundImageView.h"

@implementation CIBackgroundImageView

- (BOOL)acceptsFirstResponder
{
    return NO;
}

- (void)setImageViewStyle:(NSInteger)aStyle
{
    if (_style != aStyle) {
        _style = (int)aStyle;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)aRect
{
    NSImage *image = [self image];
    if (image == nil)
        return;
    NSSize size = [image size];
    NSRect destination = aRect;
    if (_style == 0) {
        destination.size.height = NSHeight([self bounds]) - 1.0;
        destination.origin.y = 1.0;
    } else if (_style == 1) {
        destination.size.width = NSWidth([self bounds]);
        destination.origin.x = 0.0;
    }
    [image drawInRect:destination fromRect:NSMakeRect(0.0, 0.0, size.width, size.height)
            operation:NSCompositingOperationCopy fraction:[Preferences paletteTransparencyLevel]
       respectFlipped:YES hints:nil];
    if (_style == 0) {
        [[NSColor colorWithCalibratedWhite:[Preferences separatorColorWhiteComponent]
                                     alpha:[Preferences paletteTransparencyLevel]] set];
        NSFrameRect(NSMakeRect(0.0, 0.0, NSWidth([self bounds]), 1.0));
    }
}

@end
