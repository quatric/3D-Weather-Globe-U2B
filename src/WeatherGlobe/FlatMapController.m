#import "FlatMapController.h"

// The flat map's panel controller. The position is the view centre in map
// units (x wraps around, y runs down from the top); the map scale value is
// the magnification, 2^(5 × the scale slider value), from 1 to 32.

// keeps the view from scrolling past the top and bottom of the map
static float _clampedY(float aY, float aScaleValue)
{
    float visible = -1.0f / aScaleValue + 1.0f;
    float low = visible * -0.5f + 0.5f;
    if (aY < low)
        aY = low;
    float high = visible * 0.5f + 0.5f;
    if (aY > high)
        aY = high;
    return aY;
}

@implementation FlatMapController

- (CGFloat)precisionForEntryMarker
{
    return (float)(int)((float)[Preferences markersScale] * 4.0f * ((float)[self mapScaleValue] * 0.02f + 0.98f));
}

- (void)sliderDidStopTracking:(id)aTracking
{
    _isTrackingSlider = NO;
    [[self scene] setNeedLayoutCaptions:YES];
    [self refreshView];
}

- (void)sliderWillStartTracking:(id)aTracking
{
    _yPositionBeforeTrackingScaleSlider = _position.y;
    [[self scene] setNeedLayoutCaptions:NO];
    _isTrackingSlider = YES;
}

- (NSRect)rect2DFromWorldRect:(NSRect)aRect
{
    NSRect frame = [[[self windowController] glView] frame];
    float height = 1.0f / _mapScaleValue;
    float x = (float)[self xPosition];
    float y = (float)[self yPosition];
    float xFactor = 4.0f / ((height / (float)frame.size.height) * (float)frame.size.width);
    float yFactor = 2.0f / height;
    return NSMakeRect(xFactor * ((float)aRect.origin.x - x), yFactor * ((float)aRect.origin.y - (1.0f - y)),
                      (float)aRect.size.width * xFactor, (float)aRect.size.height * yFactor);
}

// zooms so the selection fills the view, or with option one step out
- (void)zoomToSelectionRect:(NSRect)aRect
{
    NSPoint p1 = [self _mapPointFromNormalizedViewPoint:aRect.origin];
    NSPoint p2 = [self _mapPointFromNormalizedViewPoint:NSMakePoint(aRect.size.width + aRect.origin.x, aRect.size.height + aRect.origin.y)];
    float scale;
    if (_optionOnMouseDown) {
        scale = (float)pow(2.0, log2f((float)[self mapScaleValue]) - 0.8333333f);
    } else if ((float)p2.x - (float)p1.x <= (float)p2.y - (float)p1.y) {
        scale = 1.0f / ((float)p2.y - (float)p1.y);
    } else {
        scale = 1.0f / ((float)p2.x - (float)p1.x);
    }
    [self _fluentlyDoNewScale:scale toMapPoint:NSMakePoint(((float)p1.x + (float)p2.x) * 0.5f, ((float)p1.y + (float)p2.y) * 0.5f) autoselectCountry:nil autoselectState:nil autoselectTimeZone:nil];
}

