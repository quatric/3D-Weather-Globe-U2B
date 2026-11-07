// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Mesh.m
#import "SMK_GL_Mesh.h"

// the index type a part needs for this many indices
static NSUInteger _indexTypeForCount(NSUInteger aCount)
{
	return aCount > 0xffff ? GL_UNSIGNED_INT : GL_UNSIGNED_SHORT;
}

// the indices a primitive type needs per primitive, logging unknown types
static NSUInteger _indicesForPrimitives(NSUInteger aCount, NSUInteger aType)
{
	switch (aType) {
	case GL_POINTS:
		return aCount;
	case GL_LINES:
		return aCount * 2;
	case GL_TRIANGLES:
		return aCount * 3;
	case GL_QUADS:
		return aCount * 4;
	default:
		NSLog(@"Unsupported primitive type.");
		return aCount;
	}
}

// Fills an index buffer with two triangles per cell of a rows x cols grid of
// (cols + 1)-wide vertex rows.
static void _fillGridIndices(SMK_GL_IndexBuffer *aBuffer, NSUInteger aRows, NSUInteger aCols)
{
	void *p = [aBuffer lock:kSMK_GL_LockWriteOnly];
	NSUInteger type = [aBuffer indexType];
	NSUInteger width = aCols + 1;
	for (NSUInteger r = 0; r < aRows; r++) {
		for (NSUInteger c = 0; c < aCols; c++) {
			NSUInteger a = r * width + c;
			NSUInteger b = (r + 1) * width + c;
			NSUInteger idx[6] = { a, b + 1, b, a, a + 1, b + 1 };
			for (int k = 0; k < 6; k++) {
				if (type == GL_UNSIGNED_SHORT) {
					*((GLushort *)p) = (GLushort)idx[k];
					p = (GLushort *)p + 1;
				}
				else if (type == GL_UNSIGNED_INT) {
					*((GLuint *)p) = (GLuint)idx[k];
					p = (GLuint *)p + 1;
				}
				else if (type == GL_UNSIGNED_BYTE) {
					*((GLubyte *)p) = (GLubyte)idx[k];
					p = (GLubyte *)p + 1;
				}
			}
		}
	}
	[aBuffer unlock];
}

// Skips the diffuse/specular slots after position and normal and writes the
// same (u, v) into every texture coordinate set.
static void _fillVertexTail(float *aTail, NSUInteger aFVF, float aU, float aV)
{
	if (aFVF & kSMK_GL_FVF_Diffuse) {
		aTail++;
	}
	if (aFVF & kSMK_GL_FVF_Specular) {
		aTail++;
	}
	NSUInteger texCount = (aFVF & kSMK_GL_FVF_TexCoordMask) >> kSMK_GL_FVF_TexCoordShift;
	for (NSUInteger i = 0; i < texCount; i++) {
		aTail[0] = aU;
		aTail[1] = aV;
		aTail += 2;
	}
}

@implementation SMK_GL_MeshPart

+ (id)meshPartWithIndexBuffer:(id)aBuffer material:(id)aMaterial drawMode:(NSUInteger)aMode
{
	return [[[self alloc] initWithIndexBuffer:aBuffer material:aMaterial drawMode:aMode] autorelease];
}

+ (id)meshPartWithContainer:(id)aContainer indicesUsage:(NSInteger)aUsage indicesCount:(NSUInteger)aCount indicesType:(NSUInteger)aType material:(id)aMaterial drawMode:(NSUInteger)aMode
{
	return [[[self alloc] initWithContainer:aContainer indicesUsage:aUsage indicesCount:aCount
		indicesType:aType material:aMaterial drawMode:aMode] autorelease];
}

- (NSUInteger)primitivesCount
{
	NSUInteger count = [_indexBuffer count];
	if (count == 0) {
		return 0;
	}
	switch (_drawMode) {
	case GL_LINES:
		return count >> 1;
	case GL_LINE_STRIP:
		return count - 1;
	case GL_TRIANGLES:
		return count / 3;
	case GL_TRIANGLE_STRIP:
	case GL_TRIANGLE_FAN:
		return count - 2;
	case GL_QUADS:
		return count >> 2;
	case GL_QUAD_STRIP:
		return (count >> 1) - 1;
	default:
		return count;
	}
}

- (void)drawInContext:(id)aContext
{
	if (_material != nil) {
		[aContext setMaterial:_material];
	}
	[aContext setIndexBuffer:_indexBuffer];
	[aContext drawIndexedInMode:_drawMode first:0 count:[_indexBuffer count]];
}

