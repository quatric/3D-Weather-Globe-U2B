// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Drawable.m
#import "SMK_GL_Drawable.h"

// A mesh placed in the world by a matrix.
@implementation SMK_GL_Drawable

+ (id)drawableWithMesh:(id)aMesh matrix:(const SMK_GL_Matrix *)aMatrix
{
	return [[[self alloc] initWithMesh:aMesh matrix:aMatrix] autorelease];
}

+ (id)drawableWithMesh:(id)aMesh
{
	return [[[self alloc] initWithMesh:aMesh] autorelease];
}

- (void)drawInContext:(id)aContext
{
	if (_performVisibilityCheck && [self testBoundsInFrustum:aContext] == 0) {
		return;
	}
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glMultTransposeMatrixfARB((const GLfloat *)[self matrix]);
	[aContext setCurrentDrawable:self];
	[_mesh drawInContext:aContext];
	[aContext setCurrentDrawable:nil];
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}

// the context's frustum against the mesh's bounds
- (NSInteger)testBoundsInFrustum:(id)aFrustum
{
	if (_mesh == nil) {
		return 0;
	}
	SMK_GL_Frustum *frustum = [aFrustum viewFrustum];
	SMK_GL_Vec3 *maxCorner = [[_mesh vertexBuffer] maxCorner];
	SMK_GL_Vec3 *minCorner = [[_mesh vertexBuffer] minCorner];
	return boxMatrixIntersectionTest(minCorner, maxCorner, &_matrix, frustum);
}

- (id)mesh
{
	return _mesh;
}

- (void)setPerformsVisibilityCheck:(BOOL)aCheck
{
	_performVisibilityCheck = aCheck;
}

- (SMK_GL_Matrix *)matrix
{
	return &_matrix;
}

- (void)setMatrix:(const SMK_GL_Matrix *)aMatrix
{
	memcpy(&_matrix, aMatrix, sizeof(_matrix));
}

- (void)dealloc
{
	[_mesh release];
	[super dealloc];
}

- (id)initWithMesh:(id)aMesh
{
	self = [super init];
	if (self != nil) {
		matrix_make_identity(&_matrix);
		_mesh = [aMesh retain];
		_performVisibilityCheck = YES;
	}
	return self;
}

- (id)initWithMesh:(id)aMesh matrix:(const SMK_GL_Matrix *)aMatrix
{
	self = [super init];
	if (self != nil) {
		[self setMatrix:aMatrix];
		_mesh = [aMesh retain];
		_performVisibilityCheck = YES;
	}
	return self;
}

@end
