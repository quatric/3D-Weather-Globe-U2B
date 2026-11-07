// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_ParticlesRepresentation.m
#import "SMK_GL_ParticlesRepresentation.h"

// Draws each particle as a camera-facing quad. Particle structs start with
// their position.
@implementation SMK_GL_ParticlesRepresentation

- (void)drawParticlesSystem:(id)aSystem withRefill:(BOOL)aRefill inContext:(id)aContext pointSize:(NSSize)aSize worldViewMatrix:(const SMK_GL_Matrix *)aMatrix applyMatrixByGL:(BOOL)aGL
{
	if (_maxParticlesCount == 0) {
		return;
	}
	if (aRefill || aSystem != _prevDrawnSystem) {
		if (!aGL) {
			[self _refillBufferWithSystem:aSystem worldViewMatrix:aMatrix pointSize:aSize];
		}
		else {
			NSAssert(aSystem == _prevDrawnSystem,
				@"Cannot use GL matrix applying inside PS representation that was used to draw other PS before.");
		}
	}
	[_context setVertexBuffer:_vertexBuffer];
	_prevDrawnSystem = aSystem;
	NSUInteger count = MIN([aSystem particlesCount], (NSUInteger)_maxParticlesCount);
	[_context setMaterial:_material];
	[_context setIndexBuffer:_indexBuffer];
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	if (aGL) {
		SMK_GL_Matrix m = *aMatrix;
		matrix_transpose(&m);
		glMultMatrixf(&m._11);
	}
	[_context turnOffLighting];
	// the original drew count * 2 indices of its (too short) index buffer
	[_context drawIndexedInMode:GL_TRIANGLES first:0 count:count * 6];
	[_context turnOnLighting];
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	[_context setMaterial:nil];
	[_context setVertexBuffer:nil];
	[_context setIndexBuffer:nil];
}

- (void)_refillBufferWithSystem:(id)aSystem worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize
{
	NSUInteger count = [aSystem particlesCount];
	if (_maxParticlesCount <= count) {
		count = _maxParticlesCount - 1;
	}
	NSUInteger srcSize = [aSystem particleStructSize];
	char *src = [aSystem particlesBuffer];
	NSUInteger destSize = [_vertexBuffer vertexSize];
	char *dest = [_vertexBuffer lock:kSMK_GL_LockReadWrite];
	[self processPointsDataWithSource:src srcSize:srcSize toDest:dest destSize:destSize count:count
		worldViewMatrix:aMatrix pointSize:aSize];
	[_vertexBuffer unlock];
}

// subclasses fill in more than the positions
- (void)processPointsDataWithSource:(char *)aSource srcSize:(NSUInteger)aSize toDest:(char *)aDest destSize:(NSUInteger)aSize2 count:(NSUInteger)aCount worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize3
{
	[self copyPositionsFromSource:aSource srcSize:aSize toDest:aDest destSize:aSize2 count:aCount
		worldViewMatrix:aMatrix pointSize:aSize3];
}

- (void)copyPositionsFromSource:(char *)aSource srcSize:(NSUInteger)aSize toDest:(char *)aDest destSize:(NSUInteger)aSize2 count:(NSUInteger)aCount worldViewMatrix:(const SMK_GL_Matrix *)aMatrix pointSize:(NSSize)aSize3
{
	if (aSize < sizeof(SMK_GL_Vec3)) {
		return;
	}
	float halfWidth = (float)aSize3.width * 0.5f;
	float halfHeight = (float)aSize3.height * 0.5f;
	for (NSUInteger i = 0; i < aCount; i++) {
		SMK_GL_Vec4 p;
		vec3_matrix_mul(&p, (const SMK_GL_Vec3 *)aSource, aMatrix);
		float corners[4][2] = {
			{ p.x - halfWidth, p.y - halfHeight },
			{ p.x + halfWidth, p.y - halfHeight },
			{ p.x - halfWidth, p.y + halfHeight },
			{ p.x + halfWidth, p.y + halfHeight },
		};
		for (int k = 0; k < 4; k++) {
			float *v = (float *)aDest;
			v[0] = corners[k][0];
			v[1] = corners[k][1];
			v[2] = p.z;
			aDest += aSize2;
		}
		aSource += aSize;
	}
}

- (void)setMaterial:(id)aMaterial
{
	[aMaterial retain];
	[_material release];
	_material = aMaterial;
}

- (id)material
{
	return _material;
}

- (id)vertexBuffer
{
	return _vertexBuffer;
}

- (void)dealloc
{
	[_vertexBuffer release];
	[_indexBuffer release];
	[_material release];
	[super dealloc];
}

// The original sized the index buffer for two indices per particle while
// writing six; it gets room for all six here.
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage maxParticlesCount:(NSUInteger)aCount
{
	self = [super initWithContainer:aContainer];
	if (self == nil) {
		return nil;
	}
	_maxParticlesCount = (unsigned int)aCount;
	if (aCount == 0) {
		return self;
	}
	_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:aContainer count:aCount * 4 usage:aUsage fvf:aFvf];
	_indexBuffer = [[SMK_GL_IndexBuffer alloc] initWithContainer:aContainer count:aCount * 6 usage:kSMK_GL_UsageStatic];
	void *indices = [_indexBuffer lock:kSMK_GL_LockWriteOnly];
	BOOL wide = [_indexBuffer are32BitIndices];
	for (NSUInteger i = 0, k = 0; i < aCount; i++) {
		NSUInteger b = i * 4;
		NSUInteger quad[6] = { b, b + 1, b + 3, b, b + 3, b + 2 };
		for (int j = 0; j < 6; j++, k++) {
			if (wide) {
				((GLuint *)indices)[k] = (GLuint)quad[j];
			}
			else {
				((GLushort *)indices)[k] = (GLushort)quad[j];
			}
		}
	}
	[_indexBuffer unlock];
	return self;
}

@end
