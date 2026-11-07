#import "RemoteControlController.h"

// The floating remote control palette. Its right part is a drawer of extra
// buttons that slides out as the window is widened by dragging the drawer
// handle (or double clicking it); while resizing, the views are replaced by
// cached images so the window redraws quickly.

@implementation RemoteControlController

- (void)regionHighlightMenu:(id)aMenu
{
    if ([_mainController respondsToSelector:@selector(regionHighlightMenu:)])
        [_mainController performSelector:@selector(regionHighlightMenu:) withObject:aMenu];
}

- (void)cloudsMenu:(id)aMenu
{
    if ([_mainController respondsToSelector:@selector(cloudsMenu:)])
        [_mainController performSelector:@selector(cloudsMenu:) withObject:aMenu];
}

- (void)gridMenu:(id)aMenu
{
    if ([_mainController respondsToSelector:@selector(gridMenu:)])
        [_mainController performSelector:@selector(gridMenu:) withObject:aMenu];
}

- (BOOL)validateMenuItem:(id)aItem
{
    SEL action = [aItem action];
    if (action == @selector(gridMenu:) || action == @selector(cloudsMenu:) || action == @selector(regionHighlightMenu:))
        return [_mainController validateMenuItem:aItem];
    return [super validateMenuItem:aItem];
}

// a double click (within 0.5 s) toggles the drawer; a drag that leaves it
// part open snaps it open or closed
- (void)mouseUp:(id)aUp
{
    NSTimeInterval timestamp = [(NSEvent *)aUp timestamp];
    [self _switchToNormalDrawMode];
    if (_clickCount == 1) {
        _doubleClickInitTime = _mouseDownTime;
    } else if (_clickCount == 2) {
        if (timestamp - _doubleClickInitTime <= 0.5) {
            [self toggleDrawer];
            [_window makeKeyWindow];
            _clickCount = 0;
        } else {
            _doubleClickInitTime = _mouseDownTime;
            _clickCount = 1;
        }
    }
    float width = (float)[_window frame].size.width;
    if (width != (float)[_window minSize].width && width != (float)[_window maxSize].width) {
        if (width > _widthWithHalfDrawer)
            [self openDrawer];
        else
            [self closeDrawer];
    }
}

- (void)mouseDragged:(id)aDragged
{
    [self _setEnabledDrawerButtons:YES];
    NSPoint location = [aDragged locationInWindow];
    NSRect frame = _initialWindowFrame;
    frame.size.width = ((float)location.x - (float)_initialMouseLocation.x) + (float)_initialWindowFrame.size.width;
    if ((float)frame.size.width < (float)[_window minSize].width)
        frame.size.width = [_window minSize].width;
    if ((float)[_window maxSize].width < (float)frame.size.width)
        frame.size.width = [_window maxSize].width;
    [self _switchToQuickDrawMode];
    [_window setFrame:frame display:YES];
    _clickCount = 0;
}

- (void)mouseDown:(id)aDown
{
    [_window makeFirstResponder:_drawerFrontView];
    _initialMouseLocation = [aDown locationInWindow];
    _initialWindowFrame = [_window frame];
    _mouseDownTime = [(NSEvent *)aDown timestamp];
    _clickCount++;
}

- (void)windowDidResize:(id)aResize
{
    _restorePrevPosition = NO;
}

- (void)windowDidMove:(id)aMove
{
    _restorePrevPosition = NO;
}

- (id)buttonImageWithTag:(NSInteger)aTag isPressed:(BOOL)aPressed
{
    NSImage *button = [NSImage imageNamed:aPressed ? @"RC_button_pressed.tiff" : @"RC_button.tiff"];
    return [self _imageWithIconIndex:aTag intoImage:button];
}

- (void)toggleDrawer
{
    if ([self drawerIsOpen])
        [self closeDrawer];
    else
        [self openDrawer];
}

// returns to where the window was before opening the drawer moved it
- (void)closeDrawer
{
    NSRect frame = [_window frame];
    frame.size = [_window minSize];
    if (_restorePrevPosition) {
        frame.origin = _prevPosition;
        _restorePrevPosition = NO;
    }
    [_window setFrame:frame display:YES animate:YES];
    [self _setEnabledDrawerButtons:NO];
    id responder = [_window firstResponder];
    if (responder == _window)
        [responder makeFirstResponder:_drawerFrontView];
}

// moves the window left if the open drawer would go off the screen
- (void)openDrawer
{
    [self _setEnabledDrawerButtons:YES];
    NSRect frame = [_window frame];
    NSSize maxSize = [_window maxSize];
    NSRect visible = [[NSScreen mainScreen] visibleFrame];
    float visibleRight = (float)visible.origin.x + (float)visible.size.width;
    BOOL moved = visibleRight < (float)frame.origin.x + (float)maxSize.width;
    if (moved) {
        _prevPosition = frame.origin;
        frame.origin.x = visibleRight - (float)maxSize.width;
    }
    frame.size = maxSize;
    [_window setFrame:frame display:YES animate:YES];
    if (moved)
        _restorePrevPosition = YES;
}

