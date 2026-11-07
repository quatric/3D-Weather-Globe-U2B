#import "WeatherGlobePrefix.h"
#import "CountryHiliter.h"


@interface SphereCountryHiliter : CountryHiliter
{
    float _radius;
}
- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect;
- (void)rebuildForCountryDictionaries:(id)aDictionaries scaleValue:(CGFloat)aValue flags:(NSUInteger)aFlags evaluateGlobeViewRect:(NSRect)aRect;
- (void)_recalcVertexBuffers;
- (void)_calculateVertexes:(id)aVertexes forGeoRectSphereSegment:(NSRect)aSegment xCells:(NSUInteger)aCells yCells:(NSUInteger)aCells2;
- (id)initWithContainer:(id)aContainer panelController:(id)aController captionFont:(id)aFont storagePart:(NSUInteger)aPart radius:(CGFloat)aRadius;
@end

