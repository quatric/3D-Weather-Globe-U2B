#import "WeatherGlobePrefix.h"
#import "BaseDrawView.h"


@interface FlatDrawView : BaseDrawView
{
    NSRect _geoRect;
    BOOL _isImageRepsCashed;
    NSMutableArray *_cashedImageReps;
}
- (void)drawRect:(NSRect)aRect;
- (void)drawRoutes;
- (void)drawGridInRect:(NSRect)aRect;
- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (void)invalidateCashes;
- (void)_convertImageRep:(id)aRep withXIndex:(NSInteger)aIndex YIndex:(NSInteger)aIndex2 forLOD:(NSInteger)aLOD cloudsImageRep:(id)aRep2 inRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (NSRect)captionRectForCountryInfo:(id)aInfo;
- (NSRect)_initialRectForPoint:(NSPoint)aPoint Path:(id)aPath;
- (BOOL)isGeoPathVisible:(id)aVisible;
- (BOOL)isCountryVisible:(id)aVisible;
- (NSRect)destinationRect;
- (CGFloat)cityRadius;
- (id)transformGeoPath:(id)aPath;
- (NSSize)convertSizeToGeoSize:(NSSize)aSize;
- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible;
- (NSPoint)_convertVertexPoint:(struct WeatherGlobe_anon2)aPoint;
- (id)_rectsToDrawImageFromGeoRect:(NSRect)aRect;
- (NSRect)_convertGeoRect:(NSRect)aRect;
- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible;
- (NSPoint)_convertGeoPoint:(NSPoint)aPoint;
- (void)_calcTransform;
- (void)_calcGeoRect;
- (NSRect)geoRect;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame;
@end

