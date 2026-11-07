#import "WeatherGlobePrefix.h"
#import "YACityEntry.h"


@interface GeoLocCityEntry : YACityEntry
{
    NSString *_name;
    NSString *_uid;
}
- (void)setGeoPoint:(NSPoint)aPoint;
- (void)setShortCaption:(id)aCaption;
- (id)uid;
- (id)shortCaption;
- (id)ownName;
- (id)entryDictionary;
- (void)dealloc;
- (id)initWithGeoPoint:(NSPoint)aPoint shortCaption:(id)aCaption uid:(id)aUid;
- (id)initWithGeoPoint:(NSPoint)aPoint;
@end

