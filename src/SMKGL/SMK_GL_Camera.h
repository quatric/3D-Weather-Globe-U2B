// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Camera.m
#import "SMKGLPrefix.h"


@interface SMK_GL_Camera : NSObject
{
    float _fov;
    float _minZ;
    float _maxZ;
    SMK_GL_Vec3 _position;
    SMK_GL_Vec3 _upVector;
    SMK_GL_Vec3 _lookAt;
    BOOL _viewMatrixIsValid;
    SMK_GL_Matrix _viewMatrix;
    SMK_GL_Matrix _viewProjectionMatrix;
}
- (SMK_GL_Matrix *)viewMatrix;
- (void)getPosition:(SMK_GL_Vec3 *)aPosition inContextObjectSpace:(id)aSpace;
- (void)setViewDirection:(const SMK_GL_Vec3 *)aDirection;
- (void)getViewDirection:(SMK_GL_Vec3 *)aDirection;
- (void)setLookAt:(const SMK_GL_Vec3 *)aAt;
- (void)setUpVector:(const SMK_GL_Vec3 *)aVector;
- (void)setPosition:(const SMK_GL_Vec3 *)aPosition;
- (SMK_GL_Vec3 *)lookAt;
- (SMK_GL_Vec3 *)upVector;
- (SMK_GL_Vec3 *)position;
- (void)setMinZ:(CGFloat)aZ maxZ:(CGFloat)aZ2;
- (CGFloat)maxZDistance;
- (CGFloat)minZDistance;
- (void)setFov:(CGFloat)aFov;
- (CGFloat)fov;
- (void)applyCameraMatricesForSize:(NSSize)aSize;
- (void)evaluateViewFrustum:(SMK_GL_Frustum *)aFrustum forSize:(NSSize)aSize;
- (id)init;
@end