- (BOOL)drawerIsOpen
{
    return (float)[_window minSize].width < (float)[_window frame].size.width;
}

- (BOOL)isActive
{
    return [_window isKeyWindow];
}

- (void)hideRemoteControl
{
    [_window orderOut:self];
}

- (void)showRemoteControl
{
    [self checkWindowPosition];
    [_window makeKeyAndOrderFront:self];
}

// keeps the window on the main window's screen
- (void)checkWindowPosition
{
    NSRect visible = [[[_mainController mainWindow] screen] visibleFrame];
    NSRect frame = [_window frame];
    NSPoint origin = frame.origin;
    if (visible.origin.x + visible.size.width < frame.size.width + frame.origin.x)
        origin.x = (visible.origin.x + visible.size.width) - frame.size.width;
    if (origin.x < visible.origin.x)
        origin.x = visible.origin.x;
    if (visible.origin.y + visible.size.height < frame.size.height + frame.origin.y)
        origin.y = (visible.origin.y + visible.size.height) - frame.size.height;
    if (origin.y < visible.origin.y)
        origin.y = visible.origin.y;
    [_window setFrameOrigin:origin];
}

- (void)_switchToNormalDrawMode
{
    if (!_quickDrawModeEnabled)
        return;
    [_bodyCacheView removeFromSuperviewWithoutNeedingDisplay];
    [_mainView addSubview:_bodyContentView];
    [_drawerCacheView removeFromSuperviewWithoutNeedingDisplay];
    [_drawerContentView setFrame:[_drawerCacheView frame]];
    [_mainView addSubview:_drawerContentView];
    [_window setViewsNeedDisplay:NO];
    _quickDrawModeEnabled = NO;
}

- (void)_switchToQuickDrawMode
{
    if (_quickDrawModeEnabled)
        return;
    if (_bodyCacheView == nil)
        _bodyCacheView = [[NSImageView alloc] initWithFrame:[_bodyContentView frame]];
    [_bodyCacheView setImage:[self _bodyCacheImage]];
    [_bodyContentView removeFromSuperviewWithoutNeedingDisplay];
    [_mainView addSubview:_bodyCacheView];
    if (_drawerCacheView == nil) {
        _drawerCacheView = [NSImageView new];
        [_drawerCacheView setImageAlignment:NSImageAlignRight];
        [_drawerCacheView setAutoresizingMask:NSViewWidthSizable | NSViewMaxXMargin];
        [_drawerCacheView setImageScaling:NSImageScaleNone];
    }
    [_drawerCacheView setFrame:[_drawerContentView frame]];
    [_drawerCacheView setImage:[self _drawerCacheImage]];
    [_mainView addSubview:_drawerCacheView];
    _quickDrawModeEnabled = YES;
}

// the drawer is drawn in an offscreen window, since it may be hidden
- (id)_drawerCacheImage
{
    if (_cacheWindow == nil) {
        _cacheWindow = [[NSWindow alloc] initWithContentRect:_drawerContentViewRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        [_cacheWindow setBackgroundColor:[NSColor clearColor]];
        [_cacheWindow setOpaque:NO];
    }
    [_cacheWindow setContentView:_drawerContentView];
    [_drawerContentView displayIfNeeded];
    if (![_drawerContentView lockFocusIfCanDraw])
        return nil;
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[_drawerContentView bounds]] autorelease];
    [_drawerContentView unlockFocus];
    return [[[NSImage alloc] initWithData:[bitmap TIFFRepresentation]] autorelease];
}

- (id)_bodyCacheImage
{
    if (![_bodyContentView lockFocusIfCanDraw])
        return nil;
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[_bodyContentView bounds]] autorelease];
    [_bodyContentView unlockFocus];
    return [[[NSImage alloc] initWithData:[bitmap TIFFRepresentation]] autorelease];
}

- (id)_imageWithIconIndex:(NSInteger)aIndex intoImage:(id)aImage
{
    NSString *name;
    switch (aIndex) {
    case 1: name = @"icon_daynight.tiff"; break;
    case 2: name = @"icon_grid.tiff"; break;
    case 3: name = @"icon_countries.tiff"; break;
    case 4: name = @"icon_clouds.tiff"; break;
    case 6: name = @"icon_cityinfo.tiff"; break;
    case 8: name = @"icon_info.tiff"; break;
    default: return nil;
    }
    return [self _imageWithImage:[NSImage imageNamed:name] intoImage:aImage];
}

