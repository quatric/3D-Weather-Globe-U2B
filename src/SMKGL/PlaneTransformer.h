// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/PlaneTransformer.m
#import "SMKGLPrefix.h"
#import "TransformerScene.h"


@interface _PlaneScene : _TransformerScene
{
    SMK_GL_Drawable *_plane;
    float _prespectiveFactor;
}
+ (NSRect)windowRectForContentRect:(NSRect)aRect;
- (double)transformDuration;
- (void)drawObjectsInContext:(id)aContext;
- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize;
- (void)dealloc;
- (id)initWithTransformer:(id)aTransformer type:(NSInteger)aType;
@end

