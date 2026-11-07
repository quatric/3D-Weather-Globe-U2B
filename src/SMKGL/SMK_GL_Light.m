// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Light.m
#import "SMK_GL_Light.h"

// A directional light. The direction is stored negated, as GL's w=0 position.
@implementation SMK_GL_Light

- (void)disableInContext:(id)aContext withIndex:(NSInteger)aIndex
{
	glDisable(_contextIndex);
	_contextIndex = -1;
}

- (void)enableInContext:(id)aContext withIndex:(NSInteger)aIndex
{
	_contextIndex = (int)aIndex + GL_LIGHT0;
	glEnable(_contextIndex);
	[self setupLightInContext:aContext];
}

- (void)setupLightInContext:(id)aContext
{
	glLightfv(_contextIndex, GL_AMBIENT, &_ambient.r);
	glLightfv(_contextIndex, GL_DIFFUSE, &_diffuse.r);
	glLightfv(_contextIndex, GL_SPECULAR, &_specular.r);
	glLightfv(_contextIndex, GL_POSITION, &_direction.x);
}

// the light direction in the current object's space
- (void)getDirection:(SMK_GL_Vec3 *)aDirection inContextObjectSpace:(id)aSpace
{
	const SMK_GL_Matrix *inverse = [aSpace worldMatrixInverse];
	SMK_GL_Vec4 dir = _direction;
	dir.w = 0.0f;
	SMK_GL_Vec4 out;
	vec4_matrix_mul(&out, &dir, inverse);
	vec3_normalize((SMK_GL_Vec3 *)&out);
	aDirection->x = -out.x;
	aDirection->y = -out.y;
	aDirection->z = -out.z;
}

- (void)setDirection:(SMK_GL_Vec3)aDirection
{
	_direction.x = -aDirection.x;
	_direction.y = -aDirection.y;
	_direction.z = -aDirection.z;
	_direction.w = 0.0f;
}

- (SMK_GL_Vec3)direction
{
	SMK_GL_Vec3 d = { -_direction.x, -_direction.y, -_direction.z };
	return d;
}

- (void)setSpecular:(SMK_GL_Color)aSpecular
{
	_specular = aSpecular;
}

- (SMK_GL_Color)specular
{
	return _specular;
}

- (void)setDiffuse:(SMK_GL_Color)aDiffuse
{
	_diffuse = aDiffuse;
}

- (SMK_GL_Color)diffuse
{
	return _diffuse;
}

- (void)setAmbient:(SMK_GL_Color)aAmbient
{
	_ambient = aAmbient;
}

- (SMK_GL_Color)ambient
{
	return _ambient;
}

- (BOOL)isActive
{
	return _isActive;
}

- (void)setActive:(BOOL)aActive
{
	_isActive = aActive;
}

- (void)dealloc
{
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_isActive = YES;
		_contextIndex = -1;
		_direction = (SMK_GL_Vec4){ 0.0f, 0.0f, 1.0f, 0.0f };
		_ambient = (SMK_GL_Color){ 0.0f, 0.0f, 0.0f, 0.0f };
		_diffuse = (SMK_GL_Color){ 1.0f, 1.0f, 1.0f, 1.0f };
		_specular = (SMK_GL_Color){ 0.0f, 0.0f, 0.0f, 0.0f };
	}
	return self;
}

@end