- (void)setMaterial:(id)aMaterial
{
	if (aMaterial != _material) {
		[_material release];
		_material = [aMaterial retain];
	}
}

- (id)material
{
	return _material;
}

- (id)indexBuffer
{
	return _indexBuffer;
}

- (NSUInteger)drawMode
{
	return _drawMode;
}

- (void)dealloc
{
	[_material release];
	[_indexBuffer release];
	[super dealloc];
}

- (id)initWithIndexBuffer:(id)aBuffer material:(id)aMaterial drawMode:(NSUInteger)aMode
{
	self = [super init];
	if (self != nil) {
		_indexBuffer = [aBuffer retain];
		_material = [aMaterial retain];
		_drawMode = (unsigned int)aMode;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer indicesUsage:(NSInteger)aUsage indicesCount:(NSUInteger)aCount indicesType:(NSUInteger)aType material:(id)aMaterial drawMode:(NSUInteger)aMode
{
	self = [super init];
	if (self != nil) {
		_indexBuffer = [[SMK_GL_IndexBuffer alloc] initWithContainer:aContainer count:aCount usage:aUsage
			indexType:aType];
		_material = [aMaterial retain];
		_drawMode = (unsigned int)aMode;
	}
	return self;
}

@end

// A vertex buffer drawn by index buffer parts. A mesh without parts draws its
// vertices as points.
@implementation SMK_GL_Mesh

- (void)drawPart:(NSUInteger)aPart inContext:(id)aContext
{
	id part = [_parts objectAtIndex:aPart];
	[aContext setVertexBuffer:_vertexBuffer];
	[aContext setMaterial:_defaultMaterial];
	[part drawInContext:aContext];
}

- (void)drawInContext:(id)aContext
{
	[aContext setVertexBuffer:_vertexBuffer];
	[aContext setMaterial:_defaultMaterial];
	if (_pointsMesh) {
		[aContext setIndexBuffer:nil];
		[aContext drawNonIndexedInMode:GL_POINTS first:0 count:_verticesCount];
	}
	else {
		[_parts makeObjectsPerformSelector:@selector(drawInContext:) withObject:aContext];
	}
}

- (void)setMaterial:(id)aMaterial
{
	if (_defaultMaterial != aMaterial) {
		[_defaultMaterial release];
		_defaultMaterial = [aMaterial retain];
	}
}

- (id)material
{
	return _defaultMaterial;
}

- (void)addPart:(id)aPart
{
	[_parts addObject:aPart];
	_pointsMesh = NO;
}

- (id)allParts
{
	return _parts;
}

- (NSUInteger)verticesCount
{
	return _pointsMesh ? _verticesCount : [_vertexBuffer count];
}

- (NSUInteger)primitivesCount
{
	NSAssert([_parts count] == 1, @"Unable to get index buffer of the mesh with more than one part");
	return [[_parts objectAtIndex:0] primitivesCount];
}

- (id)indexBuffer
{
	NSAssert([_parts count] == 1, @"Unable to get index buffer of the mesh with more than one part");
	return [[_parts objectAtIndex:0] indexBuffer];
}

- (id)vertexBuffer
{
	return _vertexBuffer;
}

- (void)dealloc
{
	[_parts release];
	[_vertexBuffer release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount primitivesPerPart:(id)aPart primitiveType:(NSUInteger)aType
{
	NSMutableArray *parts = [NSMutableArray array];
	NSInteger partsCount = (NSInteger)[aPart count];
	int total = 0;
	for (NSInteger i = 0; i < partsCount; i++) {
		int primitives = [[aPart objectAtIndex:i] intValue];
		total += primitives;
		NSUInteger indices = _indicesForPrimitives(primitives, aType);
		[parts addObject:[SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:0 indicesCount:indices
			indicesType:_indexTypeForCount(indices) material:nil drawMode:aType]];
	}
	self = [self initWithContainer:aContainer fvf:aFvf usage:aUsage verticesCount:aCount meshParts:parts];
	if (self != nil) {
		_pointsMesh = aType == GL_POINTS;
		_verticesCount = total;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount primitivesCount:(NSUInteger)aCount2 primitiveType:(NSUInteger)aType
{
	id part = nil;
	if (aType != GL_POINTS) {
		NSUInteger indices = _indicesForPrimitives(aCount2, aType);
		part = [SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:0 indicesCount:indices
			indicesType:_indexTypeForCount(indices) material:nil drawMode:aType];
	}
	self = [self initWithContainer:aContainer fvf:aFvf usage:aUsage verticesCount:aCount meshPart:part];
	if (self != nil) {
		_pointsMesh = aType == GL_POINTS;
		_verticesCount = (unsigned int)aCount2;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount meshPart:(id)aPart
{
	self = [super init];
	if (self != nil) {
		_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:aContainer count:aCount usage:aUsage fvf:aFvf];
		_parts = [[NSMutableArray alloc] initWithObjects:aPart, nil];
		_verticesCount = (unsigned int)[aPart primitivesCount];
		_pointsMesh = NO;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount meshParts:(id)aParts
{
	self = [super init];
	if (self != nil) {
		_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:aContainer count:aCount usage:aUsage fvf:aFvf];
		_parts = [[NSMutableArray alloc] initWithArray:aParts];
		_pointsMesh = [aParts count] == 0;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount partsCapacity:(NSUInteger)aCapacity
{
	self = [super init];
	if (self != nil) {
		_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:aContainer count:aCount usage:aUsage fvf:aFvf];
		_parts = [[NSMutableArray alloc] initWithCapacity:aCapacity];
	}
	return self;
}

@end

@implementation SMK_GL_Mesh (SMK_GL_MeshCreation)

// The original scales x/y by the radius twice and the normals by it once;
// that is kept.
+ (id)createCylinderWithRadius:(CGFloat)aRadius height:(CGFloat)aHeight heightSegments:(NSUInteger)aSegments rSegments:(NSUInteger)aSegments2 container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage
{
	float radius = (float)aRadius;
	float height = (float)aHeight;
	id part = [SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:0 indicesCount:aSegments * aSegments2 * 6
		indicesType:0 material:nil drawMode:GL_TRIANGLES];
	SMK_GL_Mesh *mesh = [[[self alloc] initWithContainer:aContainer fvf:aFvf usage:aUsage
		verticesCount:(aSegments + 1) * (aSegments2 + 1) meshPart:part] autorelease];
	SMK_GL_VertexBuffer *vb = [mesh vertexBuffer];
	[vb setAutoUpdateBounds:YES];
	char *p = [vb lock:kSMK_GL_LockWriteOnly];
	NSUInteger stride = [vb elementSize];
	for (NSUInteger h = 0; h <= aSegments; h++) {
		float v = (float)(int)h / (float)aSegments;
		for (NSUInteger s = 0; s <= aSegments2; s++) {
			float u = (float)(int)s / (float)aSegments2;
			double angle = (double)(u * 6.2831855f);
			float c = (float)(cos(angle) * radius);
			float sn = (float)(sin(angle) * radius);
			float *f = (float *)p;
			f[0] = radius * c;
			f[1] = radius * sn;
			f[2] = v * height * radius;
			float *tail = f + 3;
			if (aFvf & kSMK_GL_FVF_Normal) {
				f[3] = c;
				f[4] = sn;
				f[5] = 0.0f;
				tail = f + 6;
			}
			_fillVertexTail(tail, aFvf, u, v);
			p += stride;
		}
	}
	[vb unlock];
	_fillGridIndices([part indexBuffer], aSegments, aSegments2);
	return mesh;
}

// A patch of a sphere: f1 x f2 cells covering cell column f3 of f4 and row f5
// of f6 of the whole sphere.
+ (id)createSpherePartWithParams:(struct SMKGL_anon11 *)aParams container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage
{
	NSAssert(aParams->f3 < aParams->f4 && aParams->f5 < aParams->f6, @"Param_error");
	id part = [SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:0
		indicesCount:aParams->f2 * aParams->f1 * 6 indicesType:0 material:nil drawMode:GL_TRIANGLES];
	SMK_GL_Mesh *mesh = [[[self alloc] initWithContainer:aContainer fvf:aFvf usage:aUsage
		verticesCount:(aParams->f1 + 1) * (aParams->f2 + 1) meshPart:part] autorelease];
	SMK_GL_VertexBuffer *vb = [mesh vertexBuffer];
	[vb setAutoUpdateBounds:YES];
	char *p = [vb lock:kSMK_GL_LockWriteOnly];
	NSUInteger stride = [vb elementSize];
	unsigned int cols = aParams->f1 / aParams->f4;
	unsigned int rows = aParams->f2 / aParams->f6;
	for (unsigned int r = 0; r <= rows; r++) {
		float v = (float)(int)r / (float)rows;
		float lat = ((v + (float)aParams->f5) / (float)aParams->f6 - 0.5f) * 3.1415927f;
		float sinLat = sinf(lat);
		float cosLat = cosf(lat);
		float nSinLat = sinf(lat * 0.995f);
		float nCosLat = cosf(lat * 0.995f);
		for (unsigned int c = 0; c <= cols; c++) {
			float u = (float)(int)c / (float)cols;
			double lon = (double)(((u + (float)aParams->f3) * 6.2831855f) / (float)aParams->f4);
			float *f = (float *)p;
			f[0] = (float)cos(lon) * cosLat * aParams->f0;
			f[1] = (float)sin(lon) * cosLat * aParams->f0;
			f[2] = sinLat * aParams->f0;
			float *tail = f + 3;
			if (aFvf & kSMK_GL_FVF_Normal) {
				f[3] = (float)cos(lon) * nCosLat;
				f[4] = (float)sin(lon) * nCosLat;
				f[5] = nSinLat;
				tail = f + 6;
			}
			_fillVertexTail(tail, aFvf, u, v);
			p += stride;
		}
	}
	[vb unlock];
	_fillGridIndices([part indexBuffer], rows, cols);
	return mesh;
}

+ (id)createSphereWithRadius:(CGFloat)aRadius segments:(NSUInteger)aSegments stacks:(NSUInteger)aStacks container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage
{
	float radius = (float)aRadius;
	id part = [SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:0 indicesCount:aSegments * aStacks * 6
		indicesType:0 material:nil drawMode:GL_TRIANGLES];
	SMK_GL_Mesh *mesh = [[[self alloc] initWithContainer:aContainer fvf:aFvf usage:aUsage
		verticesCount:(aStacks + 1) * (aSegments + 1) meshPart:part] autorelease];
	SMK_GL_VertexBuffer *vb = [mesh vertexBuffer];
	[vb setAutoUpdateBounds:YES];
	char *p = [vb lock:kSMK_GL_LockWriteOnly];
	NSUInteger stride = [vb elementSize];
	for (NSUInteger st = 0; st <= aStacks; st++) {
		float v = (float)(int)st / (float)aStacks;
		float lat = (v - 0.5f) * 3.1415927f;
		float sinLat = sinf(lat);
		float cosLat = cosf(lat);
		for (NSUInteger sg = 0; sg <= aSegments; sg++) {
			float u = (float)(int)sg / (float)aSegments;
			double lon = (double)(u * 6.2831855f);
			float nx = (float)cos(lon) * cosLat;
			float ny = (float)sin(lon) * cosLat;
			float *f = (float *)p;
			f[0] = radius * nx;
			f[1] = radius * ny;
			f[2] = radius * sinLat;
			float *tail = f + 3;
			if (aFvf & kSMK_GL_FVF_Normal) {
				f[3] = nx;
				f[4] = ny;
				f[5] = sinLat;
				tail = f + 6;
			}
			_fillVertexTail(tail, aFvf, u, v);
			p += stride;
		}
	}
	[vb unlock];
	_fillGridIndices([part indexBuffer], aStacks, aSegments);
	return mesh;
}

+ (id)createXYPlaneWithRect:(NSRect)aRect xSegments:(NSUInteger)aSegments ySegments:(NSUInteger)aSegments2 container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage
{
	id part = [SMK_GL_MeshPart meshPartWithContainer:aContainer indicesUsage:aUsage & ~0xfff
		indicesCount:aSegments * aSegments2 * 6 indicesType:0 material:nil drawMode:GL_TRIANGLES];
	SMK_GL_Mesh *mesh = [[[self alloc] initWithContainer:aContainer fvf:aFvf usage:aUsage
		verticesCount:(aSegments2 + 1) * (aSegments + 1) meshPart:part] autorelease];
	SMK_GL_VertexBuffer *vb = [mesh vertexBuffer];
	[vb setAutoUpdateBounds:YES];
	char *p = [vb lock:kSMK_GL_LockWriteOnly];
	NSUInteger stride = [vb elementSize];
	for (NSUInteger y = 0; y <= aSegments2; y++) {
		float v = (float)(int)y / (float)aSegments2;
		for (NSUInteger x = 0; x <= aSegments; x++) {
			float u = (float)(int)x / (float)aSegments;
			float *f = (float *)p;
			f[0] = (float)aRect.size.width * u + (float)aRect.origin.x;
			f[1] = (float)aRect.size.height * v + (float)aRect.origin.y;
			f[2] = 0.0f;
			float *tail = f + 3;
			if (aFvf & kSMK_GL_FVF_Normal) {
				f[3] = 0.0f;
				f[4] = 0.0f;
				f[5] = 1.0f;
				tail = f + 6;
			}
			_fillVertexTail(tail, aFvf, u, v);
			p += stride;
		}
	}
	[vb unlock];
	_fillGridIndices([part indexBuffer], aSegments2, aSegments);
	return mesh;
}

@end
