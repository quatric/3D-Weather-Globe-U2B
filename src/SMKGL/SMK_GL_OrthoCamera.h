// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_OrthoCamera.m
#import "SMKGLPrefix.h"
#import "SMK_GL_Camera.h"


@interface SMK_GL_OrthoCamera : SMK_GL_Camera
{
    float _frustWidth;
    float _frustHeight;
}
- (CGFloat)frustumHeight;
- (CGFloat)frustumWidth;
- (void)applyCameraMatricesForSize:(NSSize)aSize;
- (void)setFrustumHeight:(CGFloat)aHeight;
- (void)setFrustumWidth:(CGFloat)aWidth;
- (id)init;
@end

