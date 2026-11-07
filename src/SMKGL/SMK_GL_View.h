// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_View.m
#import "SMKGLPrefix.h"


@interface SMK_GL_View : NSOpenGLView
{
    SMK_GL_ObjectsContainer *_container;
    SMK_GL_Context *_context;
    NSTimer *_autoTimer;
    double _prevTime;
    unsigned int _framesCount;
    SMK_GL_Camera *_camera;
    SMK_GL_Scene *_scene;
    NSWindow *_currentHostWindow;
    NSView *_cocoaLayerSubview;
    BOOL _cocoaDrawingIsEnabled;
    BOOL _contextWasReinstalledForLeakFix;
    int _autoUpdateCounter;
    float _maxFPSLimit;
    double _prevStartTime;
    BOOL _useVerticalSync;
    BOOL _traceFPS;
}
- (void)drawRect:(NSRect)aRect;
- (BOOL)isDoubleBuffered;
- (void)flushBuffer;
- (void)clearBuffer;
- (void)viewDidMoveToWindow;
- (void)setMaxFPSLimit:(CGFloat)aLimit;
- (void)decreaseAutoUpdateCounter;
- (void)increaseAutoUpdateCounter;
- (void)setTracesFPS:(BOOL)aFPS;
- (void)stopAutoRefresh;
- (void)startAutoRefresh;
- (void)onAutoRefreshTimer:(id)aTimer;
- (void)animate:(double)aAnimate;
- (void)setUsesVerticalSync:(BOOL)aSync;
- (void)keyUp:(id)aUp;
- (void)keyDown:(id)aDown;
- (void)mouseExited:(id)aExited;
- (void)mouseEntered:(id)aEntered;
- (BOOL)acceptsFirstResponder;
- (void)mouseMoved:(id)aMoved;
- (void)mouseUp:(id)aUp;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (void)setCocoaDrawingEnabled:(BOOL)aEnabled;
- (id)camera;
- (void)setScene:(id)aScene;
- (id)scene;
- (id)context;
- (id)objectsContainer;
- (void)setOpenGLContext:(id)aContext;
- (void)createSMKGLContextForNSOpenGLContext:(id)aContext;
- (void)reshape;
- (void)update;
- (void)setViewport:(NSRect)aViewport;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame pixelFormat:(id)aFormat;
- (id)initWithCoder:(id)aCoder;
@end

@interface _CocoaLayerView : NSView
{
}
- (void)drawRect:(NSRect)aRect;
@end

