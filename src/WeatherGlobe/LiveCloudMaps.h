#import "WeatherGlobePrefix.h"


// Satellite clouds from Matt Eason's Live Cloud Maps (clouds.matteason.co.uk,
// CC0, "Contains modified EUMETSAT data"), which replace MacKiev's cloud feed.
// The service only has the latest global map, so only the current maps can be
// fetched; older frames build up as the app keeps running. Turned off with the
// LiveCloudMapsDisabled default.
@interface LiveCloudMaps : NSObject
+ (BOOL)isEnabled;
// JPEG data for one hemisphere, aSize pixels square, like the old feed's maps
+ (void)loadMapForEast:(BOOL)aEast size:(NSInteger)aSize completion:(void (^)(NSData *aJPEG))aCompletion;
@end
