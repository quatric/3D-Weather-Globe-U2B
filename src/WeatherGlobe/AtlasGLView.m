#import "AtlasGLView.h"

// the panel controller handles drags only of cities from the cities list
static id _cityDragTarget(id aController, id aDragInfo, SEL aSelector)
{
    if ([[aDragInfo draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kCitiesListPasteboardType]] == nil)
        return nil;
    id panelController = [aController currentPanelController];
    return [panelController respondsToSelector:aSelector] ? panelController : nil;
}

@implementation AtlasGLView

- (id)accessibilityAttributeValue:(id)aValue
{
    NSString *key;
    if ([aValue isEqualToString:NSAccessibilityRoleDescriptionAttribute])
        key = @"View";
    else if ([aValue isEqualToString:NSAccessibilityTitleAttribute] || [aValue isEqualToString:NSAccessibilityHelpAttribute])
        key = [[_controller currentPanelController] isKindOfClass:[SphereMapController class]] ? @"Globe" : @"Map";
    else
        return [super accessibilityAttributeValue:aValue];
    return [[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (void)setMainWindowController:(id)aController
{
    _controller = aController;
}

- (void)cleanupOnWindowClose
{
    _controller = nil;
}

- (void)resetCursorRects
{
    [super resetCursorRects];
    if (_cursor != nil)
        [self addCursorRect:[self bounds] cursor:_cursor];
}

// During a live resize by the splitter the view shows a snapshot of itself,
// cropped to keep its aspect.
- (void)drawRect:(NSRect)aRect
{
    if (_bgrImage == nil) {
        [super drawRect:aRect];
        return;
    }
    NSRect frame = [self frame];
    NSRect source = NSZeroRect;
    source.size = [_bgrImage size];
    float aspect = frame.size.width / frame.size.height;
    if (source.size.width / source.size.height < aspect) {
        float height = source.size.width / aspect;
        source.origin.y += (source.size.height - height) * 0.5f;
        source.size.height = height;
    } else {
        float width = aspect * source.size.height;
        source.origin.x += (source.size.width - width) * 0.5f;
        source.size.width = width;
    }
    [_bgrImage drawInRect:NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, frame.size.width, frame.size.height) fromRect:source operation:NSCompositingOperationCopy fraction:1.0];
}

- (void)viewDidEndLiveResize
{
    if (!_liveResizeBySplitter)
        return;
    _liveResizeBySplitter = NO;
    [[self window] setAlphaValue:1.0];
    [[self window] setOpaque:YES];
    GLint order = 1;
    [[self openGLContext] setValues:&order forParameter:NSOpenGLContextParameterSurfaceOrder];
    [_bgrImage release];
    _bgrImage = nil;
    [self setNeedsDisplay:YES];
}

// a resize not coming from the window is the splitter's: the GL surface goes
// below the window, which shows the snapshot instead
- (void)viewWillStartLiveResize
{
    _liveResizeBySplitter = ![[[self window] contentView] inLiveResize];
    if (!_liveResizeBySplitter)
        return;
    NSRect frame = [self frame];
    [self display];
    _bgrImage = [[self _snapshotImage:NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, frame.size.width, frame.size.height)] retain];
    [self display];
    GLint order = -1;
    [[self openGLContext] setValues:&order forParameter:NSOpenGLContextParameterSurfaceOrder];
    [[self window] setOpaque:NO];
    [[self window] setAlphaValue:0.999];
}

- (id)_snapshotImage:(NSRect)aImage
{
    NSImage *image = [[[NSImage alloc] initWithSize:aImage.size] autorelease];
    [image addRepresentation:[self _snapshotBitmap:aImage]];
    return image;
}

// GL rows run bottom up, which the flipped image of the original undid;
// the rows are swapped here instead
- (id)_snapshotBitmap:(NSRect)aBitmap
{
    int width = (int)aBitmap.size.width;
    int height = (int)aBitmap.size.height;
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:width * 4 bitsPerPixel:32] autorelease];
    unsigned char *data = [bitmap bitmapData];
    if (data == NULL)
        return bitmap;
    [[self openGLContext] makeCurrentContext];
    glReadPixels((int)aBitmap.origin.x, (int)aBitmap.origin.y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    size_t rowBytes = (size_t)width * 4;
    unsigned char *row = malloc(rowBytes);
    for (int y = 0; y < height / 2; y++) {
        memcpy(row, data + y * rowBytes, rowBytes);
        memcpy(data + y * rowBytes, data + (height - 1 - y) * rowBytes, rowBytes);
        memcpy(data + (height - 1 - y) * rowBytes, row, rowBytes);
    }
    free(row);
    return bitmap;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)flagsChanged:(id)aChanged
{
    [[_controller currentPanelController] flagsChanged:aChanged inView:self];
}

