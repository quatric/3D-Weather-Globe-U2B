#import "WeatherGlobePrefix.h"
#import "RoutePointsContainer.h"


@interface FlatRoutePointsContainer : RoutePointsContainer
{
}
- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition;
- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData;
- (id)estimateBreakes;
@end

