// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesSystem.m
#import "SMKGLPrefix.h"


@interface SMK_GL_ParticlesSystem : NSObject
{
    NSMutableData *_particlesArray;
    SMK_GL_ParticlesSolver *_solver;
    SMK_GL_ParticlesRepresentation *_representation;
    SMK_GL_ObjectsContainer *_container;
    BOOL _buffersAreDirty;
    unsigned int _particlesCount;
    unsigned int _particleStructSize;
    SMK_GL_Matrix _transformMatrix;
    NSSize _particleSpriteSize;
    SMK_GL_Matrix _prevMatrixForVBRefill;
}
- (void)drawInContext:(id)aContext;
- (void)setSpritePointSize:(NSSize)aSize;
- (void)setMatrix:(const SMK_GL_Matrix *)aMatrix;
- (void)adjustToNewFrameTime;
- (void)solveSystemWithTime:(double)aTime;
- (void)setRepresentation:(id)aRepresentation;
- (id)representation;
- (void)setSolver:(id)aSolver;
- (id)solver;
- (NSUInteger)particleStructSize;
- (void *)particlesBuffer;
- (NSUInteger)particlesCount;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer particlesCount:(NSInteger)aCount particleStructSize:(NSInteger)aSize;
@end

