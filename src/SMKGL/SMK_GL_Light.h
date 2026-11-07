// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Light.m
#import "SMKGLPrefix.h"


@interface SMK_GL_Light : NSObject
{
    BOOL _isActive;
    int _contextIndex;
    SMK_GL_Color _ambient;
    SMK_GL_Color _diffuse;
    SMK_GL_Color _specular;
    SMK_GL_Vec4 _direction;
}
- (void)disableInContext:(id)aContext withIndex:(NSInteger)aIndex;
- (void)enableInContext:(id)aContext withIndex:(NSInteger)aIndex;
- (void)setupLightInContext:(id)aContext;
- (void)getDirection:(SMK_GL_Vec3 *)aDirection inContextObjectSpace:(id)aSpace;
- (void)setDirection:(SMK_GL_Vec3)aDirection;
- (SMK_GL_Vec3)direction;
- (void)setSpecular:(SMK_GL_Color)aSpecular;
- (SMK_GL_Color)specular;
- (void)setDiffuse:(SMK_GL_Color)aDiffuse;
- (SMK_GL_Color)diffuse;
- (void)setAmbient:(SMK_GL_Color)aAmbient;
- (SMK_GL_Color)ambient;
- (BOOL)isActive;
- (void)setActive:(BOOL)aActive;
- (void)dealloc;
- (id)init;
@end

