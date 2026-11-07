// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesSolver.m
#import "SMK_GL_ParticlesSolver.h"

// Moves a particle system's particles; subclasses do the work.
@implementation SMK_GL_ParticlesSolver

- (BOOL)adjustParticleSystem:(id)aSystem toTime:(double)aTime
{
	return [self adjustParticlesBuffer:[aSystem particlesBuffer] particleSize:[aSystem particleStructSize]
		count:[aSystem particlesCount] toTime:aTime];
}

- (BOOL)adjustParticlesBuffer:(char *)aBuffer particleSize:(NSUInteger)aSize count:(NSUInteger)aCount toTime:(double)aTime
{
	return NO;
}

@end
