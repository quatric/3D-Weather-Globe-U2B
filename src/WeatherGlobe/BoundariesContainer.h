#import "WeatherGlobePrefix.h"


@interface BoundariesContainer : NSObject
{
    LookupGridBLOB *_grid;
    NSString *_gridName;
    NSString *_geotype;
}
- (id)allObjectUIDs;
- (id)allPathsForLOD:(NSInteger)aLOD;
- (id)allPathsForObjectWithUID:(id)aUID LOD:(NSInteger)aLOD;
- (id)objectUIDBelowGeoPoint:(NSPoint)aPoint;
- (id)_objectUIDsBelowGeoPointByGrid:(NSPoint)aGrid;
- (id)_gridBlob;
- (void)dealloc;
- (id)initWithGridDBName:(id)aName geotype:(id)aGeotype;
@end

