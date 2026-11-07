#import "WeatherGlobePrefix.h"
#import "AtlasPanelController.h"


@interface FlatMapController : AtlasPanelController
{
    FlatMapScene *_flatMapScene;
    float _mapScaleValue;
    float _yPositionBeforeTrackingScaleSlider;
    BOOL _isTrackingSlider;
    NSPoint _initialAutomoveSpeeds;
    NSTimer *_delayRecacheTimer;
    float _scaleTarget;
    float _posXTarget;
    float _posYTarget;
    float _scaleStart;
    float _posXStart;
    float _posYStart;
    float _posXDifference;
    float _posYDifference;
    float _scaleStartReal;
    float _scaleDifference;
}
- (CGFloat)precisionForEntryMarker;
- (void)sliderDidStopTracking:(id)aTracking;
- (void)sliderWillStartTracking:(id)aTracking;
- (NSRect)rect2DFromWorldRect:(NSRect)aRect;
- (void)zoomToSelectionRect:(NSRect)aRect;
- (void)zoomOutToGeoPoint:(NSPoint)aPoint;
- (void)zoomInToGeoPoint:(NSPoint)aPoint;
- (void)zoomToCurrentCountry;
- (void)endTrackingAtViewPoint:(NSPoint)aPoint;
- (void)scrollWithDiff:(NSPoint)aDiff fromViewPoint:(NSPoint)aPoint;
- (void)mouseDraggedWithDiff:(NSPoint)aDiff;
- (void)_fluentlyDoNewScale:(CGFloat)aScale toMapPoint:(NSPoint)aPoint autoselectCountry:(id)aCountry autoselectState:(id)aState autoselectTimeZone:(id)aZone;
- (void)_timerOnFluentlyScale:(id)aScale;
- (void)keyDown:(id)aDown inView:(id)aView;
- (void)calculateAutoMoveSpeedForFlyToPosition:(NSPoint)aPosition;
- (void)compassValueChangedTo:(NSInteger)aTo;
- (void)_specifyAutomoveSpeedRelativeToScale;
- (CGFloat)scale;
- (void)adjustToScale:(CGFloat)aScale;
- (void)_delayedRecacheSelector:(id)aSelector;
- (void)recacheImagesWithZoomLevels:(BOOL)aLevels;
- (void)setMapScaleValue:(CGFloat)aValue;
- (void)setPosition:(NSPoint)aPosition;
- (NSInteger)degreesGridStep;
- (CGFloat)mapScaleValue;
- (CGFloat)yPosition;
- (CGFloat)xPosition;
- (void)recacheAll;
- (void)recacheNeighborsOnly;
- (void)refreshCameraSettings;
- (void)_recacheImagesWithDelay;
- (void)_updateMinimapParams;
- (NSInteger)countryBoundariesLOD;
- (NSPoint)mapPointFromPositionPoint:(NSPoint)aPoint;
- (NSPoint)positionPointFromMapPoint:(NSPoint)aPoint;
- (id)normalizedViewPointsFromMapPoint:(NSPoint)aPoint;
- (BOOL)canConvertNormalizedViewPoint:(NSPoint)aPoint toGeoPoint:(NSPoint *)aPoint2;
- (NSPoint)_mapPointFromNormalizedViewPoint:(NSPoint)aPoint;
- (NSPoint)_mapPointFromViewPoint:(NSPoint)aPoint inView:(id)aView;
- (void)sceneWillBeInstalled;
- (void)glViewFrameDidChange:(id)aChange;
- (id)scene;
- (void)dealloc;
- (id)initWithMainWindowController:(id)aController;
@end

