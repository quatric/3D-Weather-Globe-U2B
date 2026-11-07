// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/WindowTransformer.m
#import "SMKGLPrefix.h"
#import "SMK_GL_View.h"


@interface WindowTransformer : NSObject
{
    _TransformWindow *_window;
    _Transform_GL_View *_transformView;
    _TransformerScene *_transformScene;
    NSRect _contentRect;
    double _startTransform;
    NSMutableDictionary *_cachedScenes;
    SMK_GL_2DTexture *_textureCurrent;
    SMK_GL_2DTexture *_textureNext;
}
+ (void)transformWindow:(id)aWindow newContentView:(id)aView effect:(NSInteger)aEffect;
+ (id)sharedInstance;
+ (void)applicationWillTerminate:(id)aTerminate;
+ (void)initialize;
- (void)dealloc;
- (void)_transformWindow:(id)aWindow newContentView:(id)aView effect:(NSInteger)aEffect;
- (void)_exchangeWindow:(id)aWindow withWindow:(id)aWindow2;
- (void)_enableScreenUpdates;
- (void)_disableScreenUpdates;
- (id)_bitmapFromWindow:(id)aWindow;
- (void)_setBitmap:(id)aBitmap forTexture:(id *)aTexture;
- (void)_transformTimer:(id)aTimer;
- (void)_moveBitmap:(id)aBitmap toTexture:(id)aTexture;
- (id)_transformerSceneForEffect:(NSInteger)aEffect;
- (id)_window;
- (id)glView;
- (void)_createGLTransformerView;
@end

@interface _TransformWindow : NSWindow
{
    BOOL _canBeKey;
    BOOL _canBeMain;
}
- (BOOL)canBecomeMainWindow;
- (BOOL)canBecomeKeyWindow;
- (void)setCanBecomeMainWindow:(BOOL)aWindow;
- (void)setCanBecomeKeyWindow:(BOOL)aWindow;
@end

@interface _Transform_GL_View : SMK_GL_View
{
    BOOL _drawEnabled;
}
- (void)createSMKGLContextForNSOpenGLContext:(id)aContext;
- (BOOL)isOpaque;
- (BOOL)isDoubleBuffered;
- (void)drawRect:(NSRect)aRect;
- (void)viewDidMoveToWindow;
- (void)animate:(double)aAnimate;
- (BOOL)mouseDownCanMoveWindow;
- (void)setDrawEnabled:(BOOL)aEnabled;
@end

