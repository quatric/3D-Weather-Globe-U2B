// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesSystem.m
#import "SMK_GL_ParticlesSystem.h"

// An array of caller-defined particle structs, moved by a solver and drawn by
// a representation.
@implementation SMK_GL_ParticlesSystem

// The representation refills its buffer only when the rotation part of the
// modelview changed; a pure translation is applied by GL.
- (void)drawInContext:(id)aContext
{
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	SMK_GL_Matrix m = _transformMatrix;
	matrix_transpose(&m);
	glMultMatrixf(&m._11);
	BOOL dirty = _buffersAreDirty;
	SMK_GL_Matrix worldView;
	glGetFloatv(GL_MODELVIEW_MATRIX, &worldView._11);
	matrix_transpose(&worldView);
	const SMK_GL_Matrix *prev = &_prevMatrixForVBRefill;
	BOOL refill;
	BOOL applyByGL;
	if (prev->_11 != worldView._11 || prev->_12 != worldView._12 || prev->_13 != worldView._13
		|| prev->_21 != worldView._21 || prev->_22 != worldView._22 || prev->_23 != worldView._23
		|| prev->_31 != worldView._31 || prev->_32 != worldView._32 || prev->_33 != worldView._33 || dirty) {
		_prevMatrixForVBRefill = worldView;
		refill = YES;
		applyByGL = NO;
	}
	else {
		SMK_GL_Vec3 offset = {
			worldView._14 - prev->_14,
			worldView._24 - prev->_24,
			worldView._34 - prev->_34
		};
		translateMatrix(&worldView, &offset);
		refill = dirty;
		applyByGL = YES;
	}
	[_representation drawParticlesSystem:self withRefill:refill inContext:aContext pointSize:_particleSpriteSize
		worldViewMatrix:&worldView applyMatrixByGL:applyByGL];
	_buffersAreDirty = NO;
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}

- (void)setSpritePointSize:(NSSize)aSize
{
	_particleSpriteSize = aSize;
	_buffersAreDirty = YES;
}

- (void)setMatrix:(const SMK_GL_Matrix *)aMatrix
{
	memcpy(&_transformMatrix, aMatrix, sizeof(_transformMatrix));
}

- (void)adjustToNewFrameTime
{
	[self solveSystemWithTime:[_container currentFrameTime]];
}

- (void)solveSystemWithTime:(double)aTime
{
	if ([_solver adjustParticleSystem:self toTime:aTime]) {
		_buffersAreDirty = YES;
	}
}

- (void)setRepresentation:(id)aRepresentation
{
	[aRepresentation retain];
	[_representation release];
	_representation = aRepresentation;
	_buffersAreDirty = YES;
}

- (id)representation
{
	return _representation;
}

- (void)setSolver:(id)aSolver
{
	[aSolver retain];
	[_solver release];
	_solver = aSolver;
}

- (id)solver
{
	return _solver;
}

- (NSUInteger)particleStructSize
{
	return _particleStructSize;
}

- (void *)particlesBuffer
{
	return [_particlesArray mutableBytes];
}

- (NSUInteger)particlesCount
{
	return _particlesCount;
}

- (void)dealloc
{
	[_container removeParticlesSystem:self];
	[_solver release];
	[_representation release];
	[_particlesArray release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer particlesCount:(NSInteger)aCount particleStructSize:(NSInteger)aSize
{
	self = [super init];
	if (self != nil) {
		_particlesArray = [[NSMutableData alloc] initWithLength:aCount * aSize];
		_container = aContainer;
		[aContainer addParticlesSystem:self];
		_buffersAreDirty = YES;
		_particlesCount = (unsigned int)aCount;
		_particleStructSize = (unsigned int)aSize;
		_particleSpriteSize = NSMakeSize(1.0, 1.0);
		matrix_make_identity(&_transformMatrix);
	}
	return self;
}

@end
