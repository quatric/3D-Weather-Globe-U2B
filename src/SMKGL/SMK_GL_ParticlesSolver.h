// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesSolver.m
#import "SMKGLPrefix.h"


@interface SMK_GL_ParticlesSolver : NSObject
{
}
- (BOOL)adjustParticleSystem:(id)aSystem toTime:(double)aTime;
- (BOOL)adjustParticlesBuffer:(char *)aBuffer particleSize:(NSUInteger)aSize count:(NSUInteger)aCount toTime:(double)aTime;
@end

