// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/GenericImp/SMK_GL_math.c
// Vectors, row-major 4x4 matrices, planes and view frustums.
#ifndef SMK_GL_MATH_H
#define SMK_GL_MATH_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SMK_GL_Vec2 { float x, y; } SMK_GL_Vec2;
typedef struct SMK_GL_Vec3 { float x, y, z; } SMK_GL_Vec3;
typedef struct SMK_GL_Vec4 { float x, y, z, w; } SMK_GL_Vec4;
typedef struct SMK_GL_Color { float r, g, b, a; } SMK_GL_Color;
// a*x + b*y + c*z = d
typedef struct SMK_GL_Plane { float a, b, c, d; } SMK_GL_Plane;
typedef struct SMK_GL_Matrix {
	float _11, _12, _13, _14;
	float _21, _22, _23, _24;
	float _31, _32, _33, _34;
	float _41, _42, _43, _44;
} SMK_GL_Matrix;
// corners of the clip-space cube in world space, and the six side planes,
// oriented so the inside is positive
typedef struct SMK_GL_Frustum {
	SMK_GL_Vec3 vertices[8];
	SMK_GL_Plane planes[6];
} SMK_GL_Frustum;

// the names the metadata generator gave these layouts
#define SMKGL_anon1 SMK_GL_Vec3
#define SMKGL_anon2 SMK_GL_Matrix
#define SMKGL_anon3 SMK_GL_Vec3
#define SMKGL_anon4 SMK_GL_Color
#define SMKGL_anon5 SMK_GL_Frustum
#define SMKGL_anon6 SMK_GL_Color
#define SMKGL_anon7 SMK_GL_Plane
#define SMKGL_anon8 SMK_GL_Frustum
#define SMKGL_anon9 SMK_GL_Matrix
#define SMKGL_anon10 SMK_GL_Vec4
#define SMKGL_anon13 SMK_GL_Vec2

// sin and cos of i * 2pi / 1024 for i in 0..1027
#define SMK_GL_TRIG_TABLE_SIZE 1028
extern float *_sin_table;
extern float *_cos_table;

void SMK_GL_initMath(void);
void SMK_GL_finalizeMath(void);

void vec2_normalize(SMK_GL_Vec2 *v);
void vec3_normalize(SMK_GL_Vec3 *v);
void vec4_normalize(SMK_GL_Vec4 *v);
void vec2_normalize_e(SMK_GL_Vec2 *v);
void vec3_normalize_e(SMK_GL_Vec3 *v);
void vec4_normalize_e(SMK_GL_Vec4 *v);
// projective transform: out = (m * (v, 1)).xyz / w
void vec3_transfrom(SMK_GL_Vec3 *out, const SMK_GL_Matrix *m, const SMK_GL_Vec3 *v);
// out = m * (v, 1); writes four floats
void vec3_matrix_mul(SMK_GL_Vec4 *out, const SMK_GL_Vec3 *v, const SMK_GL_Matrix *m);
void vec4_matrix_mul(SMK_GL_Vec4 *out, const SMK_GL_Vec4 *v, const SMK_GL_Matrix *m);

void matrix_make_identity(SMK_GL_Matrix *m);
void matrix_mul(SMK_GL_Matrix *out, const SMK_GL_Matrix *m1, const SMK_GL_Matrix *m2);
void matrix_transpose(SMK_GL_Matrix *m);
float matrix_det3x3(float a1, float a2, float a3, float b1, float b2, float b3,
                    float c1, float c2, float c3);
void matrix_invert(SMK_GL_Matrix *out, const SMK_GL_Matrix *m);
void rotateMatrix(SMK_GL_Matrix *out, float angle, const SMK_GL_Vec3 *axis);
void scaleMatrix(SMK_GL_Matrix *out, const SMK_GL_Vec3 *scale);
void translateMatrix(SMK_GL_Matrix *out, const SMK_GL_Vec3 *offset);

void planeFromPoints(SMK_GL_Plane *out, const SMK_GL_Vec3 *p1, const SMK_GL_Vec3 *p2,
                     const SMK_GL_Vec3 *p3);
void calcViewFrustum(SMK_GL_Frustum *frustum, const SMK_GL_Matrix *inverseViewProjection);
// 0: the box is outside the frustum, 1: it intersects it, 2: it's inside
int boxIntersectionTest(const SMK_GL_Vec3 *boxMin, const SMK_GL_Vec3 *boxMax,
                        const SMK_GL_Frustum *frustum);
int boxMatrixIntersectionTest(const SMK_GL_Vec3 *boxMin, const SMK_GL_Vec3 *boxMax,
                              const SMK_GL_Matrix *m, const SMK_GL_Frustum *frustum);

#ifdef __cplusplus
}
#endif

#endif
