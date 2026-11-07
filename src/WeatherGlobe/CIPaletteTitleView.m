#import "CIPaletteTitleView.h"

static const float _kDoubleOffset = 4.0f;

@implementation CIPaletteTitleView

- (void)setVerticalTitleImage:(id)aImage
{
    [aImage retain];
    [_verticalTitleImage release];
    _verticalTitleImage = aImage;
    [self setNeedsDisplay:YES];
}

- (void)setHorizontalTitleImage:(id)aImage
{
    [_horizontalTitleImage release];
    _horizontalTitleImage = [[NSImage alloc] initWithData:[aImage TIFFRepresentation]];
    [self setNeedsDisplay:YES];
}

- (id)verticalTitleImage
{
    return _verticalTitleImage;
}

- (id)horizontalTitleImage
{
    return _horizontalTitleImage;
}

- (void)setViewComponents:(id)aComponents
{
    [aComponents retain];
    [_viewComponents makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_viewComponents release];
    _viewComponents = aComponents;
    [self _reconstruct];
}

- (id)viewComponents
{
    return _viewComponents;
}

- (void)setTopOffset:(CGFloat)aOffset
{
    if ((float)aOffset != _topOffset) {
        _topOffset = aOffset;
        [self _reconstruct];
    }
}

- (BOOL)isVertical
{
    return _vertical;
}

- (void)setVertical:(BOOL)aVertical
{
    if (_vertical != aVertical) {
        _vertical = aVertical;
        [self _reconstruct];
    }
}

- (NSSize)sizeForBestFit
{
    return _sizeForBestFit;
}

// the title image runs along the full length of the bar; as in the original,
// only the horizontal one is set up for the flipped view
- (void)drawRect:(NSRect)aRect
{
    NSImage *image = _vertical ? _verticalTitleImage : _horizontalTitleImage;
    if (image == nil)
        return;
    NSRect source = {NSZeroPoint, [image size]};
    NSRect destination = aRect;
    if (_vertical) {
        destination.size.width = [self bounds].size.width;
        destination.origin.x = 0.0;
    } else {
        destination.size.height = [self bounds].size.height;
        destination.origin.y = 0.0;
    }
    [image drawInRect:destination fromRect:source operation:NSCompositingOperationSourceOver fraction:[Preferences paletteTransparencyLevel] respectFlipped:!_vertical hints:nil];
}

- (void)keyDown:(id)aDown
{
    [[self window] keyDown:aDown];
}

- (void)mouseDragged:(id)aDragged
{
}

- (void)mouseDown:(id)aDown
{
}

- (void)mouseExited:(id)aExited
{
    [self _stopLightsAllButtons];
}

- (void)mouseEntered:(id)aEntered
{
    [self _setLightsAllButtons];
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)acceptsFirstMouse:(id)aMouse
{
    return YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_horizontalTitleImage release];
    [_verticalTitleImage release];
    [_viewComponents release];
    [super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self != nil) {
        [self setPostsFrameChangedNotifications:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_frameWereChanged:) name:NSViewFrameDidChangeNotification object:self];
    }
    return self;
}

// Components tagged 1 at the end of the list stick to the far end of the
// bar; the enabled buttons are covered by a tracking rect that lights them.
- (void)_frameWereChanged:(id)aChanged
{
    if (_trackingRectTag != 0)
        [self removeTrackingRect:_trackingRectTag];
    _trackingRect = NSZeroRect;
    BOOL trailing = YES;
    float trailingOffset = 0.0f;
    for (NSInteger i = (NSInteger)[_viewComponents count] - 1; i >= 0; i--) {
        NSView *view = [_viewComponents objectAtIndex:i];
        NSRect frame = [view frame];
        if (trailing && [view tag] == 1) {
            if (_vertical) {
                trailingOffset += frame.size.height + 2.0f;
                frame.origin.y = [self frame].size.height - trailingOffset;
            } else {
                trailingOffset += frame.size.width + 2.0f;
                frame.origin.x = [self frame].size.width - trailingOffset;
            }
            [view setFrameOrigin:frame.origin];
            continue;
        }
        if ([(NSControl *)view isEnabled] && [view isKindOfClass:[NSButton class]])
            _trackingRect = NSIsEmptyRect(_trackingRect) ? frame : NSUnionRect(_trackingRect, frame);
        trailing = NO;
    }
    _trackingRectTag = (int)[self addTrackingRect:_trackingRect owner:self userData:NULL assumeInside:NO];
    [self _stopLightsAllButtons];
}

- (void)_stopLightsAllButtons
{
    NSInteger count = [_viewComponents count];
    for (NSInteger i = 0; i < count - 1; i++) {
        id view = [_viewComponents objectAtIndex:i];
        if ([view isEnabled] && [view isKindOfClass:[NSButton class]] && NSContainsRect(_trackingRect, [view frame]))
            [self _stopLightsButton:view];
    }
}

- (void)_setLightsAllButtons
{
    NSInteger count = [_viewComponents count];
    for (NSInteger i = 0; i < count - 1; i++) {
        id view = [_viewComponents objectAtIndex:i];
        if ([view isEnabled] && [view isKindOfClass:[NSButton class]] && NSContainsRect(_trackingRect, [view frame]))
            [self _setLightsButton:view];
    }
}

// a button out of the mouse shows gray, keeping its own image as the alternate one
- (void)_stopLightsButton:(id)aButton
{
    static NSImage *grayButtonImage = nil;
    if (grayButtonImage == nil)
        grayButtonImage = [[NSImage imageNamed:@"Gray.tif"] retain];
    if ([aButton alternateImage] != nil)
        return;
    [aButton setAlternateImage:[aButton image]];
    [aButton setImage:grayButtonImage];
}

- (void)_setLightsButton:(id)aButton
{
    if ([aButton alternateImage] == nil)
        return;
    [aButton setImage:[aButton alternateImage]];
    [aButton setAlternateImage:nil];
}

// lays the components out in a row (or column) 2 points apart
- (void)_reconstruct
{
    NSSize size = NSZeroSize;
    NSUInteger count = [_viewComponents count];
    int x = 2, y = 2;
    for (NSUInteger i = 0; i < count; i++) {
        NSView *view = [_viewComponents objectAtIndex:i];
        NSRect frame = [view frame];
        NSPoint origin;
        if (_vertical) {
            origin = NSMakePoint((float)x + _topOffset, (float)y);
            y = (int)(origin.y + frame.size.height + 2.0f);
            size.height += frame.size.height;
            if (size.width < frame.size.width)
                size.width = frame.size.width;
        } else {
            origin = NSMakePoint((float)x, (float)y + _topOffset);
            x = (int)(origin.x + frame.size.width + 2.0f);
            size.width += frame.size.width;
            if (size.height < frame.size.height)
                size.height = frame.size.height;
        }
        if ([view superview] == nil)
            [self addSubview:view];
        [view setFrameOrigin:origin];
    }
    size.width += _kDoubleOffset + 1.0f;
    size.height += _kDoubleOffset + 1.0f;
    float spacing = count != 0 ? (float)(count * 2 - 2) : 0.0f;
    if (_vertical)
        size.height += spacing;
    else
        size.width += spacing;
    _sizeForBestFit = size;
}

@end
