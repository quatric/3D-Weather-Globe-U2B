#import "WeatherGlobePrefix.h"


@interface RoutePointsContainer : NSObject
{
    SMK_GL_ObjectsContainer *_container;
    NSData *_routePoints;
    SMK_GL_Drawable *_routeDrawable;
    int _currPointIndex;
    float _currPointOffset;
    NSPoint _currMapPoint;
    BOOL _backwardFly;
}
- (NSPoint)currentFlyMapPoint;
- (BOOL)flyStepWithDeltaTime:(double)aTime;
- (void)stopFlying;
- (void)startFlying;
- (NSPoint)mapPointFromScenePosition:(struct WeatherGlobe_anon2)aPosition;
- (id)routeDrawable;
- (void)appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 segmentsCount:(NSInteger)aCount toData:(id)aData;
- (void)adjustToRoutePointsArray:(id)aArray;
- (void)_createRouteMesh;
- (id)estimateBreakes;
- (void)_appendRouteBetweenPoint:(struct WeatherGlobe_anon8 *)aPoint andPoint:(struct WeatherGlobe_anon8 *)aPoint2 toData:(id)aData;
- (void)dealloc;
- (id)initWithGLContainer:(id)aContainer;
@end

