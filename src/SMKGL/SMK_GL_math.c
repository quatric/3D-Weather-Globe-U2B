// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/GenericImp/SMK_GL_math.c
#include <assert.h>
#include <math.h>
#include <string.h>

#include "SMK_GL_math.h"

static float _sin_tableArr[SMK_GL_TRIG_TABLE_SIZE];
static float _cos_tableArr[SMK_GL_TRIG_TABLE_SIZE];
float *_sin_table = _sin_tableArr;
float *_cos_table = _cos_tableArr;

void SMK_GL_initMath(void)
{
	for (int i = 0; i < SMK_GL_TRIG_TABLE_SIZE; i++) {
		float a = (float)i * 6.283185f * (1.0f / 1024.0f);
		_sin_table[i] = sinf(a);
		_cos_table[i] = cosf(a);
	}
}

void SMK_GL_finalizeMath(void)
{
}

void vec2_normalize(SMK_GL_Vec2 *v)
{
	float k = 1.0f / sqrtf(v->x * v->x + v->y * v->y);
	v->x *= k;
	v->y *= k;
}

void vec3_normalize(SMK_GL_Vec3 *v)
{
	float k = 1.0f / sqrtf(v->x * v->x + v->y * v->y + v->z * v->z);
	v->x *= k;
	v->y *= k;
	v->z *= k;
}

void vec4_normalize(SMK_GL_Vec4 *v)
{
	float k = 1.0f / sqrtf(v->x * v->x + v->y * v->y + v->z * v->z + v->w * v->w);
	v->x *= k;
	v->y *= k;
	v->z *= k;
	v->w *= k;
}

// the _e versions were the same code in the generic implementation
void vec2_normalize_e(SMK_GL_Vec2 *v)
{
	vec2_normalize(v);
}

void vec3_normalize_e(SMK_GL_Vec3 *v)
{
	vec3_normalize(v);
}

void vec4_normalize_e(SMK_GL_Vec4 *v)
{
	vec4_normalize(v);
}

void vec3_transfrom(SMK_GL_Vec3 *out, const SMK_GL_Matrix *m, const SMK_GL_Vec3 *v)
{
	float x = v->x, y = v->y, z = v->z;
	float w = 1.0f / (m->_41 * x + m->_42 * y + m->_43 * z + m->_44);
	out->x = (m->_11 * x + m->_12 * y + m->_13 * z + m->_14) * w;
	out->y = (m->_21 * x + m->_22 * y + m->_23 * z + m->_24) * w;
	out->z = (m->_31 * x + m->_32 * y + m->_33 * z + m->_34) * w;
}

void matrix_make_identity(SMK_GL_Matrix *m)
{
	memset(m, 0, sizeof(*m));
	m->_11 = m->_22 = m->_33 = m->_44 = 1.0f;
}

void vec3_matrix_mul(SMK_GL_Vec4 *out, const SMK_GL_Vec3 *v, const SMK_GL_Matrix *m)
{
	float x = v->x, y = v->y, z = v->z;
	out->x = x * m->_11 + y * m->_12 + z * m->_13 + m->_14;
	out->y = x * m->_21 + y * m->_22 + z * m->_23 + m->_24;
	out->z = x * m->_31 + y * m->_32 + z * m->_33 + m->_34;
	out->w = x * m->_41 + y * m->_42 + z * m->_43 + m->_44;
}

void vec4_matrix_mul(SMK_GL_Vec4 *out, const SMK_GL_Vec4 *v, const SMK_GL_Matrix *m)
{
	float x = v->x, y = v->y, z = v->z, w = v->w;
	out->x = x * m->_11 + y * m->_12 + z * m->_13 + w * m->_14;
	out->y = x * m->_21 + y * m->_22 + z * m->_23 + w * m->_24;
	out->z = x * m->_31 + y * m->_32 + z * m->_33 + w * m->_34;
	out->w = x * m->_41 + y * m->_42 + z * m->_43 + w * m->_44;
}

void matrix_mul(SMK_GL_Matrix *out, const SMK_GL_Matrix *m1, const SMK_GL_Matrix *m2)
{
	assert((out != m1) && (out != m2));
	const float *a = &m1->_11, *b = &m2->_11;
	float *o = &out->_11;
	for (int r = 0; r < 4; r++) {
		for (int c = 0; c < 4; c++) {
			o[r * 4 + c] = a[r * 4] * b[c] + a[r * 4 + 1] * b[4 + c] +
				a[r * 4 + 2] * b[8 + c] + a[r * 4 + 3] * b[12 + c];
		}
	}
}

// Counts how many of the box's eight corners lie inside each plane: none for
// some plane means the box is outside, all eight for every plane means inside.
static int classify(float d, float ex, float ey, float ez)
{
	int n = d < 0.0f;
	n += d < ex;
	n += d < ey;
	n += d < ez;
	n += d < ex + ey;
	n += d < ex + ez;
	n += d < ey + ez;
	n += d < ex + ey + ez;
	return n;
}