- (void)keyUp:(id)aUp
{
    [[_controller currentPanelController] keyUp:aUp inView:self];
}

- (void)keyDown:(id)aDown
{
    [[_controller currentPanelController] keyDown:aDown inView:self];
}

- (void)scrollWheel:(id)aWheel
{
    [[_controller currentPanelController] scrollWheel:aWheel inView:self];
}

// The original turned on the window's mouse-moved events here, which go to
// the first responder: clicking a button (the compass) took the hover
// effects away. A tracking area sends them to this view instead.
- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if (_hoverTrackingArea == nil) {
        _hoverTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
            options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
            owner:self userInfo:nil];
        [self addTrackingArea:_hoverTrackingArea];
    }
}

- (void)mouseExited:(id)aExited
{
    [[_controller currentPanelController] mouseExited:aExited inView:self];
}

- (void)mouseEntered:(id)aEntered
{
    [[_controller currentPanelController] mouseEntered:aEntered inView:self];
}

- (BOOL)acceptsFirstResponder
{
    return [[_controller currentPanelController] acceptsFirstResponderInView:self];
}

- (void)mouseMoved:(id)aMoved
{
    [[_controller currentPanelController] mouseMoved:aMoved inView:self];
}

- (void)mouseUp:(id)aUp
{
    [[_controller currentPanelController] mouseUp:aUp inView:self];
    _doAnimateFromMouse = NO;
    [self refreshAutoAnimationFlag];
}

- (void)mouseDragged:(id)aDragged
{
    [[_controller currentPanelController] mouseDragged:aDragged inView:self];
}

- (void)mouseDown:(id)aDown
{
    [[_controller currentPanelController] mouseDown:aDown inView:self];
    _doAnimateFromMouse = YES;
    [self refreshAutoAnimationFlag];
}

- (void)createSMKGLContextForNSOpenGLContext:(id)aContext
{
    [super createSMKGLContextForNSOpenGLContext:aContext];
    [[self context] setClearColor:(SMK_GL_Color){0, 0, 0, 0}];
}

- (void)_cloudMapWasDecompressed
{
    [self setNeedsDisplay:YES];
}

- (void)_defaultsWereChanged:(id)aChanged
{
    _doAnimateFromPrefs = [Preferences cloudsEnabled] && [Preferences cloudsAnimationQuality] != 0;
    [self refreshAutoAnimationFlag];
}

- (void)refreshAutoAnimationFlag
{
    if (_doAnimateFromPrefs || _doAnimateFromMouse || [_controller requiresAnimation])
        [self startAutoRefresh];
    else
        [self stopAutoRefresh];
}

- (void)animate:(double)aAnimate
{
    [super animate:aAnimate];
    [self setNeedsDisplay:YES];
}

// keeps animating while a menu or a drag tracks the mouse
- (void)startAutoRefresh
{
    [super startAutoRefresh];
    [[NSRunLoop currentRunLoop] addTimer:_autoTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)_citiesListDraggingWasEnded:(id)aEnded
{
    [[_controller currentPanelController] draggingExited:nil];
}

- (void)concludeDragOperation:(id)aOperation
{
    [_cityDragTarget(_controller, aOperation, @selector(concludeDragOperation:)) concludeDragOperation:aOperation];
}

- (BOOL)performDragOperation:(id)aOperation
{
    return YES;
}

- (BOOL)prepareForDragOperation:(id)aOperation
{
    return YES;
}

- (void)draggingExited:(id)aExited
{
    [_cityDragTarget(_controller, aExited, @selector(draggingExited:)) draggingExited:aExited];
}

- (NSUInteger)draggingUpdated:(id)aUpdated
{
    return [_cityDragTarget(_controller, aUpdated, @selector(draggingUpdated:)) draggingUpdated:aUpdated];
}

- (NSUInteger)draggingEntered:(id)aEntered
{
    return [_cityDragTarget(_controller, aEntered, @selector(draggingEntered:)) draggingEntered:aEntered];
}

- (id)cursor
{
    return _cursor;
}

- (void)setCursor:(id)aCursor
{
    if (_cursor == aCursor)
        return;
    [aCursor retain];
    [_cursor release];
    _cursor = aCursor;
    [[_controller mainWindow] invalidateCursorRectsForView:self];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_cursor release];
    [_hoverTrackingArea release];
    [_bgrImage release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self setMaxFPSLimit:30.0];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_defaultsWereChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(_cloudMapWasDecompressed) name:SingleCloudMapWasDecompressedNotification object:nil];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:kCitiesListPasteboardType, nil]];
    [center addObserver:self selector:@selector(_citiesListDraggingWasEnded:) name:kCitiesListDraggingEndedNotification object:nil];
}

@end
