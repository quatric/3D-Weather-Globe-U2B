#import "WeatherGlobePrefix.h"
#import "BaseAtlasScene.h"


@interface FlatMapScene : BaseAtlasScene
{
    SMK_GL_Drawable *_dayNightSeparator;
    BOOL _separatorNormalsAreOK;
    struct WeatherGlobe_anon1 _lightDirection;
    SMK_GL_Drawable *_gridMeshLow;
    SMK_GL_Drawable *_gridMeshNorm;
    SMK_GL_Drawable *_gridMeshHigh;
    SMK_GL_Drawable *_rivers;
    FlatMapController *_controller;
    FlatRoutePointsContainer *_routePointsContainer;
    SMK_GL_Drawable *_routeMarkers;
    float _prevMapScaleVal;
    NSSize _prevContextSize;
}
- (struct WeatherGlobe_anon2)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint;
- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize;
- (void)drawObjectsInContext:(id)aContext;
- (void)_drawAllBordersInContext:(id)aContext;
- (void)_drawFlatOverlaysInContext:(id)aContext;
- (void)_drawAllCitiesInContext:(id)aContext;
- (void)_drawZoneHighliteCaptionsInContext:(id)aContext;
- (void)_drawZoneHiliteInContext:(id)aContext;
- (BOOL)_drawInContext:(id)aContext countryCaption:(id)aCaption in2DRect:(NSRect)aRect;
- (void)_drawGridInContext:(id)aContext;
- (void)_drawCloudsInContext:(id)aContext;
- (void)_drawFlatMapInContext:(id)aContext;
- (void)_setupMatrix:(struct WeatherGlobe_anon3 *)aMatrix toDisplayFlatMeshInRect:(NSRect)aRect;
- (void)_predrawDayNightSeparatorInContext:(id)aContext;
- (void)_startFrameDrawingWithLOD:(NSInteger)aLOD xStart:(NSInteger)aStart xEnd:(NSInteger)aEnd yStart:(NSInteger)aStart2 yEnd:(NSInteger)aEnd2;
- (id)routePathsMesh;
- (id)routeMarkersMesh;
- (void)recalculateCountryHilite;
- (void)highlightCountry:(id)aCountry state:(id)aState timeZone:(id)aZone;
- (void)_recalcSeparatorNormalsIfNeeded;
- (void)setLightDirection:(struct WeatherGlobe_anon2)aDirection;
- (void)invalidateDayNightSeparator;
- (void)distCalcSetChangedTo:(id)aTo;
- (void)_invalStaticTextsScaling;
- (id)routePointsContainer;
- (id)sceneController;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer controller:(id)aController;
- (void)fillVerticesWithAllCitiesInVB:(struct WeatherGlobe_anon4 *)aVB;
- (void)_createRivers;
- (void)_createCountryHiliter;
- (void)_createGridObjects;
- (id)_createFlatGridWithXSegs:(NSInteger)aSegs ySegs:(NSInteger)aSegs2;
- (void)_createDayNightSeparator;
@end