- (void)zoomOutToGeoPoint:(NSPoint)aPoint
{
    float scale = (float)pow(2.0, log2f((float)[self mapScaleValue]) - 0.8333333f);
    [self _fluentlyDoNewScale:scale toMapPoint:_mapPointFromGeoPoint(aPoint) autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

- (void)zoomInToGeoPoint:(NSPoint)aPoint
{
    float scale = (float)pow(2.0, log2f((float)[self mapScaleValue]) + 0.8333333f);
    [self _fluentlyDoNewScale:scale toMapPoint:_mapPointFromGeoPoint(aPoint) autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

- (void)zoomToCurrentCountry
{
    if (![Preferences regionHighlightIsEnabled] || _prevCountryUID == nil)
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
    NSRect frame = [[_controller glView] frame];
    float width = (((float)rect.size.width + (float)rect.size.width) * (float)frame.size.height) / (float)frame.size.width;
    float size = (float)rect.size.height <= width ? width : (float)rect.size.height;
    [self _fluentlyDoNewScale:1.0f / size toMapPoint:NSMakePoint((float)rect.size.width * 0.5f + (float)rect.origin.x, (float)rect.size.height * 0.5f + (float)rect.origin.y) autoselectCountry:_prevCountryUID autoselectState:_prevStateUID autoselectTimeZone:_prevTimeZoneUID];
}

- (void)endTrackingAtViewPoint:(NSPoint)aPoint
{
    [super endTrackingAtViewPoint:aPoint];
    [self _recacheImagesWithDelay];
}

- (void)scrollWithDiff:(NSPoint)aDiff fromViewPoint:(NSPoint)aPoint
{
    [super scrollWithDiff:NSMakePoint(aDiff.x * 0.5, aDiff.y * -0.5) fromViewPoint:aPoint];
}

- (void)mouseDraggedWithDiff:(NSPoint)aDiff
{
    [super mouseDraggedWithDiff:aDiff];
    _postMoveVelocity.x = -(float)_postMoveVelocity.x / _mapScaleValue;
    _postMoveVelocity.y = (float)_postMoveVelocity.y / _mapScaleValue;
    NSRect frame = [[_controller glView] frame];
    float height = (float)frame.size.height;
    [self setPosition:NSMakePoint((float)_positionOnDown.x - ((float)aDiff.x / (height + height)) / _mapScaleValue,
                                  ((float)aDiff.y / height) / _mapScaleValue + (float)_positionOnDown.y)];
}

// Animates scale and position to the new ones over 0.35 s, crossing the
// map's edge if that is shorter, then highlights the given regions.
- (void)_fluentlyDoNewScale:(CGFloat)aScale toMapPoint:(NSPoint)aPoint autoselectCountry:(id)aCountry autoselectState:(id)aState autoselectTimeZone:(id)aZone
{
    if (_scaleTimer != nil)
        return;
    [[self scene] setNeedLayoutCaptions:NO];
    [_autoselectedCountryUID release];
    [_autoselectedStateUID release];
    [_autoselectedTimeZoneUID release];
    _autoselectedCountryUID = [aCountry retain];
    _autoselectedStateUID = [aState retain];
    _autoselectedTimeZoneUID = [aZone retain];
    [[self scene] highlightCountry:nil state:nil timeZone:nil];
    float scale = (float)aScale < 1.0f ? 1.0f : (float)aScale;
    float x = (float)[self xPosition];
    float targetX = (float)aPoint.x;
    float distance = fabsf(x - targetX);
    if (fabsf(x - ((float)aPoint.x - 1.0f)) < distance) {
        distance = fabsf(x - ((float)aPoint.x - 1.0f));
        targetX = (float)aPoint.x - 1.0f;
    }
    if (distance > fabsf(x - ((float)aPoint.x + 1.0f)))
        targetX = (float)aPoint.x + 1.0f;
    _posXStart = (float)[self xPosition];
    _posXTarget = targetX;
    _posXDifference = targetX - _posXStart;
    _posYStart = _position.y;
    _posYTarget = 1.0f - (float)aPoint.y;
    _posYDifference = (1.0f - (float)aPoint.y) - _posYStart;
    float scaleValue = _mapScaleValue;
    _scaleStart = log2f(scaleValue);
    _scaleTarget = log2f(scale <= 32.0f ? scale : 32.0f);
    _scaleStartReal = scaleValue;
    _scaleDifference = _scaleTarget - _scaleStart;
    _startFluentlyScaleTime = [NSDate timeIntervalSinceReferenceDate];
    [self _timerOnFluentlyScale:nil];
    [self refreshView];
}

// zooms exponentially; the position moves so the target point stays put
- (void)_timerOnFluentlyScale:(id)aScale
{
    double progress = ([NSDate timeIntervalSinceReferenceDate] - _startFluentlyScaleTime) / 0.35;
    [_scaleTimer invalidate];
    if (progress < 1.0) {
        float scaleValue = (float)pow(2.0, (double)_scaleStart + (double)_scaleDifference * progress);
        float ratio = scaleValue / _scaleStartReal;
        float targetX = _posXTarget, differenceX = _posXDifference;
        float y = (float)((double)_posYTarget - (double)(_posYDifference / ratio) * (1.0 - progress));
        _scaleTimer = [NSTimer scheduledTimerWithTimeInterval:0.0001 target:self selector:@selector(_timerOnFluentlyScale:) userInfo:nil repeats:NO];
        [self adjustToScale:(float)(log2((double)scaleValue) / 5.0)];
        [self setPosition:NSMakePoint((float)((double)targetX - (double)(differenceX / ratio) * (1.0 - progress)), y)];
        [_controller setScaleValue:(float)(log2((double)scaleValue) / 5.0)];
    } else {
        _scaleTimer = nil;
        [self adjustToScale:_scaleTarget / 5.0f];
        [self setPosition:NSMakePoint(_posXTarget, _posYTarget)];
        [_controller setScaleValue:_scaleTarget / 5.0f];
        NSView *glView = [_controller glView];
        NSPoint mouse = [[[self windowController] mainWindow] convertRectFromScreen:NSMakeRect([NSEvent mouseLocation].x, [NSEvent mouseLocation].y, 0.0, 0.0)].origin;
        [self _mapPointFromViewPoint:[glView convertPoint:mouse fromView:nil] inView:glView];
        AtlasDatabase *database = [AtlasDatabase database];
        id country = [database infoWithShapeUID:_autoselectedCountryUID lod:[self countryBoundariesLOD]];
        id state = [database infoWithShapeUID:_autoselectedStateUID lod:[self countryBoundariesLOD]];
        id timeZone = [database infoWithShapeUID:_autoselectedTimeZoneUID lod:[self countryBoundariesLOD]];
        [[self scene] highlightCountry:country state:state timeZone:timeZone];
        [_autoselectedCountryUID release];
        [_autoselectedStateUID release];
        [_autoselectedTimeZoneUID release];
        _autoselectedCountryUID = nil;
        _autoselectedStateUID = nil;
        _autoselectedTimeZoneUID = nil;
        [[self scene] setNeedLayoutCaptions:YES];
    }
    [self _updateMinimapParams];
}

// the arrow keys scroll by 5% of the map at the current scale
- (void)keyDown:(id)aDown inView:(id)aView
{
    NSString *characters = [aDown charactersIgnoringModifiers];
    if ([characters length] == 1) {
        float x = _position.x, y = _position.y;
        BOOL handled = YES;
        switch ([characters characterAtIndex:0]) {
        case NSDownArrowFunctionKey: y = 0.05f / _mapScaleValue + (float)_position.y; break;
        case NSUpArrowFunctionKey: y = -0.05f / _mapScaleValue + (float)_position.y; break;
        case NSLeftArrowFunctionKey: x = -0.05f / _mapScaleValue + (float)_position.x; break;
        case NSRightArrowFunctionKey: x = 0.05f / _mapScaleValue + (float)_position.x; break;
        default: handled = NO; break;
        }
        if (handled) {
            [self setPosition:NSMakePoint(x, y)];
            [_controller stopAnyFlying];
            return;
        }
    }
    [super keyDown:aDown inView:aView];
}

- (void)calculateAutoMoveSpeedForFlyToPosition:(NSPoint)aPosition
{
    [super calculateAutoMoveSpeedForFlyToPosition:aPosition];
    [self _specifyAutomoveSpeedRelativeToScale];
}

- (void)compassValueChangedTo:(NSInteger)aTo
{
    [super compassValueChangedTo:aTo];
    [self _specifyAutomoveSpeedRelativeToScale];
}

- (void)_specifyAutomoveSpeedRelativeToScale
{
    _initialAutomoveSpeeds = _automoveSpeed;
    float scaleValue = _mapScaleValue;
    _automoveSpeed.x = (float)_automoveSpeed.x / (scaleValue * 0.5f);
    _automoveSpeed.y = (float)_automoveSpeed.y / (scaleValue * -0.5f);
}

- (CGFloat)scale
{
    return (float)(log2((double)_mapScaleValue) / 5.0);
}

- (void)adjustToScale:(CGFloat)aScale
{
    [super adjustToScale:aScale];
    [self setMapScaleValue:(float)pow(2.0, (double)((float)aScale * 5.0f))];
    [self _recacheImagesWithDelay];
    [self _updateMinimapParams];
    [self refreshView];
    float scaleValue = _mapScaleValue;
    _automoveSpeed.x = (float)_initialAutomoveSpeeds.x / (scaleValue * 0.5f);
    _automoveSpeed.y = (float)_initialAutomoveSpeeds.y / (scaleValue * -0.5f);
}

- (void)_delayedRecacheSelector:(id)aSelector
{
    [self recacheImagesWithZoomLevels:YES];
}

// map tiles of a finer level of detail as the magnified map gets larger
- (void)recacheImagesWithZoomLevels:(BOOL)aLevels
{
    [_delayRecacheTimer invalidate];
    _delayRecacheTimer = nil;
    float mapHeight = (float)[[_controller glView] frame].size.height * _mapScaleValue;
    NSInteger lod;
    if (mapHeight < 2048.0f)
        lod = 0;
    else if (mapHeight < 6144.0f)
        lod = 1;
    else
        lod = (mapHeight >= 12288.0f) + 2;
    [[_controller mapPartsLoader] startBackgroundRecacheForXPos:_position.x yPos:_position.y currentLOD:lod size:[[_controller glView] frame].size cacheZoomLevels:aLevels];
}

- (void)setMapScaleValue:(CGFloat)aValue
{
    float value = (float)aValue < 1.0f ? 1.0f : (float)aValue;
    if (value == _mapScaleValue)
        return;
    _mapScaleValue = value;
    [_flatMapScene invalidateDayNightSeparator];
    _position.y = _clampedY(_position.y, _mapScaleValue);
    // the scale slider zooms around the height where the drag started
    if (_isTrackingSlider && !_isFlying)
        [self setPosition:NSMakePoint(_position.x, _yPositionBeforeTrackingScaleSlider)];
    else
        [self refreshCameraSettings];
    [self refreshView];
}

- (void)setPosition:(NSPoint)aPosition
{
    _position.x = (float)aPosition.x - floorf((float)aPosition.x);
    _position.y = _clampedY((float)aPosition.y, _mapScaleValue);
    [self refreshCameraSettings];
    [super setPosition:_position];
}

- (NSInteger)degreesGridStep
{
    NSInteger detalization = [Preferences gridDetalization];
    float scaleValue = (float)[self mapScaleValue];
    if (detalization == 1)
        return 5;
    if (detalization == 0) {
        if (scaleValue > 7.0f)
            return 5;
        if (scaleValue > 3.0f)
            return 10;
    } else if (detalization == 2) {
        return 10;
    }
    return 20;
}

- (CGFloat)mapScaleValue
{
    return _mapScaleValue;
}

- (CGFloat)yPosition
{
    return _position.y;
}

- (CGFloat)xPosition
{
    float x = _position.x;
    return x - floorf(x);
}

- (void)recacheAll
{
    [self recacheImagesWithZoomLevels:YES];
}

- (void)recacheNeighborsOnly
{
    [self recacheImagesWithZoomLevels:NO];
}

- (void)refreshCameraSettings
{
    [_flatMapScene invalidateDayNightSeparator];
    [self _updateMinimapParams];
    [super refreshCameraSettings];
    [self refreshView];
}

// recaches 0.1 s after the last change, also while a control is tracked
- (void)_recacheImagesWithDelay
{
    [_delayRecacheTimer invalidate];
    _delayRecacheTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(_delayedRecacheSelector:) userInfo:nil repeats:NO];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:_delayRecacheTimer forMode:NSDefaultRunLoopMode];
    [runLoop addTimer:_delayRecacheTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)_updateMinimapParams
{
    float aspect = (float)[self viewAspect];
    float height = 1.0f / _mapScaleValue;
    float width = (aspect * 0.5f) / _mapScaleValue;
    float y = (float)[self yPosition];
    float x = (float)[self xPosition];
    [_controller setMinimapWorldRect:NSMakeRect(width * -0.5f + x, (1.0f - y) + height * -0.5f, width, height)];
}

- (NSInteger)countryBoundariesLOD
{
    float pixelsPerDegree = (_mapScaleValue * (float)[[[self windowController] glView] frame].size.height) / 180.0f;
    if (pixelsPerDegree < 4.0f)
        return 0;
    if (pixelsPerDegree < 16.0f)
        return 1;
    return (pixelsPerDegree >= 64.0f) + 2;
}

- (NSPoint)mapPointFromPositionPoint:(NSPoint)aPoint
{
    return NSMakePoint((float)aPoint.x - floorf((float)aPoint.x), 1.0f - (float)aPoint.y);
}

- (NSPoint)positionPointFromMapPoint:(NSPoint)aPoint
{
    return NSMakePoint((float)aPoint.x - floorf((float)aPoint.x), 1.0f - (float)aPoint.y);
}

// the point and its copies one map width left and right that are in view
- (id)normalizedViewPointsFromMapPoint:(NSPoint)aPoint
{
    float aspect = (float)[self viewAspect];
    NSMutableArray *points = [NSMutableArray array];
    float y = (((float)aPoint.y - 1.0f) + (float)[self yPosition]) * _mapScaleValue + 0.5f;
    if (y >= 0.0f && y <= 1.0f) {
        for (int i = -1; i < 2; i++) {
            float x = (((float)aPoint.x - (float)[self xPosition]) + (float)i) * _mapScaleValue;
            x = (x + x) / aspect + 0.5f;
            if (x >= 0.0f && x <= 1.0f)
                [points addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
        }
    }
    return points;
}

- (BOOL)canConvertNormalizedViewPoint:(NSPoint)aPoint toGeoPoint:(NSPoint *)aPoint2
{
    BOOL inView = _pointInRect(aPoint, NSMakeRect(0.0, 0.0, 1.0, 1.0));
    if (inView)
        *aPoint2 = _geoPointFromMapPoint([self _mapPointFromNormalizedViewPoint:aPoint]);
    return inView;
}

- (NSPoint)_mapPointFromNormalizedViewPoint:(NSPoint)aPoint
{
    float aspect = (float)[self viewAspect];
    float x = (float)[self xPosition];
    float y = (float)[self yPosition];
    return NSMakePoint((aspect * ((float)aPoint.x - 0.5f) * 0.5f) / _mapScaleValue + x,
                       (((float)aPoint.y - 0.5f) / _mapScaleValue + 1.0f) - y);
}

- (NSPoint)_mapPointFromViewPoint:(NSPoint)aPoint inView:(id)aView
{
    NSRect frame = [aView frame];
    float width = (float)frame.size.width, height = (float)frame.size.height;
    float y = (float)[self yPosition];
    float x = (float)[self xPosition];
    return NSMakePoint(((((float)aPoint.x + width * -0.5f) / _mapScaleValue) * 0.5f) / height + x,
                       (1.0f - y) + (((float)aPoint.y + height * -0.5f) / _mapScaleValue) / height);
}

- (void)sceneWillBeInstalled
{
    [super sceneWillBeInstalled];
    [self recacheImagesWithZoomLevels:YES];
    [self _updateMinimapParams];
}

- (void)glViewFrameDidChange:(id)aChange
{
    [super glViewFrameDidChange:aChange];
    [self _updateMinimapParams];
    [self refreshView];
}

- (id)scene
{
    return _flatMapScene;
}

- (void)dealloc
{
    [_delayRecacheTimer invalidate];
    [_flatMapScene release];
    [super dealloc];
}

- (id)initWithMainWindowController:(id)aController
{
    self = [super initWithMainWindowController:aController];
    if (self == nil)
        return nil;
    if (![self getDefaultCompassValue:&_compassValue])
        _compassValue = 0;
    _mapScaleValue = 1.0f;
    if (![self getDefaultPosition:&_position])
        _position = NSMakePoint(0.5, 0.5);
    _isTrackingSlider = NO;
    _flatMapScene = [[FlatMapScene alloc] initWithContainer:[[_controller glView] objectsContainer] controller:self];
    return self;
}

@end
