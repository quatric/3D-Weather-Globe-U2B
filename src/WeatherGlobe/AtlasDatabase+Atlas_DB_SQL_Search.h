#import "WeatherGlobePrefix.h"
#import "AtlasDatabase.h"


@interface AtlasDatabase (Atlas_DB_SQL_Search)
- (id)sampleRouteWithUID:(id)aUID;
- (id)allSampleRoutes;
- (id)allCityUIDsArray;
- (id)allCityPointsArray;
- (id)searchWithRequest:(id)aRequest sorting:(NSInteger)aSorting;
- (void)sortSearchResults:(id)aResults mode:(NSInteger)aMode;
- (id)searchWithRequest:(id)aRequest parameters:(id)aParameters;
- (id)searchWithRequest:(id)aRequest;
- (id)simpleSearchWithRequest:(id)aRequest;
@end

