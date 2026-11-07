#import "WeatherGlobePrefix.h"
#import "BaseDrawView.h"


@interface SphereDrawView : BaseDrawView
{
    struct WeatherGlobe_anon9 _transfMatrix;
    NSImage *_cashedMapImage;
}
- (void)drawRect:(NSRect)aRect;
- (void)drawGridInRect:(NSRect)aRect;
- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (id)_projectedSphereImageForPosition:(NSPoint)aPosition enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (void)_addCloudsAndDayNightToWestImageRep:(id)aRep eastImageRep:(id)aRep2 enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight;
- (void)invalidateCashes;
- (NSRect)destinationRect;
- (NSRect)geoRect;
- (CGFloat)cityRadius;
- (NSSize)convertSizeToGeoSize:(NSSize)aSize;
- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible;
- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible;
- (NSPoint)_convertEarthVec:(struct WeatherGlobe_anon2 *)aVec isVisible:(BOOL *)aVisible;
- (void)_getTransformMatrix:(struct WeatherGlobe_anon3 *)aMatrix;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame;
@end

