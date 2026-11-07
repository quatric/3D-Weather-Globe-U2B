// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Scene.m
#import "SMKGLPrefix.h"


@interface SMK_GL_Scene : NSObject
{
    SMK_GL_Camera *_camera;
    NSMutableArray *_objects;
    NSMutableSet *_lights;
    NSMutableArray *_controls;
    SMK_GL_Control *_prevOverControl;
}
- (void)animate:(double)aAnimate;
- (void)keyUp:(id)aUp inView:(id)aView;
- (void)keyDown:(id)aDown inView:(id)aView;
- (void)mouseExited:(id)aExited inView:(id)aView;
- (void)mouseEntered:(id)aEntered inView:(id)aView;
- (BOOL)acceptsFirstResponderInView:(id)aView;
- (void)mouseMoved:(id)aMoved inView:(id)aView;
- (void)mouseUp:(id)aUp inView:(id)aView;
- (void)mouseDragged:(id)aDragged inView:(id)aView;
- (void)mouseDown:(id)aDown inView:(id)aView;
- (NSPoint)_glPointFromEvent:(id)aEvent inView:(id)aView;
- (void)removeAllControls;
- (void)removeControl:(id)aControl;
- (void)addControl:(id)aControl;
- (void)_controlsAppearanceWasChanged;
- (void)drawInFocusedView:(id)aView inRect:(NSRect)aRect;
- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize;
- (void)drawControlsInContext:(id)aContext;
- (void)drawObjectsInContext:(id)aContext;
- (void)setupLightsInContext:(id)aContext;
- (void)setupCameraForSize:(NSSize)aSize;
- (void)setCamera:(id)aCamera;
- (id)camera;
- (void)removeLight:(id)aLight;
- (void)addLight:(id)aLight;
- (id)lights;
- (void)removeDrawable:(id)aDrawable;
- (void)addDrawable:(id)aDrawable;
- (id)controlObjects;
- (id)drawableObjects;
- (void)dealloc;
- (id)init;
@end