int boxIntersectionTest(const SMK_GL_Vec3 *boxMin, const SMK_GL_Vec3 *boxMax,
                        const SMK_GL_Frustum *frustum)
{
	int inside = 0;
	for (int i = 0; i < 6; i++) {
		const SMK_GL_Plane *p = &frustum->planes[i];
		float ex = (boxMax->x - boxMin->x) * p->a;
		float ey = (boxMax->y - boxMin->y) * p->b;
		float ez = (boxMax->z - boxMin->z) * p->c;
		float d = p->d - p->a * boxMin->x - p->b * boxMin->y - p->c * boxMin->z;
		int n = classify(d, ex, ey, ez);
		if (n == 0) {
			return 0;
		}
		if (n == 8) {
			inside++;
		}
	}
	return inside == 6 ? 2 : 1;
}

int boxMatrixIntersectionTest(const SMK_GL_Vec3 *boxMin, const SMK_GL_Vec3 *boxMax,
                              const SMK_GL_Matrix *m, const SMK_GL_Frustum *frustum)
{
	float x = boxMin->x, y = boxMin->y, z = boxMin->z;
	float dx = boxMax->x - x, dy = boxMax->y - y, dz = boxMax->z - z;
	int inside = 0;
	for (int i = 0; i < 6; i++) {
		const SMK_GL_Plane *p = &frustum->planes[i];
		float ex = m->_11 * dx * p->a + m->_21 * dx * p->b + dx * m->_31 * p->c;
		float ey = m->_12 * dy * p->a + m->_22 * dy * p->b + dy * m->_32 * p->c;
		float ez = m->_13 * dz * p->a + m->_23 * dz * p->b + dz * m->_33 * p->c;
		float d = p->d
			- p->a * (m->_12 * y + m->_13 * z + m->_14 + m->_11 * x)
			- p->b * (m->_22 * y + m->_23 * z + m->_24 + m->_21 * x)
			- p->c * (y * m->_32 + z * m->_33 + m->_34 + x * m->_31);
		int n = classify(d, ex, ey, ez);
		if (n == 0) {
			return 0;
		}
		if (n == 8) {
			inside++;
		}
	}
	return inside == 6 ? 2 : 1;
}

void rotateMatrix(SMK_GL_Matrix *out, float angle, const SMK_GL_Vec3 *axis)
{
	float c = cosf(angle);
	float s = sinf(angle);
	SMK_GL_Vec3 a = *axis;
	vec3_normalize(&a);
	float t = 1.0f - c;
	out->_11 = a.x * a.x * t + c;
	out->_12 = a.x * a.y * t - a.z * s;
	out->_13 = a.x * a.z * t + a.y * s;
	out->_14 = 0.0f;
	out->_21 = a.x * a.y * t + a.z * s;
	out->_22 = a.y * a.y * t + c;
	out->_23 = a.y * a.z * t - s * a.x;
	out->_24 = 0.0f;
	out->_31 = a.x * a.z * t - a.y * s;
	out->_32 = a.y * a.z * t + s * a.x;
	out->_33 = a.z * a.z * t + c;
	out->_34 = 0.0f;
	out->_41 = 0.0f;
	out->_42 = 0.0f;
	out->_43 = 0.0f;
	out->_44 = 1.0f;
}

void matrix_transpose(SMK_GL_Matrix *m)
{
	float t;
	t = m->_12; m->_12 = m->_21; m->_21 = t;
	t = m->_13; m->_13 = m->_31; m->_31 = t;
	t = m->_14; m->_14 = m->_41; m->_41 = t;
	t = m->_23; m->_23 = m->_32; m->_32 = t;
	t = m->_24; m->_24 = m->_42; m->_42 = t;
	t = m->_34; m->_34 = m->_43; m->_43 = t;
}

float matrix_det3x3(float a1, float a2, float a3, float b1, float b2, float b3,
                    float c1, float c2, float c3)
{
	return a1 * (b2 * c3 - b3 * c2) - b1 * (a2 * c3 - a3 * c2) + c1 * (a2 * b3 - a3 * b2);
}

