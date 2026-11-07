#import "WeatherGlobePrefix.h"
#import "AtlasPanelController.h"


@interface SphereMapController : AtlasPanelController
{
    SphereMapScene *_sphereMapScene;
    float _zoomFactor;
    float _zoomMultiplier;
    float _startScale;
    float _targetScale;
    float _startXAngle;
    float _targetXAngle;
    float _startYAngle;
    float _targetYAngle;
}
- (CGFloat)precisionForEntryMarker;
- (void)zoomOutToGeoPoint:(NSPoint)aPoint;
- (void)zoomInToGeoPoint:(NSPoint)aPoint;
- (void)scrollWithDiff:(NSPoint)aDiff fromViewPoint:(NSPoint)aPoint;
- (void)mouseDraggedWithDiff:(NSPoint)aDiff;
- (void)zoomToSelectionRect:(NSRect)aRect;
- (CGFloat)_calculateZoomFactorForSelectionRect:(NSRect)aRect;
- (NSPoint)_findPointOnGlobeInPartialSelectionWithPoint1:(NSPoint)aPoint1 point2:(NSPoint *)aPoint2;
- (void)zoomToCurrentCountry;
- (void)_fluentlyDoNewScale:(CGFloat)aScale newXAngle:(CGFloat)aAngle newYAngle:(CGFloat)aAngle2 autoselectCountry:(id)aCountry autoselectState:(id)aState autoselectTimeZone:(id)aZone;
- (void)_timerOnFluentlyScale:(id)aScale;
- (NSInteger)countryBoundariesLOD;
- (NSPoint)mapPointFromPositionPoint:(NSPoint)aPoint;
- (NSPoint)positionPointFromMapPoint:(NSPoint)aPoint;
- (id)normalizedViewPointsFromMapPoint:(NSPoint)aPoint;
- (BOOL)canConvertNormalizedViewPoint:(NSPoint)aPoint toGeoPoint:(NSPoint *)aPoint2;
- (struct WeatherGlobe_anon3)getMatrix_XAxisToNormalForGeoPoint:(NSPoint)aPoint;
- (NSPoint)get2DCoordinatesFromGeoPoint:(NSPoint)aPoint;
- (CGFloat)defaultScale;
- (CGFloat)scale;
- (void)adjustToScale:(CGFloat)aScale;
- (CGFloat)_scaleFromZoomFactor:(CGFloat)aFactor;
- (CGFloat)_zoomFactorFromScale:(CGFloat)aScale;
- (id)scene;
- (void)refreshCameraSettings;
- (NSInteger)degreesGridStep;
- (NSPoint)rotationAngles;
- (CGFloat)zoomFactor;
- (void)sceneWillBeInstalled;
- (void)dealloc;
- (id)initWithMainWindowController:(id)aController;
@end

