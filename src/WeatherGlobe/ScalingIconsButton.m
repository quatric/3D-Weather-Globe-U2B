#import "ScalingIconsButton.h"

@implementation ScalingIconsButton

- (void)drawRect:(NSRect)aRect
{
    [self _refreshIcons];
    [super drawRect:aRect];
}

- (void)setAlternateImage:(id)aImage toPosition:(NSInteger)aPosition
{
    if (_altIconImages == nil)
        _altIconImages = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([self _setImage:aImage toPosition:aPosition intoIconImages:_altIconImages])
        _needRefreshAltIcon = YES;
}

- (void)setImage:(id)aImage toPosition:(NSInteger)aPosition
{
    if (_iconImages == nil)
        _iconImages = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([self _setImage:aImage toPosition:aPosition intoIconImages:_iconImages])
        _needRefreshIcon = YES;
}

- (void)_refreshIcons
{
    float width = NSWidth([self bounds]);
    BOOL resized = width != _lastWidth;
    _lastWidth = width;
    if (_needRefreshIcon || resized) {
        NSImage *image = [self _imageFromImages:_iconImages];
        if (image != nil)
            [self setImage:image];
        _needRefreshIcon = NO;
    }
    if (_needRefreshAltIcon || resized) {
        NSImage *image = [self _imageFromImages:_altIconImages];
        if (image != nil)
            [self setAlternateImage:image];
        _needRefreshAltIcon = NO;
    }
}

// Builds a button-wide image from a left cap (0), a stretched middle (1) and a right cap (2).
- (id)_imageFromImages:(id)aImages
{
    NSImage *left = [aImages objectForKey:[NSString stringWithFormat:@"%d", 0]];
    NSImage *middle = [aImages objectForKey:[NSString stringWithFormat:@"%d", 1]];
    NSImage *right = [aImages objectForKey:[NSString stringWithFormat:@"%d", 2]];
    NSRect bounds = [self bounds];
    NSSize leftSize = left ? [left size] : NSZeroSize;
    NSSize middleSize = middle ? [middle size] : NSZeroSize;
    NSSize rightSize = right ? [right size] : NSZeroSize;
    CGFloat height = MAX(MAX(leftSize.height, middleSize.height), rightSize.height);
    if (height == 0.0)
        return nil;

    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(NSWidth(bounds), height)] autorelease];
    [image lockFocus];
    if (left != nil)
        [left drawAtPoint:NSMakePoint(0.0, floorf((height - leftSize.height) * 0.5f)) fromRect:NSZeroRect
                operation:NSCompositingOperationSourceOver fraction:1.0];
    if (middle != nil)
        [middle drawInRect:NSMakeRect(leftSize.width, floorf((height - middleSize.height) * 0.5f),
                                      NSWidth(bounds) - leftSize.width - rightSize.width, middleSize.height)
                  fromRect:NSMakeRect(0.0, 0.0, middleSize.width, middleSize.height)
                 operation:NSCompositingOperationSourceOver fraction:1.0];
    if (right != nil)
        [right drawAtPoint:NSMakePoint(NSWidth(bounds) - rightSize.width, floorf((height - rightSize.height) * 0.5f))
                  fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [image unlockFocus];
    return image;
}

- (BOOL)_setImage:(id)aImage toPosition:(NSInteger)aPosition intoIconImages:(id)aImages
{
    NSString *key = [NSString stringWithFormat:@"%d", (int)aPosition];
    id old = [aImages objectForKey:key];
    if (old != aImage) {
        [aImages setObject:aImage forKey:key];
        [self setNeedsDisplay:YES];
    }
    return old != aImage;
}

- (void)dealloc
{
    [_iconImages release];
    [_altIconImages release];
    [super dealloc];
}

@end
