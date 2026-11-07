#import "WeatherGlobePrefix.h"
#import "CountryHiliter.h"


@interface FlatMapCountryHiliter : CountryHiliter
{
}
- (void)rebuildForCountryDictionaries:(id)aDictionaries mapXPosition:(CGFloat)aPosition mapYPosition:(CGFloat)aPosition2 scaleValue:(CGFloat)aValue flags:(NSUInteger)aFlags;
- (void)_recalcVertexBuffers;
- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect;
@end

