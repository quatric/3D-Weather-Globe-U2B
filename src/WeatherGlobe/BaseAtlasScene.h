#import "WeatherGlobePrefix.h"


@interface BaseAtlasScene : SMK_GL_Scene
{
    SMK_GL_ObjectsContainer *_container;
    BOOL _selectionRectIsVisible;
    NSRect _selectionRect;
    SMK_GL_Drawable *_planeMeshDrawable;
    SMK_GL_Drawable *_allCitiesPoints;
    SMK_GL_2DTexture *_flatCityMarkerTexture;
    YACityEntry *_highlightedCity;
    YACityEntry *_highlightedCity2;
    AppleStoreEntry *_highlightedAppleStore;
    CountryHiliter *_zoneHiliter;
    InfoDrawer *_infoDrawer;
    struct WeatherGlobe_anon6 _nearestCityCaptionBackColor;
    struct WeatherGlobe_anon6 _countryCaptionBackColor;
    struct WeatherGlobe_anon6 _colorHilitedCity2;
    struct WeatherGlobe_anon6 _colorHilitedAppleStore;
    NSColor *_highlightCountryFillColor;
    NSColor *_highlightStateFillColor;
    NSColor *_highlightTimeZoneFillColor;
    NSColor *_highlightCountryBorderColor;
    NSColor *_highlightStateBorderColor;
    NSColor *_highlightTimeZoneBorderColor;
    NSColor *_highlightCaptionColor;
    NSColor *_highlightCaptionTimeZoneColor;
    NSString *_statusLine;
    SMK_GL_StaticText *_routeMarkersCaptions;
    CaptionsLayouter *_routeMarkersCaptionsLayouter;
    NSMutableArray *_recordedCaptionIDs;
    SMK_GL_Font *_appleStoresGLFont;
    float _appleStoreMarkerSize;
    NSArray *_allBorders;
    NSMutableDictionary *_currentTextures;
}
+ (void)initialize;
- (id)textureForLod:(NSInteger)aLod xPos:(NSInteger)aPos yPos:(NSInteger)aPos2 translation:(struct WeatherGlobe_anon5 *)aTranslation scaling:(struct WeatherGlobe_anon5 *)aScaling;
- (struct WeatherGlobe_anon2)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint;
- (id)createGLMeshWidthBezierPaths:(id)aPaths;
- (void)setNeedLayoutCaptions:(BOOL)aCaptions;
- (id)allCitiesPoints;
- (id)routePathsMesh;
- (id)routeMarkersMesh;
- (id)allCitiesMesh;
- (void)drawInfoInContext:(id)aContext;
- (void)drawOverlaysInContext:(id)aContext;
- (void)drawStatusLineInContext:(id)aContext;
- (void)drawAppleStoresInContext:(id)aContext;
- (void)_drawAppleStoreEntry:(id)aEntry inContext:(id)aContext;
- (void)drawHighlightedCitiesInContext:(id)aContext;
- (void)_drawHighlightedCity:(id)aCity color:(struct WeatherGlobe_anon7)aColor InContext:(id)aContext;
- (void)drawSelectionRectInContext:(id)aContext;
- (void)fillVerticesWithAllCitiesInVB:(struct WeatherGlobe_anon4 *)aVB;
- (void)dragConcludedWithAllEntries;
- (void)dragExitedWithAllEntries;
- (void)dragBringsEntries:(id)aEntries;
- (void)distCalcSetChangedTo:(id)aTo;
- (void)recalculateCountryHilite;
- (void)highlightCountry:(id)aCountry state:(id)aState timeZone:(id)aZone;
- (CGFloat)appleStoreMarkerSize;
- (id)highlightedAppleStore;
- (void)highlightAppleStore:(id)aStore hiliteColor:(struct WeatherGlobe_anon7 *)aColor;
- (void)highlightCity2:(id)aCity2 hiliteColor:(struct WeatherGlobe_anon7 *)aColor;
- (void)highlightCity:(id)aCity;
- (void)setStatusLine:(id)aLine;
- (void)setSelectionRect:(NSRect)aRect;
- (BOOL)selectionVisible;
- (void)setSelectionVisible:(BOOL)aVisible;
- (void)_mainDatabaseWasChanged;
- (id)routePointsContainer;
- (id)sceneController;
- (BOOL)requiresAnimation;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
- (void)_createAllCitiesPoints;
- (void)_createPlaneMesh;
@end

@interface BaseAtlasScene (Protected)
- (id)_loader;
- (id)_allBordersForLOD:(NSInteger)aLOD;
- (id)_zoneInfoArrayWithCountry:(id)aCountry state:(id)aState timeZone:(id)aZone;
- (id)_zoneDictionaryWithBoundary:(id)aBoundary fillColor:(id)aColor borderColor:(id)aColor2 captionColor:(id)aColor3;
@end

