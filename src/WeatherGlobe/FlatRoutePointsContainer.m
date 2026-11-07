#import "FlatRoutePointsContainer.h"

// Routes on the flat map: great circle arcs projected to map coordinates,
// with an extra pair of points at the map edges where an arc wraps around.

typedef struct WeatherGlobe_anon8 RoutePoint;

void _routeStepRotation(const RoutePoint *aPoint, const RoutePoint *aPoint2, NSInteger aCount, SMK_GL_Matrix *aRotation);

@implementation FlatRoutePointsContainer

- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition
{
    return NSMakePoint(aPosition.f0, aPosition.f1);
}

- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData
{
    RoutePoint point;
    memset(&point, 0, sizeof(point));
    SMK_GL_Matrix step, rotation;
    _routeStepRotation(aPoint, aPoint2, aCount, &step);
    matrix_make_identity(&rotation);
    float previousX = (float)_mapPointFromEarthVec((const SMK_GL_Vec3 *)&aPoint->f0).x;
    for (int i = 0; i <= aCount; i++) {
        float t = (float)i / (float)aCount;
        SMK_GL_Vec4 rotated;
        vec3_matrix_mul(&rotated, (const SMK_GL_Vec3 *)&aPoint->f0, &rotation);
        SMK_GL_Vec3 position = {rotated.x, rotated.y, rotated.z};
        vec3_normalize(&position);
        NSPoint mapPoint = _mapPointFromEarthVec(&position);
        float x = (float)mapPoint.x, y = (float)mapPoint.y;
        if (i > 0 && fabsf(x - previousX) > 0.75f) {
            // the arc wraps: end it at one edge and restart it at the other,
            // at the height where it crosses
            const RoutePoint *last = (const RoutePoint *)((const char *)[aData bytes] + [aData length]) - 1;
            RoutePoint lastEdge = *last, edge = *last;
            float lastX = last->f0.f0;
            float distance = x;
            edge.f0.f0 = 0.0f;
            if (x >= 0.5f) {
                distance = 1.0f - x;
                edge.f0.f0 = 1.0f;
            }
            lastEdge.f0.f0 = 0.0f;
            if (lastX >= 0.5f) {
                lastX = 1.0f - lastX;
                lastEdge.f0.f0 = 1.0f;
            }
            float edgeY = (distance * last->f0.f1 + y * lastX) / (distance + lastX + 1e-10f);
            lastEdge.f0.f1 = edgeY;
            edge.f0.f1 = edgeY;
            [aData appendBytes:&lastEdge length:sizeof(lastEdge)];
            [aData appendBytes:&edge length:sizeof(edge)];
        }
        point.f0.f0 = x;
        point.f0.f1 = y;
        point.f1.f0 = (1.0f - t) * aPoint->f1.f0 + t * aPoint2->f1.f0;
        point.f1.f1 = (1.0f - t) * aPoint->f1.f1 + t * aPoint2->f1.f1;
        point.f1.f2 = (1.0f - t) * aPoint->f1.f2 + t * aPoint2->f1.f2;
        point.f1.f3 = 1.0f;
        SMK_GL_Matrix next;
        matrix_mul(&next, &rotation, &step);
        rotation = next;
        [aData appendBytes:&point length:sizeof(point)];
        previousX = x;
    }
}

// indices of the points after which the route jumps across the map edge
- (id)estimateBreakes
{
    int count = (int)([_routePoints length] / sizeof(RoutePoint));
    const RoutePoint *points = [_routePoints bytes];
    NSMutableData *breaks = nil;
    for (int i = 0; i < count - 1; i++) {
        if (fabsf(points[i + 1].f0.f0 - points[i].f0.f0) > 0.75f) {
            if (breaks == nil)
                breaks = [NSMutableData data];
            [breaks appendBytes:&i length:sizeof(i)];
        }
    }
    return breaks;
}

@end
