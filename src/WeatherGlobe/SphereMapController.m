#import "SphereMapController.h"

// The position is the camera's turn around the axis (x) and its latitude
// (y), both fractions of the full range.

static float _wrapUnit(float aValue)
{
    if (aValue < 0.0f)
        return aValue + 1.0f;
    if (aValue > 1.0f)
        return aValue - 1.0f;
    return aValue;
}

@implementation SphereMapController

- (CGFloat)precisionForEntryMarker
{
    return ((float)[Preferences markersScale] * 8.5f) / (float)[self zoomFactor];
}

- (void)zoomOutToGeoPoint:(NSPoint)aPoint
{
    [self _fluentlyDoNewScale:(float)[self scale] - 0.16666667f newXAngle:aPoint.x / -360.0 + 0.25 newYAngle:aPoint.y / 180.0 + 0.5 autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

- (void)zoomInToGeoPoint:(NSPoint)aPoint
{
    [self _fluentlyDoNewScale:(float)[self scale] + 0.16666667f newXAngle:aPoint.x / -360.0 + 0.25 newYAngle:aPoint.y / 180.0 + 0.5 autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

- (void)scrollWithDiff:(NSPoint)aDiff fromViewPoint:(NSPoint)aPoint
{
    [super scrollWithDiff:NSMakePoint(aDiff.x / -10.0, aDiff.y / 10.0) fromViewPoint:aPoint];
}

- (void)mouseDraggedWithDiff:(NSPoint)aDiff
{
    [super mouseDraggedWithDiff:aDiff];
    NSRect frame = [[_controller glView] frame];
    _position.x = aDiff.x / (frame.size.width * 0.5f * _zoomFactor) + _positionOnDown.x;
    _position.y = aDiff.y / (frame.size.height * 0.5f * _zoomFactor) + _positionOnDown.y;
    [self refreshCameraSettings];
    [super setPosition:_position];
}

// Turns to the middle of the selection on the globe; with only a part of
// the selection on the globe, its off-globe corner is pulled in first.
- (void)zoomToSelectionRect:(NSRect)aRect
{
    NSPoint corner1 = aRect.origin;
    NSPoint corner2 = NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height);
    NSPoint target = NSMakePoint((corner1.x + corner2.x) * 0.5f, (corner1.y + corner2.y) * 0.5f);
    BOOL centerOnGlobe = [[self scene] geoPointFromNormalizedViewPoint:&target];
    float zoomFactor = [self _calculateZoomFactorForSelectionRect:aRect];
    float scale;
    if (_optionOnMouseDown)
        scale = (float)[self scale] - 0.16666667f;
    else
        scale = [self _scaleFromZoomFactor:zoomFactor];
    if (!centerOnGlobe) {
        NSPoint geo1 = corner1, geo2 = corner2;
        BOOL onGlobe1 = [[self scene] geoPointFromNormalizedViewPoint:&geo1];
        BOOL onGlobe2 = [[self scene] geoPointFromNormalizedViewPoint:&geo2];
        if (!onGlobe1 && !onGlobe2) {
            [self _fluentlyDoNewScale:scale newXAngle:_position.x newYAngle:1.0 - _position.y autoselectCountry:nil autoselectState:nil autoselectTimeZone:nil];
            return;
        }
        if (!onGlobe1)
            geo1 = [self _findPointOnGlobeInPartialSelectionWithPoint1:corner2 point2:&corner1];
        else if (!onGlobe2)
            geo2 = [self _findPointOnGlobeInPartialSelectionWithPoint1:corner1 point2:&corner2];
        if (geo1.x > 0.0 && geo2.x < 0.0)
            geo2.x += 360.0;
        target = NSMakePoint((geo1.x + geo2.x) * 0.5f, (geo1.y + geo2.y) * 0.5f);
    }
    [self _fluentlyDoNewScale:scale newXAngle:target.x / -360.0 + 0.25 newYAngle:target.y / 180.0 + 0.5 autoselectCountry:nil autoselectState:nil autoselectTimeZone:nil];
}

- (CGFloat)_calculateZoomFactorForSelectionRect:(NSRect)aRect
{
    float factor = 1.0f / aRect.size.width;
    if (1.0f / aRect.size.height <= factor)
        factor = 1.0f / aRect.size.height;
    factor *= _zoomFactor;
    return factor <= 4.0f ? factor : 4.0f;
}

// halves the way from aPoint2 to aPoint1 until it lands on the globe
- (NSPoint)_findPointOnGlobeInPartialSelectionWithPoint1:(NSPoint)aPoint1 point2:(NSPoint *)aPoint2
{
    NSPoint point;
    do {
        point = NSMakePoint((aPoint1.x + aPoint2->x) * 0.5f, (aPoint1.y + aPoint2->y) * 0.5f);
        *aPoint2 = point;
    } while (![[self scene] geoPointFromNormalizedViewPoint:&point]);
    return point;
}

- (void)zoomToCurrentCountry
{
    if (![Preferences regionHighlightIsEnabled])
        return;
    NSInteger mode = [Preferences regionHighLightMode];
    NSString *uid;
    if (mode < 2)
        uid = _prevCountryUID;
    else if (mode == 2)
        uid = _prevStateUID;
    else
        return;
    id info = [[AtlasDatabase database] infoWithShapeUID:uid lod:0];
    if (info == nil)
        return;
    NSRect rect = _mapRectFromGeoRect([info enclosingRect]);
    NSPoint position = [self positionPointFromMapPoint:NSMakePoint(rect.size.width * 0.5f + rect.origin.x, 1.0f - (rect.size.height * 0.5f + rect.origin.y))];
    [self _fluentlyDoNewScale:1.0 newXAngle:position.x newYAngle:position.y autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

// Animates scale and position to the new ones the short way round, then
// highlights the given regions.
- (void)_fluentlyDoNewScale:(CGFloat)aScale newXAngle:(CGFloat)aAngle newYAngle:(CGFloat)aAngle2 autoselectCountry:(id)aCountry autoselectState:(id)aState autoselectTimeZone:(id)aZone
{
    if (_scaleTimer != nil)
        return;
    [_autoselectedCountryUID release];
    [_autoselectedStateUID release];
    [_autoselectedTimeZoneUID release];
    _autoselectedCountryUID = [aCountry retain];
    _autoselectedStateUID = [aState retain];
    _autoselectedTimeZoneUID = [aZone retain];
    [[self scene] highlightCountry:nil state:nil timeZone:nil];
    float scale = aScale;
    if (scale < 0.0f)
        scale = 0.0f;
    else if (scale > 1.0f)
        scale = 1.0f;
    float targetX = _wrapUnit(aAngle);
    float targetY = _wrapUnit(1.0f - (float)aAngle2);
    float x = _position.x;
    float larger = x <= targetX ? targetX : x;
    float smaller = x <= targetX ? x : targetX;
    if (smaller + (1.0f - larger) < fabsf(targetX - x)) {
        if (targetX <= x)
            targetX += 1.0f;
        else
            targetX -= 1.0f;
    }
    _startScale = [self scale];
    _targetScale = scale;
    _startXAngle = _wrapUnit(_position.x);
    _targetXAngle = targetX;
    _startYAngle = _wrapUnit(_position.y);
    _targetYAngle = targetY;
    _startFluentlyScaleTime = [NSDate timeIntervalSinceReferenceDate];
    [self _timerOnFluentlyScale:nil];
    [self refreshView];
}

- (void)_timerOnFluentlyScale:(id)aScale
{
    double progress = ([NSDate timeIntervalSinceReferenceDate] - _startFluentlyScaleTime) / 0.35;
    [_scaleTimer invalidate];
    if (progress < 1.0) {
        float scale = (float)(_startScale + (double)(_targetScale - _startScale) * progress);
        _position.x = (float)(_startXAngle + (double)(_targetXAngle - _startXAngle) * progress);
        _position.y = (float)(_startYAngle + progress * (double)(_targetYAngle - _startYAngle));
        [_controller setScaleValue:scale];
        [self adjustToScale:scale];
        [self refreshCameraSettings];
        _scaleTimer = [NSTimer scheduledTimerWithTimeInterval:0.0001 target:self selector:@selector(_timerOnFluentlyScale:) userInfo:nil repeats:NO];
    } else {
        _scaleTimer = nil;
        [_controller setScaleValue:_targetScale];
        [self adjustToScale:_targetScale];
        _position.x = _targetXAngle;
        _position.y = _targetYAngle;
        [self refreshCameraSettings];
        AtlasDatabase *database = [AtlasDatabase database];
        id country = [database infoWithShapeUID:_autoselectedCountryUID lod:[self countryBoundariesLOD]];
        [_autoselectedCountryUID release];
        _autoselectedCountryUID = nil;
        id state = [database infoWithShapeUID:_autoselectedStateUID lod:[self countryBoundariesLOD]];
        [_autoselectedStateUID release];
        _autoselectedStateUID = nil;
        id timeZone = [database infoWithShapeUID:_autoselectedTimeZoneUID lod:[self countryBoundariesLOD]];
        [_autoselectedTimeZoneUID release];
        _autoselectedTimeZoneUID = nil;
        [[self scene] highlightCountry:country state:state timeZone:timeZone];
    }
    [super setPosition:_position];
}

- (NSInteger)countryBoundariesLOD
{
    return _zoomFactor > 2.0f;
}

- (NSPoint)mapPointFromPositionPoint:(NSPoint)aPoint
{
    float x = 0.75f - aPoint.x;
    return NSMakePoint(x - floorf(x), 1.0f - aPoint.y);
}

- (NSPoint)positionPointFromMapPoint:(NSPoint)aPoint
{
    float x = 0.75f - aPoint.x;
    return NSMakePoint(x - floorf(x), 1.0f - aPoint.y);
}

- (id)normalizedViewPointsFromMapPoint:(NSPoint)aPoint
{
    BOOL onViewedSide = NO;
    NSPoint point = [[self scene] get2DCoordinatesFromGeoPoint:_geoPointFromMapPoint(aPoint) onViewedSide:&onViewedSide];
    if (!onViewedSide)
        return [NSArray array];
    return [NSArray arrayWithObject:[NSValue valueWithPoint:NSMakePoint(point.x * 0.5f + 0.5f, point.y * 0.5f + 0.5f)]];
}

- (BOOL)canConvertNormalizedViewPoint:(NSPoint)aPoint toGeoPoint:(NSPoint *)aPoint2
{
    if (!NSPointInRect(aPoint, NSMakeRect(0.0, 0.0, 1.0, 1.0)) || ![_sphereMapScene geoPointFromNormalizedViewPoint:&aPoint])
        return NO;
    if (aPoint2 != NULL)
        *aPoint2 = aPoint;
    return YES;
}

// moves the x axis onto the globe's normal at aPoint
- (struct WeatherGlobe_anon3)getMatrix_XAxisToNormalForGeoPoint:(NSPoint)aPoint
{
    static const SMK_GL_Vec3 vectorY = {0, 1, 0};
    static const SMK_GL_Vec3 vectorZ = {0, 0, 1};
    NSPoint radians = _radiansFromDegreesPoint(aPoint);
    SMK_GL_Matrix rotY, rotZ, translation, rotation;
    struct WeatherGlobe_anon3 result;
    rotateMatrix(&rotY, -(float)radians.y, &vectorY);
    rotateMatrix(&rotZ, (float)radians.x, &vectorZ);
    struct WeatherGlobe_anon2 spacePoint = [self drawedSpacePointFromGeoPoint:aPoint];
    translateMatrix(&translation, (const SMK_GL_Vec3 *)&spacePoint);
    matrix_mul(&rotation, &rotZ, &rotY);
    matrix_mul((SMK_GL_Matrix *)&result, &translation, &rotation);
    return result;
}

- (NSPoint)get2DCoordinatesFromGeoPoint:(NSPoint)aPoint
{
    return [_sphereMapScene get2DCoordinatesFromGeoPoint:aPoint onViewedSide:NULL];
}

- (CGFloat)defaultScale
{
    float scale = [super defaultScale];
    return scale >= 0.0f ? scale : 0.33f;
}

- (CGFloat)scale
{
    return [self _scaleFromZoomFactor:_zoomFactor];
}

- (void)adjustToScale:(CGFloat)aScale
{
    [super adjustToScale:aScale];
    _zoomFactor = [self _zoomFactorFromScale:aScale];
    [_sphereMapScene setZoomFactor:_zoomFactor];
}

- (CGFloat)_scaleFromZoomFactor:(CGFloat)aFactor
{
    return (float)log2((float)aFactor) / _zoomMultiplier;
}

- (CGFloat)_zoomFactorFromScale:(CGFloat)aScale
{
    return (float)pow(2.0, (float)aScale * _zoomMultiplier);
}

- (id)scene
{
    return _sphereMapScene;
}

// The camera circles the globe at distance 10, looking at its center; in
// tilted mode its up vector leans by the earth's 23.5 degree tilt.
- (void)refreshCameraSettings
{
    _position.x -= floorf(_position.x);
    if (_position.y < 0.01f)
        _position.y = 0.01f;
    else if (_position.y > 0.99f)
        _position.y = 0.99f;
    double latitude = (double)(((float)_position.y - 0.5f) * -3.1415927f);
    float distance = (float)(cos(latitude) * 10.0);
    double longitude = (double)((float)_position.x * 6.2831855f);
    SMK_GL_Vec3 position = {distance * (float)sin(longitude), (float)cos(longitude) * distance, (float)(sin(latitude) * 10.0)};
    [(SMK_GL_Camera *)[_sphereMapScene camera] setPosition:&position];
    SMK_GL_Vec3 direction = {-position.x, -position.y, -position.z};
    [[_sphereMapScene camera] setViewDirection:&direction];
    SMK_GL_Vec3 up = {0.0f, 0.0f, 1.0f};
    if ([Preferences earthTiltedMode]) {
        SMK_GL_Matrix tilt;
        SMK_GL_Vec4 tilted;
        rotateMatrix(&tilt, 0.41015238f, &position);
        vec3_matrix_mul(&tilted, &up, &tilt);
        up = (SMK_GL_Vec3){tilted.x, tilted.y, tilted.z};
    }
    [[_sphereMapScene camera] setUpVector:&up];
    [super refreshCameraSettings];
    [self refreshView];
}

- (NSInteger)degreesGridStep
{
    NSInteger detalization = [Preferences gridDetalization];
    float zoomFactor = [self zoomFactor];
    if (detalization == 1)
        return 5;
    if (detalization == 0) {
        if (zoomFactor > 3.5f)
            return 5;
        if (zoomFactor > 2.0f)
            return 10;
    } else if (detalization == 2) {
        return 10;
    }
    return 20;
}

- (NSPoint)rotationAngles
{
    float x = 0.25f - _position.x;
    return NSMakePoint(x - floorf(x), 1.0f - _position.y);
}

- (CGFloat)zoomFactor
{
    return _zoomFactor;
}

- (void)sceneWillBeInstalled
{
    [super sceneWillBeInstalled];
    [_controller setMinimapWorldRect:NSZeroRect];
}

- (void)dealloc
{
    [_sphereMapScene release];
    [super dealloc];
}

- (id)initWithMainWindowController:(id)aController
{
    self = [super initWithMainWindowController:aController];
    if (self == nil)
        return nil;
    _sphereMapScene = [[SphereMapScene alloc] initWithContainer:[[_controller glView] objectsContainer] controller:self];
    if (![self getDefaultPosition:&_position])
        _position = NSMakePoint(0.5, 0.5);
    _zoomFactor = 1.0f;
    if (![self getDefaultCompassValue:&_compassValue])
        _compassValue = 3;
    _zoomMultiplier = 2.0f;
    [self refreshCameraSettings];
    return self;
}

@end
