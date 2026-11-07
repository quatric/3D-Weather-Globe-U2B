// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/TransformerScene.m
#import "SMKGLPrefix.h"
#import "SMK_GL_Scene.h"
#import "WindowTransformer.h"


@interface _TransformerScene : SMK_GL_Scene
{
    WindowTransformer *_transformer;
    SMK_GL_ObjectsContainer *_container;
    int _type;
    float _progress;
}
+ (id)transformerSceneWithType:(NSInteger)aType viewTransformer:(id)aTransformer;
+ (NSRect)windowRectForContentRect:(NSRect)aRect transformerType:(NSInteger)aType;
- (double)transformDuration;
- (id)nextTexture;
- (id)currentTexture;
- (BOOL)animateWithProgress:(CGFloat)aProgress;
- (NSSize)frameSize;
- (NSRect)contentRect;
- (NSInteger)transformType;
- (id)initWithTransformer:(id)aTransformer type:(NSInteger)aType;
@end

@interface WindowTransformer (TransformerScenePrivate)
- (NSRect)contentRect;
- (id)nextTexture;
- (id)currentTexture;
@end

