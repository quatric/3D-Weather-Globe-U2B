#import "WeatherGlobePrefix.h"
#import "RoutePointsContainer.h"


@interface SphereRoutePointsContainer : RoutePointsContainer
{
    float _radius;
}
- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition;
- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData;
- (void)dealloc;
- (id)initWithGLContainer:(id)aContainer radius:(CGFloat)aRadius;
@end

