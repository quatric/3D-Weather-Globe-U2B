// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesRepresentation.m
#import "SMKGLPrefix.h"
#import "SMK_GL_object.h"


@interface SMK_GL_ParticlesRepresentation : SMK_GL_Object
{
    SMK_GL_VertexBuffer *_vertexBuffer;
    SMK_GL_IndexBuffer *_indexBuffer;
    SMK_GL_Material *_material;
    unsigned int _maxParticlesCount;
    SMK_GL_ParticlesSystem *_prevDrawnSystem;
}
- (void)drawParticlesSystem:(id)aSystem withRefill:(BOOL)aRefill inContext:(id)aContext pointSize:(NSSize)aSize worldViewMatrix:(const SMK_GL_Matrix *)aMatrix applyMatrixByGL:(BOOL)aGL;
- (void)_refillBufferWithSystem:(id)aSystem worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize;
- (void)processPointsDataWithSource:(char *)aSource srcSize:(NSUInteger)aSize toDest:(char *)aDest destSize:(NSUInteger)aSize2 count:(NSUInteger)aCount worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize3;
- (void)copyPositionsFromSource:(char *)aSource srcSize:(NSUInteger)aSize toDest:(char *)aDest destSize:(NSUInteger)aSize2 count:(NSUInteger)aCount worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize3;
- (void)setMaterial:(id)aMaterial;
- (id)material;
- (id)vertexBuffer;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage maxParticlesCount:(NSUInteger)aCount;
@end

