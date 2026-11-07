// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Camera.m
#import "SMK_GL_Camera.h"

@implementation SMK_GL_Camera

static void lookAt(SMK_GL_Camera *self)
{
	gluLookAt(self->_position.x, self->_position.y, self->_position.z,
		self->_lookAt.x, self->_lookAt.y, self->_lookAt.z,
		self->_upVector.x, self->_upVector.y, self->_upVector.z);
}

- (SMK_GL_Matrix *)viewMatrix
{
	if (!_viewMatrixIsValid) {
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		lookAt(self);
		glGetFloatv(GL_MODELVIEW_MATRIX, &_viewMatrix._11);
		matrix_transpose(&_viewMatrix);
		glPopMatrix();
		_viewMatrixIsValid = YES;
	}
	return &_viewMatrix;
}

- (void)getPosition:(SMK_GL_Vec3 *)aPosition inContextObjectSpace:(id)aSpace
{
	SMK_GL_Vec4 p;
	vec3_matrix_mul(&p, &_position, [aSpace worldMatrixInverse]);
	memcpy(aPosition, &p, sizeof(*aPosition));
}

- (void)setViewDirection:(const SMK_GL_Vec3 *)aDirection
{
	_lookAt.x = _position.x + aDirection->x;
	_lookAt.y = _position.y + aDirection->y;
	_lookAt.z = _position.z + aDirection->z;
	_viewMatrixIsValid = NO;
}

- (void)getViewDirection:(SMK_GL_Vec3 *)aDirection
{
	aDirection->x = _lookAt.x - _position.x;
	aDirection->y = _lookAt.y - _position.y;
	aDirection->z = _lookAt.z - _position.z;
}

- (void)setLookAt:(const SMK_GL_Vec3 *)aAt
{
	_lookAt = *aAt;
	_viewMatrixIsValid = NO;
}

- (void)setUpVector:(const SMK_GL_Vec3 *)aVector
{
	_upVector = *aVector;
	_viewMatrixIsValid = NO;
}

- (void)setPosition:(const SMK_GL_Vec3 *)aPosition
{
	_position = *aPosition;
	_viewMatrixIsValid = NO;
}

- (SMK_GL_Vec3 *)lookAt
{
	return &_lookAt;
}

- (SMK_GL_Vec3 *)upVector
{
	return &_upVector;
}

- (SMK_GL_Vec3 *)position
{
	return &_position;
}

- (void)setMinZ:(CGFloat)aZ maxZ:(CGFloat)aZ2
{
	_minZ = aZ;
	_maxZ = aZ2;
}

- (CGFloat)maxZDistance
{
	return _maxZ;
}

- (CGFloat)minZDistance
{
	return _minZ;
}

- (void)setFov:(CGFloat)aFov
{
	_fov = aFov;
}

- (CGFloat)fov
{
	return _fov;
}

- (void)applyCameraMatricesForSize:(NSSize)aSize
{
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(_fov, (float)(aSize.width / aSize.height), _minZ, _maxZ);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	lookAt(self);
	if (!_viewMatrixIsValid) {
		glGetFloatv(GL_MODELVIEW_MATRIX, &_viewMatrix._11);
		matrix_transpose(&_viewMatrix);
		_viewMatrixIsValid = YES;
	}
}

- (void)evaluateViewFrustum:(SMK_GL_Frustum *)aFrustum forSize:(NSSize)aSize
{
	SMK_GL_Matrix view, projection, viewProjection, inverse;
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	[self applyCameraMatricesForSize:aSize];
	glGetFloatv(GL_MODELVIEW_MATRIX, &view._11);
	matrix_transpose(&view);
	glGetFloatv(GL_PROJECTION_MATRIX, &projection._11);
	matrix_transpose(&projection);
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	matrix_mul(&viewProjection, &projection, &view);
	matrix_invert(&inverse, &viewProjection);
	calcViewFrustum(aFrustum, &inverse);
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_fov = 70.0f;
		_minZ = 0.5f;
		_maxZ = 100.0f;
		_position = (SMK_GL_Vec3){ 0.0f, -1.0f, 0.0f };
		_upVector = (SMK_GL_Vec3){ 0.0f, 0.0f, 1.0f };
		_lookAt = (SMK_GL_Vec3){ 0.0f, 0.0f, 0.0f };
	}
	return self;
}

@end
