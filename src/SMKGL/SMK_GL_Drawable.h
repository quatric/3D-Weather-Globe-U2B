// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Drawable.m
#import "SMKGLPrefix.h"


@interface SMK_GL_Drawable : NSObject
{
    SMK_GL_Mesh *_mesh;
    SMK_GL_Matrix _matrix;
    BOOL _performVisibilityCheck;
}
+ (id)drawableWithMesh:(id)aMesh matrix:(const SMK_GL_Matrix *)aMatrix;
+ (id)drawableWithMesh:(id)aMesh;
- (void)drawInContext:(id)aContext;
- (NSInteger)testBoundsInFrustum:(id)aFrustum;
- (id)mesh;
- (void)setPerformsVisibilityCheck:(BOOL)aCheck;
- (SMK_GL_Matrix *)matrix;
- (void)setMatrix:(const SMK_GL_Matrix *)aMatrix;
- (void)dealloc;
- (id)initWithMesh:(id)aMesh;
- (id)initWithMesh:(id)aMesh matrix:(const SMK_GL_Matrix *)aMatrix;
@end

