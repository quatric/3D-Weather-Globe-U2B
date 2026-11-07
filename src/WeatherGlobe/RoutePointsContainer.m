#import "RoutePointsContainer.h"

// A flight route drawn as a line strip of coloured scene points; subclasses
// project the points for the sphere or flat map and split the strip where
// it wraps around.

typedef struct WeatherGlobe_anon8 RoutePoint;

static NSUInteger _colorByte(float aComponent)
{
    float value = aComponent * 255.0f;
    if (value <= 0.0f)
        value = 0.0f;
    return (NSUInteger)value & 0xff;
}

@implementation RoutePointsContainer

- (NSPoint)currentFlyMapPoint
{
    return _currMapPoint;
}

// moves the plane 150 km per second along the route; it turns around at
// either end and returns NO while flying back
- (BOOL)flyStepWithDeltaTime:(double)aTime
{
    int count = (int)([_routePoints length] / sizeof(RoutePoint));
    if (!_backwardFly) {
        if (_currPointIndex >= count - 1) {
            _currPointIndex = count - 1;
            _backwardFly = YES;
        }
    } else if (_currPointIndex < 1) {
        _currPointIndex = 0;
        _backwardFly = NO;
    }
    const RoutePoint *points = [_routePoints bytes];
    NSPoint current = [self mapPointFromScenePosition:points[_currPointIndex].f0];
    NSPoint next = [self mapPointFromScenePosition:points[_currPointIndex + (_backwardFly ? -1 : 1)].f0];
    float distance = _distanceOnEarthFromGeoPoints(_geoPointFromMapPoint(current), _geoPointFromMapPoint(next));
    float offset = (float)(_currPointOffset + aTime * 150.0);
    _currPointOffset = offset;
    if (offset > distance) {
        _currPointOffset = 0.0f;
        _currPointIndex += _backwardFly ? -1 : 1;
        _currMapPoint = next;
    } else {
        // take the short way across the map's left and right edges
        float nextX = (float)next.x;
        if ((float)current.x > 0.8f && nextX < 0.2f)
            nextX += 1.0f;
        else if ((float)current.x < 0.2f && nextX > 0.8f)
            nextX -= 1.0f;
        float t = offset / distance;
        float x = t * (nextX - (float)current.x) + (float)current.x;
        _currMapPoint.y = (float)current.y + ((float)next.y - (float)current.y) * t;
        if (x > 1.0f)
            x -= 1.0f;
        else if (x < 0.0f)
            x += 1.0f;
        _currMapPoint.x = x;
    }
    return !_backwardFly;
}

- (void)stopFlying
{
}

- (void)startFlying
{
    _currPointIndex = 0;
    _currPointOffset = 0.0f;
    _backwardFly = NO;
    const RoutePoint *points = [_routePoints bytes];
    _currMapPoint = [self mapPointFromScenePosition:points[0].f0];
}

- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition
{
    return NSZeroPoint;
}

- (id)routeDrawable
{
    return _routeDrawable;
}

- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData
{
}

- (void)adjustToRoutePointsArray:(id)aArray
{
    const RoutePoint *points = [aArray bytes];
    int count = (int)([aArray length] / sizeof(RoutePoint));
    NSMutableData *data = [NSMutableData data];
    for (int i = 1; i < count; i++) {
        [self _appendRouteBetweenPoint:(RoutePoint *)points andPoint:(RoutePoint *)(points + 1) toData:data];
        points++;
    }
    [_routePoints release];
    _routePoints = [data length] ? [[NSData alloc] initWithData:data] : nil;
    [self _createRouteMesh];
}

- (void)_createRouteMesh
{
    // indices of the points where the strip is broken
    NSData *breaks = [self estimateBreakes];
    unsigned int breaksCount = (unsigned int)([breaks length] / sizeof(int));
    const int *breakIndices = [breaks bytes];
    unsigned int pointsCount = (unsigned int)([_routePoints length] / sizeof(RoutePoint));
    int linesCount = (int)(pointsCount - breaksCount) - 1;
    [_routeDrawable release];
    _routeDrawable = nil;
    if (pointsCount < 2)
        return;

    [_container beginAccumulationBlock];
    SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:0x42 usage:0 verticesCount:pointsCount primitivesCount:linesCount primitiveType:1] autorelease];
    SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
    [mesh setMaterial:material];
    SMK_GL_Color ambient = {1.0f, 1.0f, 1.0f, 1.0f};
    SMK_GL_Color diffuse = {0.0f, 0.0f, 0.0f, 0.2f};
    [material setAmbient:ambient];
    [material setDiffuse:diffuse];

    // vertices: x, y, z and an RGBA byte colour
    SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
    float *vertex = [vertexBuffer lock:2];
    const RoutePoint *point = [_routePoints bytes];
    for (unsigned int i = 0; i < pointsCount; i++, point++, vertex += 4) {
        vertex[0] = point->f0.f0;
        vertex[1] = point->f0.f1;
        vertex[2] = point->f0.f2;
        uint8_t *color = (uint8_t *)&vertex[3];
        color[0] = (uint8_t)_colorByte(point->f1.f0);
        color[1] = (uint8_t)_colorByte(point->f1.f1);
        color[2] = (uint8_t)_colorByte(point->f1.f2);
        color[3] = 0xff;
    }
    [vertexBuffer unlock];

    // line segments between consecutive points, skipping each break
    SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
    void *indices = [indexBuffer lock:2];
    BOOL wide = [indexBuffer are32BitIndices];
    int breakIndex = 0;
    unsigned int index = 0;
    for (int i = 0; i < linesCount; i++) {
        if (wide) {
            ((uint32_t *)indices)[i * 2] = index;
            ((uint32_t *)indices)[i * 2 + 1] = index + 1;
        } else {
            ((uint16_t *)indices)[i * 2] = (uint16_t)index;
            ((uint16_t *)indices)[i * 2 + 1] = (uint16_t)(index + 1);
        }
        index++;
        if (breaksCount && breakIndex < (int)breaksCount && breakIndex + 1 + i == breakIndices[breakIndex]) {
            breakIndex++;
            index++;
        }
    }
    [indexBuffer unlock];

    _routeDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
    [_routeDrawable setPerformsVisibilityCheck:NO];
    [_container endAccumulationBlock];
}

- (id)estimateBreakes
{
    return nil;
}

// one segment for every 2 degrees of arc
- (void)_appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 toData:(id)aData
{
    float angle = acosf(aPoint->f0.f0 * aPoint2->f0.f0 + aPoint->f0.f1 * aPoint2->f0.f1 + aPoint->f0.f2 * aPoint2->f0.f2);
    [self appendRouteBetweenPoint:aPoint andPoint:aPoint2 segmentsCount:(int)(angle / 0.034904014f + 1.0f) toData:aData];
}

- (void)dealloc
{
    [_routePoints release];
    [_routeDrawable release];
    [super dealloc];
}

- (id)initWithGLContainer:(id)aContainer
{
    self = [super init];
    if (self != nil)
        _container = aContainer;
    return self;
}

@end
