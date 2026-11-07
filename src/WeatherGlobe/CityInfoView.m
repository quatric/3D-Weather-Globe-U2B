#import "CityInfoView.h"

// A city's box in the cities list. A click selects it, a double click opens
// the full city info, and holding the mouse down tears the box off into a
// floating window that can be dragged to reorder or (when dropped outside)
// remove the city.

static SInt32 _currentSystemVersion;
static CityInfoView *__selectedView = nil;
static CityInfoSelectionView *_sCityInfoSelectionView = nil;
static NSColor *__selectedColor = nil;
static NSMutableArray *___selectedViews = nil;
static BOOL __draggingInProgress = NO;
static BOOL __draggingAborted = NO;
static BOOL __needQuickDraw = NO;
static NSTimer *_startSelfDraggingTimer = nil;
static BOOL _continueDraggedEvent = NO;
static NSDate *_doubleClickStartTime = nil;
static NSEvent *_mouseDownEvent = nil;
static NSView *__superView = nil;
static NSWindow *__draggedWindow = nil;
static NSPoint __draggedImageLocation;
static NSRect __draggedFrame;

@implementation CityInfoView

+ (void)setSelectedView:(id)aView
{
    CityInfoSelectionView *selection = [self _selectionView];
    [selection removeFromSuperview];
    [__selectedView setNeedsCreateImage];
    __selectedView = aView;
    [selection setFrame:[[aView contentView] bounds]];
    [selection setMenu:[__selectedView menu]];
    [__selectedView addSubview:selection];
    [__selectedView setNeedsCreateImage];
}

+ (id)selectedView
{
    return __selectedView;
}

+ (id)_selectionView
{
    if (_sCityInfoSelectionView == nil) {
        _sCityInfoSelectionView = [CityInfoSelectionView new];
        [_sCityInfoSelectionView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    }
    return _sCityInfoSelectionView;
}

+ (BOOL)isDraggingInProgress
{
    return __draggingInProgress;
}

+ (void)initialize
{
    Gestalt(gestaltSystemVersion, &_currentSystemVersion);
    __selectedColor = [[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:0.1f] retain];
    ___selectedViews = [NSMutableArray new];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityChildrenAttribute])
        return [_owner accessibilityObjects];
    return [super accessibilityAttributeValue:aValue];
}

- (id)accessibilityAttributeNames
{
    return [[super accessibilityAttributeNames] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:NSAccessibilityChildrenAttribute, nil]];
}

- (void)mouseUp:(id)aUp
{
    // a click that didn't start a drag selects the city
    if (_startSelfDraggingTimer != nil) {
        [[self class] setSelectedView:self];
        [FullCityInfoController refreshWithCityEntry:[_owner cityEntry]];
    }
    [_startSelfDraggingTimer invalidate];
    _startSelfDraggingTimer = nil;
    NSPoint point = [self convertPoint:[aUp locationInWindow] fromView:nil];
    if (![self mouse:point inRect:[self opaqueBounds]])
        [super mouseUp:aUp];
}

- (void)mouseDragged:(id)aDragged
{
    [_startSelfDraggingTimer invalidate];
    _startSelfDraggingTimer = nil;
    if (_continueDraggedEvent)
        [super mouseDragged:aDragged];
}

// a second click within 0.3 s opens the full city info; otherwise holding
// the button for 0.2 s starts dragging the box
- (void)mouseDown:(id)aDown
{
    if (_startSelfDraggingTimer != nil)
        return;
    [super mouseDown:aDown];
    _continueDraggedEvent = YES;
    NSPoint point = [self convertPoint:[aDown locationInWindow] fromView:nil];
    if (![self mouse:point inRect:[self opaqueBounds]])
        return;
    if (_doubleClickStartTime != nil) {
        [_doubleClickStartTime autorelease];
        if ([_doubleClickStartTime timeIntervalSinceNow] >= -0.3) {
            _doubleClickStartTime = nil;
            _continueDraggedEvent = NO;
            [FullCityInfoController showWithCityEntry:[_owner cityEntry]];
            return;
        }
    }
    _doubleClickStartTime = [[NSDate date] retain];
    [_mouseDownEvent release];
    _mouseDownEvent = [aDown retain];
    _startSelfDraggingTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(_startSelfDragging:) userInfo:nil repeats:NO];
}

- (void)_startSelfDragging:(id)aDragging
{
    _startSelfDraggingTimer = nil;
    if ([[Preferences citiesList] count] <= 1)
        return;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"NeedStopAnimationsNotification" object:self userInfo:nil];
    NSPoint origin = [self convertPoint:NSZeroPoint toView:nil];
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:@"CityInfoPboardType"] owner:nil];
    [self _createDraggedImage];
    [center postNotificationName:@"CityInfoStartDraggingNotification" object:self userInfo:nil];
    __draggingInProgress = YES;
    __needQuickDraw = YES;
    __draggingAborted = NO;
    [[__superView window] setViewsNeedDisplay:NO];
    [self dragImage:_image at:origin offset:NSZeroSize event:_mouseDownEvent pasteboard:pasteboard source:self slideBack:NO];
}

