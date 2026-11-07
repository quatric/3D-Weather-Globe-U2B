#import "WeatherGlobePrefix.h"


@interface AtlasGLView : SMK_GL_View
{
    MainWindowController *_controller;
    BOOL _doAnimateFromPrefs;
    BOOL _doAnimateFromMouse;
    NSCursor *_cursor;
    NSImage *_bgrImage;
    BOOL _liveResizeBySplitter;
    NSTrackingArea *_hoverTrackingArea;
}
- (id)accessibilityAttributeValue:(id)aValue;
- (BOOL)accessibilityIsIgnored;
- (void)setMainWindowController:(id)aController;
- (void)cleanupOnWindowClose;
- (void)resetCursorRects;
- (void)drawRect:(NSRect)aRect;
- (void)viewDidEndLiveResize;
- (void)viewWillStartLiveResize;
- (id)_snapshotImage:(NSRect)aImage;
- (id)_snapshotBitmap:(NSRect)aBitmap;
- (BOOL)isOpaque;
- (void)flagsChanged:(id)aChanged;
- (void)keyUp:(id)aUp;
- (void)keyDown:(id)aDown;
- (void)scrollWheel:(id)aWheel;
- (void)mouseExited:(id)aExited;
- (void)mouseEntered:(id)aEntered;
- (BOOL)acceptsFirstResponder;
- (void)mouseMoved:(id)aMoved;
- (void)mouseUp:(id)aUp;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (void)createSMKGLContextForNSOpenGLContext:(id)aContext;
- (void)_cloudMapWasDecompressed;
- (void)_defaultsWereChanged:(id)aChanged;
- (void)refreshAutoAnimationFlag;
- (void)animate:(double)aAnimate;
- (void)startAutoRefresh;
- (void)_citiesListDraggingWasEnded:(id)aEnded;
- (void)concludeDragOperation:(id)aOperation;
- (BOOL)performDragOperation:(id)aOperation;
- (BOOL)prepareForDragOperation:(id)aOperation;
- (void)draggingExited:(id)aExited;
- (NSUInteger)draggingUpdated:(id)aUpdated;
- (NSUInteger)draggingEntered:(id)aEntered;
- (id)cursor;
- (void)setCursor:(id)aCursor;
- (void)dealloc;
- (void)awakeFromNib;
@end