void matrix_invert(SMK_GL_Matrix *out, const SMK_GL_Matrix *m)
{
	const float *s = &m->_11;
	float *o = &out->_11;
	// adjugate (transposed cofactors), then divide by the determinant
	o[0] = matrix_det3x3(s[5], s[9], s[13], s[6], s[10], s[14], s[7], s[11], s[15]);
	o[4] = -matrix_det3x3(s[4], s[8], s[12], s[6], s[10], s[14], s[7], s[11], s[15]);
	o[8] = matrix_det3x3(s[4], s[8], s[12], s[5], s[9], s[13], s[7], s[11], s[15]);
	o[12] = -matrix_det3x3(s[4], s[8], s[12], s[5], s[9], s[13], s[6], s[10], s[14]);
	o[1] = -matrix_det3x3(s[1], s[9], s[13], s[2], s[10], s[14], s[3], s[11], s[15]);
	o[5] = matrix_det3x3(s[0], s[8], s[12], s[2], s[10], s[14], s[3], s[11], s[15]);
	o[9] = -matrix_det3x3(s[0], s[8], s[12], s[1], s[9], s[13], s[3], s[11], s[15]);
	o[13] = matrix_det3x3(s[0], s[8], s[12], s[1], s[9], s[13], s[2], s[10], s[14]);
	o[2] = matrix_det3x3(s[1], s[5], s[13], s[2], s[6], s[14], s[3], s[7], s[15]);
	o[6] = -matrix_det3x3(s[0], s[4], s[12], s[2], s[6], s[14], s[3], s[7], s[15]);
	o[10] = matrix_det3x3(s[0], s[4], s[12], s[1], s[5], s[13], s[3], s[7], s[15]);
	o[14] = -matrix_det3x3(s[0], s[4], s[12], s[1], s[5], s[13], s[2], s[6], s[14]);
	o[3] = -matrix_det3x3(s[1], s[5], s[9], s[2], s[6], s[10], s[3], s[7], s[11]);
	o[7] = matrix_det3x3(s[0], s[4], s[8], s[2], s[6], s[10], s[3], s[7], s[11]);
	o[11] = -matrix_det3x3(s[0], s[4], s[8], s[1], s[5], s[9], s[3], s[7], s[11]);
	o[15] = matrix_det3x3(s[0], s[4], s[8], s[1], s[5], s[9], s[2], s[6], s[10]);
	float k = 1.0f / (o[0] * s[0] + o[4] * s[1] + o[8] * s[2] + o[12] * s[3]);
	for (int i = 0; i < 16; i++) {
		o[i] *= k;
	}
}

void planeFromPoints(SMK_GL_Plane *out, const SMK_GL_Vec3 *p1, const SMK_GL_Vec3 *p2,
                     const SMK_GL_Vec3 *p3)
{
	float ux = p1->x - p3->x, uy = p1->y - p3->y, uz = p1->z - p3->z;
	float vx = p2->x - p3->x, vy = p2->y - p3->y, vz = p2->z - p3->z;
	out->a = uy * vz - uz * vy;
	out->b = uz * vx - vz * ux;
	out->c = ux * vy - uy * vx;
	out->d = out->a * p3->x + out->b * p3->y + out->c * p3->z;
}

// flips the plane if the reference point is on its negative side
static void orient(SMK_GL_Plane *p, const SMK_GL_Vec3 *inside)
{
	if (p->a * inside->x + p->b * inside->y + p->c * inside->z - p->d < 0.0f) {
		p->a = -p->a;
		p->b = -p->b;
		p->c = -p->c;
		p->d = -p->d;
	}
}

void calcViewFrustum(SMK_GL_Frustum *f, const SMK_GL_Matrix *inverseViewProjection)
{
	static const SMK_GL_Vec3 cube[8] = {
		{ -1, -1, -1 }, { 1, -1, -1 }, { -1, 1, -1 }, { 1, 1, -1 },
		{ -1, -1, 1 }, { 1, -1, 1 }, { -1, 1, 1 }, { 1, 1, 1 },
	};
	SMK_GL_Vec3 *v = f->vertices;
	for (int i = 0; i < 8; i++) {
		SMK_GL_Vec3 t;
		vec3_transfrom(&t, inverseViewProjection, &cube[i]);
		v[i] = t;
	}
	planeFromPoints(&f->planes[0], &v[0], &v[1], &v[2]);
	orient(&f->planes[0], &v[4]);
	planeFromPoints(&f->planes[1], &v[6], &v[7], &v[5]);
	orient(&f->planes[1], &v[0]);
	planeFromPoints(&f->planes[2], &v[2], &v[6], &v[4]);
	orient(&f->planes[2], &v[7]);
	planeFromPoints(&f->planes[3], &v[7], &v[3], &v[5]);
	orient(&f->planes[3], &v[6]);
	planeFromPoints(&f->planes[4], &v[2], &v[3], &v[6]);
	orient(&f->planes[4], &v[5]);
	planeFromPoints(&f->planes[5], &v[1], &v[0], &v[4]);
	orient(&f->planes[5], &v[7]);
}

void scaleMatrix(SMK_GL_Matrix *out, const SMK_GL_Vec3 *scale)
{
	matrix_make_identity(out);
	out->_11 = scale->x;
	out->_22 = scale->y;
	out->_33 = scale->z;
}

void translateMatrix(SMK_GL_Matrix *out, const SMK_GL_Vec3 *offset)
{
	matrix_make_identity(out);
	out->_14 = offset->x;
	out->_24 = offset->y;
	out->_34 = offset->z;
}