- (void)_transparencyLevelWasChanged:(id)aChanged
{
    [__selectedColor autorelease];
    __selectedColor = [[__selectedColor colorWithAlphaComponent:0.1f] retain];
}

// while one box is dragged, the others show their cached image
- (void)_acceptFinishDragging:(id)aDragging
{
    if (!_isDragged) {
        [self setContentView:_content];
        [_content release];
    }
}

- (void)_acceptPrepareForDragging:(id)aDragging
{
    if (!_isDragged) {
        [self createImageIfNeeded];
        _content = [[self contentView] retain];
        [self setContentView:nil];
    }
}

- (void)draggedImage:(id)aImage endedAt:(NSPoint)aAt operation:(NSUInteger)aOperation
{
    [self showDraggedImageIfCan];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (!__draggingAborted && aOperation != NSDragOperationEvery) {
        // escape aborts the drag
        NSEvent *event = [NSApp currentEvent];
        if ([event type] == NSEventTypeKeyDown && [[event charactersIgnoringModifiers] characterAtIndex:0] != 0)
            __draggingAborted = YES;
        [center postNotificationName:@"DraggingExitedNotification" object:_owner userInfo:nil];
        [[__superView window] displayIfNeeded];
    }
    [center postNotificationName:@"CityInfoStopDraggingNotification" object:self userInfo:nil];
    __needQuickDraw = NO;
    _isDragged = NO;
    if (!__draggingAborted && aOperation != NSDragOperationEvery) {
        // dropped outside the list: remove the city in a puff of smoke
        [center postNotificationName:@"DraggingRemoveCityNotification" object:_owner userInfo:nil];
        [_owner release];
        _owner = nil;
        Class panther = [PantherSpecificClass principalClass];
        if (panther == nil) {
            [self _poofAnimationFinished];
        } else {
            NSSize size = [aImage size];
            NSPoint center = NSMakePoint(aAt.x + ceilf((float)size.width * 0.5f), aAt.y + ceilf((float)size.height * 0.5f));
            [panther showAnimationAt:center withSize:NSMakeSize(64.0, 64.0) animationDelegate:self didEndSelector:@selector(_poofAnimationFinished)];
        }
    } else {
        // slide back into the list
        NSWindow *window = [__superView window];
        NSPoint point = [__superView convertPoint:__draggedFrame.origin toView:nil];
        point = [window convertRectToScreen:NSMakeRect(point.x, point.y, 0.0, 0.0)].origin;
        if ([__superView isFlipped])
            point.y = (float)point.y - (float)__draggedFrame.size.height;
        [self _animateDraggedWindowTo:point];
        [self setFrame:__draggedFrame];
        [__superView addSubview:self];
        [self displayIfNeeded];
        _needCreateImage = YES;
        __draggingInProgress = NO;
    }
    [__draggedWindow orderOut:self];
    [[__superView window] setViewsNeedDisplay:NO];
    [self release];
}

- (void)draggedImage:(id)aImage movedTo:(NSPoint)aTo
{
    __draggedImageLocation = aTo;
}

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal
{
    return aLocal ? NSDragOperationEvery : NSDragOperationNone;
}

- (BOOL)isDraggingAborted
{
    return __draggingInProgress && __draggingAborted;
}

- (void)abortDragging
{
    __draggingAborted = YES;
}

- (NSRect)opaqueBounds
{
    return [self bounds];
}

- (void)showDraggedImageIfCan
{
    if (__needQuickDraw) {
        [__draggedWindow setFrameOrigin:__draggedImageLocation];
        [__draggedWindow orderFront:self];
    }
}

- (void)tearOffImageIfNeeded
{
    if (_needTearOffImage) {
        [__superView displayRect:__draggedFrame];
        _needTearOffImage = NO;
    }
}

- (void)createImageIfNeeded
{
    if (_needCreateImage)
        [self _createImage];
}

- (void)setNeedsCreateImage
{
    _needCreateImage = YES;
}

// while dragging, other boxes slide to their new places over 0.05 s
- (void)setFrameAnimated:(NSRect)aAnimated
{
    if (!__draggingInProgress) {
        [self setFrame:aAnimated];
        return;
    }
    NSDate *start = [NSDate date];
    [__superView addSubview:self];
    NSRect startFrame = [self frame];
    double elapsed = 0.0;
    do {
        float t = (float)(elapsed / 0.05);
        NSPoint origin;
        origin.x = ((float)aAnimated.origin.x - (float)startFrame.origin.x) * t + (float)startFrame.origin.x;
        origin.y = t * ((float)aAnimated.origin.y - (float)startFrame.origin.y) + (float)startFrame.origin.y;
        NSRect oldFrame = [self frame];
        [self setFrameOrigin:origin];
        NSRect newFrame = {origin, startFrame.size};
        [__superView displayRect:NSIntegralRect(NSUnionRect(oldFrame, newFrame))];
        elapsed = -[start timeIntervalSinceNow];
    } while (elapsed < 0.05);
    NSRect oldFrame = [self frame];
    [self setFrameOrigin:aAnimated.origin];
    [__superView displayRect:NSIntegralRect(NSUnionRect(oldFrame, aAnimated))];
}

