// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ASEMeshCreator.m
#import "ASEMeshCreator.h"

NSString *kObjectsKey = @"Objects";
NSString *kObjectNameKey = @"ObjectName";
NSString *kObjectMatrixKey = @"ObjectMatrix";
NSString *kObjectMaterialKey = @"ObjectMaterial";
NSString *kObjectMeshKey = @"ObjectMesh";
NSString *kMeshVerticesKey = @"MeshVertices";
NSString *kMeshIndicesKey = @"MeshIndices";

@implementation SMK_GL_Mesh (ASEMeshCreator)

// Builds a triangle mesh from the first object of a parsed ASE property list.
// Each vertex is position, normal and texture coordinate as big-endian
// floats; each index set is big-endian 32-bit triangles.
+ (id)meshWithASEParsedFile:(id)aFile container:(id)aContainer usage:(NSInteger)aUsage fvf:(NSUInteger)aFvf normalize:(BOOL)aNormalize mergeParts:(BOOL)aParts
{
	NSDictionary *object = [[[NSDictionary dictionaryWithContentsOfFile:aFile] objectForKey:kObjectsKey] objectAtIndex:0];
	NSDictionary *meshInfo = [object objectForKey:kObjectMeshKey];
	if (meshInfo == nil) {
		return nil;
	}
	NSArray *vertices = [meshInfo objectForKey:kMeshVerticesKey];
	NSUInteger verticesCount = [vertices count];
	NSArray *indexSets = [[meshInfo objectForKey:kMeshIndicesKey] allValues];
	NSMutableArray *primitives = [NSMutableArray array];
	NSUInteger setsCount = [indexSets count];
	if (aParts) {
		NSMutableData *merged = [NSMutableData data];
		for (NSUInteger i = 0; i < setsCount; i++) {
			[merged appendData:[indexSets objectAtIndex:i]];
		}
		indexSets = [NSArray arrayWithObject:merged];
		[primitives addObject:[NSNumber numberWithInt:(int)([merged length] / 12)]];
	}
	else {
		for (NSUInteger i = 0; i < setsCount; i++) {
			[primitives addObject:[NSNumber numberWithInt:(int)([[indexSets objectAtIndex:i] length] / 12)]];
		}
	}
	SMK_GL_Mesh *mesh = [[[self alloc] initWithContainer:aContainer fvf:aFvf usage:aUsage
		verticesCount:verticesCount primitivesPerPart:primitives primitiveType:GL_TRIANGLES] autorelease];
	SMK_GL_VertexBuffer *vb = [mesh vertexBuffer];
	[vb setAutoUpdateBounds:YES];
	char *p = [vb lock:kSMK_GL_LockWriteOnly];
	NSUInteger stride = [SMK_GL_VertexBuffer vertexSizeForFVF:aFvf];
	for (NSUInteger i = 0; i < verticesCount; i++) {
		const uint32_t *src = [[vertices objectAtIndex:i] bytes];
		uint32_t *dst = (uint32_t *)p;
		if (aFvf & kSMK_GL_FVF_Position) {
			dst[0] = CFSwapInt32BigToHost(src[0]);
			dst[1] = CFSwapInt32BigToHost(src[1]);
			dst[2] = CFSwapInt32BigToHost(src[2]);
			dst += 3;
		}
		if (aFvf & kSMK_GL_FVF_Normal) {
			dst[0] = CFSwapInt32BigToHost(src[3]);
			dst[1] = CFSwapInt32BigToHost(src[4]);
			dst[2] = CFSwapInt32BigToHost(src[5]);
			dst += 3;
		}
		if (aFvf & kSMK_GL_FVF_TexCoordMask) {
			dst[0] = CFSwapInt32BigToHost(src[6]);
			dst[1] = CFSwapInt32BigToHost(src[7]);
		}
		p += stride;
	}
	[vb unlock];
	if (aNormalize && (aFvf & kSMK_GL_FVF_Position)) {
		// fit into a unit cube around the origin
		SMK_GL_Vec3 mn = *[vb minCorner];
		SMK_GL_Vec3 mx = *[vb maxCorner];
		float size = mx.x - mn.x;
		if (size < mx.y - mn.y) {
			size = mx.y - mn.y;
		}
		if (size < mx.z - mn.z) {
			size = mx.z - mn.z;
		}
		SMK_GL_Matrix m;
		matrix_make_identity(&m);
		m._11 = 1.0f / size;
		m._22 = m._11;
		m._33 = m._11;
		m._14 = -((mn.x + mx.x) * 0.5f) / size;
		m._24 = -((mn.y + mx.y) * 0.5f) / size;
		m._34 = -((mn.z + mx.z) * 0.5f) / size;
		p = [vb lock:kSMK_GL_LockWriteOnly];
		for (NSUInteger i = 0; i < verticesCount; i++) {
			SMK_GL_Vec4 out;
			vec3_matrix_mul(&out, (SMK_GL_Vec3 *)p, &m);
			memcpy(p, &out, sizeof(SMK_GL_Vec3));
			p += stride;
		}
		[vb unlock];
	}
	setsCount = [indexSets count];
	for (NSUInteger i = 0; i < setsCount; i++) {
		SMK_GL_IndexBuffer *ib = [[[mesh allParts] objectAtIndex:i] indexBuffer];
		const uint32_t *src = [[indexSets objectAtIndex:i] bytes];
		BOOL wide = [ib are32BitIndices];
		NSUInteger count = [ib indicesCount];
		void *dst = [ib lock:kSMK_GL_LockWriteOnly];
		for (NSUInteger k = 0; k < count / 3 * 3; k++) {
			uint32_t index = CFSwapInt32BigToHost(src[k]);
			if (wide) {
				((GLuint *)dst)[k] = index;
			}
			else {
				((GLushort *)dst)[k] = (GLushort)index;
			}
		}
		[ib unlock];
	}
	return mesh;
}

@end
