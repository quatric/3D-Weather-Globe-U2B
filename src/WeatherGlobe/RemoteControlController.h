#import "WeatherGlobePrefix.h"


@interface RemoteControlController : NSObject
{
    RemoteControlWindow *_window;
    MainWindowController *_mainController;
    NSView *_mainView;
    RemoteControlBackgroundView *_bodyContentView;
    NSImageView *_drawerBackView;
    DrawerImageView *_drawerFrontView;
    NSView *_drawerContentView;
    NSPoint _initialMouseLocation;
    NSRect _initialWindowFrame;
    float _widthWithHalfDrawer;
    double _doubleClickInitTime;
    double _mouseDownTime;
    int _clickCount;
    BOOL _restorePrevPosition;
    NSPoint _prevPosition;
    BOOL _quickDrawModeEnabled;
    NSRect _drawerContentViewRect;
    NSImageView *_bodyCacheView;
    NSImageView *_drawerCacheView;
    NSWindow *_cacheWindow;
}
- (void)regionHighlightMenu:(id)aMenu;
- (void)cloudsMenu:(id)aMenu;
- (void)gridMenu:(id)aMenu;
- (BOOL)validateMenuItem:(id)aItem;
- (void)mouseUp:(id)aUp;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (void)windowDidResize:(id)aResize;
- (void)windowDidMove:(id)aMove;
- (id)buttonImageWithTag:(NSInteger)aTag isPressed:(BOOL)aPressed;
- (void)toggleDrawer;
- (void)closeDrawer;
- (void)openDrawer;
- (BOOL)drawerIsOpen;
- (BOOL)isActive;
- (void)hideRemoteControl;
- (void)showRemoteControl;
- (void)checkWindowPosition;
- (void)_switchToNormalDrawMode;
- (void)_switchToQuickDrawMode;
- (id)_drawerCacheImage;
- (id)_bodyCacheImage;
- (id)_imageWithIconIndex:(NSInteger)aIndex intoImage:(id)aImage;
- (id)_imageWithImage:(id)aImage intoImage:(id)aImage2;
- (void)dealloc;
- (void)awakeFromNib;
- (void)_setEnabledDrawerButtons:(BOOL)aButtons;
@end

@interface RemoteControlBackgroundView : NSView
{
    NSImage *_image;
}
- (void)drawRect:(NSRect)aRect;
- (void)setImage:(id)aImage;
@end

@interface DrawerImageView : NSImageView
{
    RemoteControlController *_controller;
    NSCursor *_resizeLeftRightCursor;
}
- (void)accessibilityPerformAction:(id)aAction;
- (id)accessibilityActionDescription:(id)aDescription;
- (id)accessibilityFocusedUIElement;
- (id)accessibilityHitTest:(NSPoint)aTest;
- (BOOL)accessibilityIsAttributeSettable:(id)aSettable;
- (BOOL)accessibilityIsIgnored;
- (id)accessibilityAttributeValue:(id)aValue;
- (BOOL)acceptsFirstResponder;
- (void)keyDown:(id)aDown;
- (void)mouseUp:(id)aUp;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (void)resetCursorRects;
- (id)resizeLeftRightCursor;
- (void)setController:(id)aController;
- (void)dealloc;
@end