// at 2000 points per second
- (void)_animateDraggedWindowTo:(NSPoint)aTo
{
    NSDate *start = [NSDate date];
    NSRect frame = [__draggedWindow frame];
    float dx = (float)aTo.x - (float)frame.origin.x;
    float dy = (float)aTo.y - (float)frame.origin.y;
    float distance = fabsf(dx) > fabsf(dy) ? fabsf(dx) : fabsf(dy);
    double duration = distance / 2000.0f;
    for (double elapsed = 0.0; elapsed < duration; elapsed = -[start timeIntervalSinceNow]) {
        float t = (float)(elapsed / duration);
        [__draggedWindow setFrameOrigin:NSMakePoint(t * dx + (float)frame.origin.x, dy * t + (float)frame.origin.y)];
    }
}

// moves the box into a borderless floating window for dragging
- (void)_createDraggedImage
{
    NSColor *background = [[self window] backgroundColor];
    __superView = [[[self superview] retain] autorelease];
    __draggedFrame = [self frame];
    [self retain];
    [self removeFromSuperview];
    _needTearOffImage = YES;
    __draggedWindow = [[[NSWindow alloc] initWithContentRect:__draggedFrame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO] autorelease];
    [__draggedWindow setLevel:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    [__draggedWindow setOpaque:NO];
    [__draggedWindow setBackgroundColor:background];
    [__draggedWindow setContentView:self];
    [[[self class] _selectionView] removeFromSuperview];
    [self displayIfNeeded];
    [__selectedView addSubview:[[self class] _selectionView]];
    _isDragged = YES;
    [self _createImage];
}

- (void)_createImage
{
    if (![self lockFocusIfCanDraw])
        return;
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[self bounds]] autorelease];
    [self unlockFocus];
    [bitmap bitmapData];
    [_image release];
    _image = [[NSImage alloc] initWithSize:NSMakeSize((float)(int)[bitmap pixelsWide], (float)(int)[bitmap pixelsHigh])];
    [_image addRepresentation:bitmap];
    [_image lockFocus];
    [_image unlockFocus];
    _needCreateImage = NO;
}

- (void)_poofAnimationFinished
{
    __draggingInProgress = NO;
}

- (void)setOwner:(id)aOwner
{
    [aOwner retain];
    [_owner release];
    _owner = aOwner;
}

- (id)owner
{
    return _owner;
}

- (void)setFrameSize:(NSSize)aSize
{
    if (NSEqualSizes([self frame].size, aSize))
        return;
    [super setFrameSize:aSize];
    [[self class] setSelectedView:[[self class] selectedView]];
    if ([self postsFrameChangedNotifications])
        [[NSNotificationCenter defaultCenter] postNotificationName:kCIViewSizeDidChangeNotification object:self userInfo:nil];
}

// the box being dragged keeps its frame in the list to itself
- (void)setFrame:(NSRect)aFrame
{
    if (_isDragged) {
        __draggedFrame = aFrame;
        return;
    }
    [self setFrameOrigin:aFrame.origin];
    [self setFrameSize:aFrame.size];
}

- (NSRect)frame
{
    if (_isDragged)
        return __draggedFrame;
    return [super frame];
}

- (void)drawRect:(NSRect)aRect
{
    if (!_isDragged && __needQuickDraw)
        [_image drawInRect:aRect fromRect:aRect operation:NSCompositingOperationCopy fraction:1.0];
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

- (void)dealloc
{
    if (__selectedView == self)
        [[self class] setSelectedView:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_image release];
    [_owner release];
    [super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self != nil) {
        [self setBorderType:NSNoBorder];
        [self setContentViewMargins:NSMakeSize(0.0, -1.0)];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_acceptPrepareForDragging:) name:@"CityInfoStartDraggingNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptFinishDragging:) name:@"CityInfoStopDraggingNotification" object:nil];
        [center addObserver:self selector:@selector(_transparencyLevelWasChanged:) name:kCITransparencyLevelWasChanged object:nil];
    }
    return self;
}

@end

@implementation CityInfoSelectionView

- (void)drawRect:(NSRect)aRect
{
    if ([[self window] isKeyWindow]) {
        [__selectedColor set];
        NSRectFillUsingOperation(aRect, NSCompositingOperationSourceOver);
    }
}

@end
