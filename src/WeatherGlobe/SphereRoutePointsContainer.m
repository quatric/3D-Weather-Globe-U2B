#import "SphereRoutePointsContainer.h"

// Routes on the globe: great circle arcs lifted slightly above the surface.

typedef struct WeatherGlobe_anon8 RoutePoint;

// rotation taking aPoint towards aPoint2 by 1/aCount of the arc between them
void _routeStepRotation(const RoutePoint *aPoint, const RoutePoint *aPoint2, NSInteger aCount, SMK_GL_Matrix *aRotation)
{
    SMK_GL_Vec3 axis;
    axis.x = aPoint->f0.f1 * aPoint2->f0.f2 - aPoint->f0.f2 * aPoint2->f0.f1;
    axis.y = aPoint->f0.f2 * aPoint2->f0.f0 - aPoint->f0.f0 * aPoint2->f0.f2;
    axis.z = aPoint->f0.f0 * aPoint2->f0.f1 - aPoint->f0.f1 * aPoint2->f0.f0;
    if (axis.x == axis.y && axis.z == axis.y && axis.x == 0.0f)
        axis.z = 1.0f;
    vec3_normalize(&axis);
    float dot = aPoint->f0.f0 * aPoint2->f0.f0 + aPoint->f0.f1 * aPoint2->f0.f1 + aPoint->f0.f2 * aPoint2->f0.f2;
    rotateMatrix(aRotation, (float)(acos(dot) / (float)aCount), &axis);
}

@implementation SphereRoutePointsContainer

- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition
{
    vec3_normalize((SMK_GL_Vec3 *)&aPosition);
    return _mapPointFromEarthVec((SMK_GL_Vec3 *)&aPosition);
}

- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData
{
    SMK_GL_Matrix step, rotation;
    _routeStepRotation(aPoint, aPoint2, aCount, &step);
    matrix_make_identity(&rotation);
    for (int i = 0; i <= aCount; i++) {
        float t = (float)i / (float)aCount;
        SMK_GL_Vec4 rotated;
        vec3_matrix_mul(&rotated, (const SMK_GL_Vec3 *)&aPoint->f0, &rotation);
        SMK_GL_Vec3 position = {rotated.x, rotated.y, rotated.z};
        vec3_normalize(&position);
        RoutePoint point;
        point.f0.f0 = position.x * _radius;
        point.f0.f1 = position.y * _radius;
        point.f0.f2 = position.z * _radius;
        point.f1.f0 = (1.0f - t) * aPoint->f1.f0 + t * aPoint2->f1.f0;
        point.f1.f1 = (1.0f - t) * aPoint->f1.f1 + t * aPoint2->f1.f1;
        point.f1.f2 = (1.0f - t) * aPoint->f1.f2 + t * aPoint2->f1.f2;
        point.f1.f3 = 1.0f;
        SMK_GL_Matrix next;
        matrix_mul(&next, &rotation, &step);
        rotation = next;
        [aData appendBytes:&point length:sizeof(point)];
    }
}

- (void)dealloc
{
    [super dealloc];
}

- (id)initWithGLContainer:(id)aContainer radius:(CGFloat)aRadius
{
    self = [super initWithGLContainer:aContainer];
    if (self != nil)
        _radius = (float)(aRadius * 1.003);
    return self;
}

@end
