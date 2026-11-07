// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_RenderTarget.m
#import "SMKGLPrefix.h"
#import "SMK_GL_TextureCore.h"


@interface SMK_GL_RenderTarget : SMK_GL_TextureCore
{
    NSOpenGLPixelBuffer *_pBuffer;
    NSOpenGLContext *_pBuffContext;
    int _width;
    int _height;
    unsigned int _format;
    SMK_GL_Scene *_scene;
    SMK_GL_Color _clearColor;
}
- (void)bindAtStage:(NSInteger)aStage;
- (void)deactivateInContext:(id)aContext;
- (BOOL)activateAsRenderTargetInContext:(id)aContext;
- (void)setClearColor:(SMK_GL_Color)aColor;
- (SMK_GL_Color)clearColor;
- (void)setScene:(id)aScene;
- (id)scene;
- (NSSize)size;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (NSUInteger)textureTarget;
- (BOOL)isValid;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer width:(NSInteger)aWidth height:(NSInteger)aHeight format:(NSUInteger)aFormat;
@end