// aImage centred on aImage2
- (id)_imageWithImage:(id)aImage intoImage:(id)aImage2
{
    NSSize size = [aImage2 size];
    NSSize iconSize = [aImage size];
    NSPoint origin = NSMakePoint(ceilf(((float)size.width - (float)iconSize.width) * 0.5f),
                                 ceilf(((float)size.height - (float)iconSize.height) * 0.5f));
    NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
    [image lockFocus];
    [aImage2 drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [aImage drawAtPoint:origin fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [image unlockFocus];
    return image;
}

- (void)dealloc
{
    [_window release];
    [_bodyContentView release];
    [_drawerContentView release];
    [_bodyCacheView release];
    [_drawerCacheView release];
    [_cacheWindow release];
    [_mainView release];
    [super dealloc];
}

// the window's maximum size shows the whole drawer, the minimum none of it
- (void)awakeFromNib
{
    [_bodyContentView setImage:[NSImage imageNamed:@"RC_body"]];
    _drawerContentViewRect = [_drawerContentView frame];
    [_bodyContentView retain];
    [_drawerContentView retain];
    _window = [[RemoteControlWindow alloc] initWithParentWindow:[_mainController mainWindow]];
    NSSize size = [_mainView frame].size;
    [_window setMaxSize:size];
    [_window setContentSize:size];
    [_window setContentView:_mainView];
    NSSize closedSize = NSMakeSize(size.width - [_drawerContentView frame].size.width, size.height);
    [_window setMinSize:closedSize];
    [_window setContentSize:closedSize];
    [_window center];
    [_window setFrameAutosaveName:@"Remote Control"];
    [_window setDelegate:(id)self];
    [_drawerFrontView setController:self];
    _widthWithHalfDrawer = (float)[_window minSize].width + ceilf(((float)[_window maxSize].width - (float)[_window minSize].width) * 0.5f);
    [_window setInitialFirstResponder:[_mainView nextKeyView]];
    [self _setEnabledDrawerButtons:NO];
}

// the drawer's buttons are only in the window while it's (partly) open
- (void)_setEnabledDrawerButtons:(BOOL)aButtons
{
    if (!_quickDrawModeEnabled) {
        if (aButtons) {
            if ([_drawerContentView superview] != _mainView)
                [_mainView addSubview:_drawerContentView];
            return;
        }
    } else if (aButtons) {
        return;
    }
    [_drawerContentView removeFromSuperview];
}

@end

@implementation RemoteControlBackgroundView

- (void)drawRect:(NSRect)aRect
{
    [_image drawInRect:aRect fromRect:aRect operation:NSCompositingOperationSourceOver fraction:1.0];
}

- (void)setImage:(id)aImage
{
    if (_image != aImage) {
        [_image release];
        _image = [aImage retain];
        [self setNeedsDisplay:YES];
    }
}

@end

@implementation DrawerImageView

- (void)accessibilityPerformAction:(id)aAction
{
    [_controller toggleDrawer];
}

- (id)accessibilityActionDescription:(id)aDescription
{
    if ([aDescription isEqualToString:NSAccessibilityPressAction])
        return [[NSBundle mainBundle] localizedStringForKey:@"Press" value:@"" table:nil];
    return [super accessibilityActionDescription:aDescription];
}

- (id)accessibilityFocusedUIElement
{
    return NSAccessibilityUnignoredAncestor(self);
}

- (id)accessibilityHitTest:(NSPoint)aTest
{
    return NSAccessibilityUnignoredAncestor(self);
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    if ([aSettable isEqualToString:NSAccessibilityTitleAttribute] || [aSettable isEqualToString:NSAccessibilityRoleAttribute])
        return NO;
    return [super accessibilityIsAttributeSettable:aSettable];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityTitleAttribute])
        return [[NSBundle mainBundle] localizedStringForKey:@"Drawer" value:@"" table:nil];
    if ([aValue isEqualToString:NSAccessibilityRoleAttribute])
        return NSAccessibilityButtonRole;
    return [super accessibilityAttributeValue:aValue];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

// space toggles the drawer
- (void)keyDown:(id)aDown
{
    if ([[aDown charactersIgnoringModifiers] isEqualToString:@" "])
        [_controller toggleDrawer];
    else
        [super keyDown:aDown];
}

- (void)mouseUp:(id)aUp
{
    [_controller mouseUp:aUp];
    [[NSCursor arrowCursor] set];
}

- (void)mouseDragged:(id)aDragged
{
    [(NSCursor *)[self resizeLeftRightCursor] set];
    [_controller mouseDragged:aDragged];
}

- (void)mouseDown:(id)aDown
{
    [(NSCursor *)[self resizeLeftRightCursor] set];
    [_controller mouseDown:aDown];
}

- (void)resetCursorRects
{
    [self addCursorRect:[self bounds] cursor:[self resizeLeftRightCursor]];
}

- (id)resizeLeftRightCursor
{
    if (_resizeLeftRightCursor == nil)
        _resizeLeftRightCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"resizeLeftRightCursor"] hotSpot:NSMakePoint(8.0, 8.0)];
    return _resizeLeftRightCursor;
}

- (void)setController:(id)aController
{
    _controller = aController;
}

- (void)dealloc
{
    [_resizeLeftRightCursor release];
    [super dealloc];
}

@end
