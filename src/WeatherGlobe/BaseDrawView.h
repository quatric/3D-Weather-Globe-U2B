#import "WeatherGlobePrefix.h"


@interface BaseDrawView : NSView
{
    AtlasPanelController *_panelController;
    NSRect _transfRect;
    struct __dvFlags _dvFlags;
    CaptionsLayouter *_captionsLayouter;
    float _scale;
}
- (void)drawRect:(NSRect)aRect;
- (void)drawAppleStores;
- (void)drawRouteMarkersInRect:(NSRect)aRect;
- (void)drawRoutes;
- (void)drawAllCitiesInRect:(NSRect)aRect;
- (void)drawStateNames;
- (void)drawStateBordersInRect:(NSRect)aRect;
- (void)drawCountryNames;
- (void)drawCountryBordersInRect:(NSRect)aRect;
- (void)_drawShapeNamesWithType:(NSInteger)aType;
- (void)_drawShapeBordersWithType:(NSInteger)aType InRect:(NSRect)aRect;
- (void)drawGridInRect:(NSRect)aRect;
- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (void)invalidateCashes;
- (NSRect)captionRectForCountryInfo:(id)aInfo;
- (id)transformGeoPath:(id)aPath;
- (NSSize)convertSizeToGeoSize:(NSSize)aSize;
- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible;
- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible;
- (BOOL)isGeoPathVisible:(id)aVisible;
- (BOOL)isCountryVisible:(id)aVisible;
- (NSRect)destinationRect;
- (NSRect)geoRect;
- (id)appleStoresShadowAttributes;
- (id)appleStoresAttributes;
- (id)stateNameShadowAttributes;
- (id)stateNameAttributes;
- (id)countryNameShadowAttributes;
- (id)countryNameAttributes;
- (id)countryBorderColor;
- (id)gridMarkerAttributes;
- (id)gridColor;
- (id)lineColor;
- (id)routeCaptionShadowAttributes;
- (id)routeCaptionAttributes;
- (CGFloat)routeMarkerRadius;
- (id)cityColor;
- (CGFloat)cityRadius;
- (void)setDrawsAppleStores:(BOOL)aStores;
- (BOOL)drawsAppleStores;
- (void)setDrawsCityBorder:(BOOL)aBorder;
- (BOOL)drawsCityBorder;
- (void)setDrawsRouteNames:(BOOL)aNames;
- (BOOL)drawsRouteNames;
- (void)setDrawsRouteLines:(BOOL)aLines;
- (BOOL)drawsRouteLines;
- (void)setDrawsRouteMarkers:(BOOL)aMarkers;
- (BOOL)drawsRouteMarkers;
- (void)setDrawsAllCities:(BOOL)aCities;
- (BOOL)drawsAllCities;
- (void)setDrawsStateNames:(BOOL)aNames;
- (BOOL)drawsStateNames;
- (void)setDrawsStateBorders:(BOOL)aBorders;
- (BOOL)drawsStateBorders;
- (void)setDrawsCountryNames:(BOOL)aNames;
- (BOOL)drawsCountryNames;
- (void)setDrawsCountryBorders:(BOOL)aBorders;
- (BOOL)drawsCountryBorders;
- (void)setDrawsGrid:(BOOL)aGrid;
- (BOOL)drawsGrid;
- (void)setDrawsDayNight:(BOOL)aNight;
- (BOOL)drawsDayNight;
- (void)setDrawsClouds:(BOOL)aClouds;
- (BOOL)drawsClouds;
- (void)setDrawsMap:(BOOL)aMap;
- (BOOL)drawsMap;
- (void)setScale:(CGFloat)aScale;
- (void)setAtlasPanelController:(id)aController;
- (id)atlasPanelController;
- (BOOL)isOpaque;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame;
@end

