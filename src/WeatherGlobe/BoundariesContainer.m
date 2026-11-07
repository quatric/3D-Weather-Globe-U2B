#import "BoundariesContainer.h"

@implementation BoundariesContainer

- (id)allObjectUIDs
{
    NSArray *rows = [[AtlasDatabase database] simpleSearchWithRequest:
        [NSString selectAllObjectUIDsWithGeotype:_geotype representationType:kRepTypeShapeIndices]];
    NSUInteger count = [rows count], i;
    NSMutableArray *uids = [NSMutableArray array];
    for (i = 0; i < count; i++)
        [uids addObject:[[rows objectAtIndex:i] objectForKey:kColumnNameObjectUid]];
    return uids;
}

- (id)allPathsForLOD:(NSInteger)aLOD
{
    NSArray *rows = [[AtlasDatabase database] simpleSearchWithRequest:
        [NSString selectAllObjectUIDsWithGeotype:_geotype representationType:kRepTypeShapeIndices]];
    NSUInteger count = [rows count], i;
    NSMutableArray *paths = [NSMutableArray array];
    for (i = 0; i < count; i++) {
        id objectPaths = [self allPathsForObjectWithUID:[[rows objectAtIndex:i] objectForKey:kColumnNameObjectUid] LOD:aLOD];
        if (objectPaths != nil)
            [paths addObject:objectPaths];
    }
    return paths;
}

- (id)allPathsForObjectWithUID:(id)aUID LOD:(NSInteger)aLOD
{
    return [[[[AtlasDatabase database] dbEntryWithUID:aUID]
             wrapperWithRepresentationOfType:kRepTypeShapeIndices createIfNeeded:YES] allPathsForLOD:aLOD];
}

// Of the shapes containing the point, returns the one with the smallest bounds.
- (id)objectUIDBelowGeoPoint:(NSPoint)aPoint
{
    NSArray *candidates = [self _objectUIDsBelowGeoPointByGrid:aPoint];
    NSUInteger count = [candidates count], i;
    NSMutableArray *hits = [NSMutableArray array];
    AtlasDatabase *database = [AtlasDatabase database];
    for (i = 0; i < count; i++) {
        id uid = [candidates objectAtIndex:i];
        IndexBuffersBLOB *shape = [[database dbEntryWithUID:uid] wrapperWithRepresentationOfType:kRepTypeShapeIndices
                                                                                  createIfNeeded:YES];
        if ([shape hitTestForGeoPoint:aPoint])
            [hits addObject:uid];
    }
    id best = nil;
    CGFloat bestSize = 0.0;
    count = [hits count];
    for (i = 0; i < count; i++) {
        id uid = [hits objectAtIndex:i];
        NSRect bounds = [[[database dbEntryWithUID:uid] wrapperWithRepresentationOfType:kRepTypeShapeIndices
                                                                         createIfNeeded:YES] allPathsBounds];
        if (i == 0 || NSWidth(bounds) + NSHeight(bounds) < bestSize) {
            bestSize = NSWidth(bounds) + NSHeight(bounds);
            best = uid;
        }
    }
    return best;
}

- (id)_objectUIDsBelowGeoPointByGrid:(NSPoint)aGrid
{
    return [[self _gridBlob] objectUIDsBelowGeoPoint:aGrid];
}

- (id)_gridBlob
{
    if (_grid == nil) {
        NSArray *rows = [[AtlasDatabase database] simpleSearchWithRequest:[NSString selectBLOBUIDForGrid:_gridName]];
        if ([rows count] != 1) {
            NSLog(@"Unable to find grid BLOB for the grid with name %@", _gridName);
            return nil;
        }
        _grid = [[BLOBWrapper wrapperWithBLOBUid:[[rows objectAtIndex:0] objectForKey:kColumnNameBLOBUid]] retain];
        if (![_grid isKindOfClass:[LookupGridBLOB class]]) {
            NSLog(@"Unable to create grid BLOB for the grid with name %@", _gridName);
            [_grid release];
            _grid = nil;
            return nil;
        }
    }
    return _grid;
}

- (void)dealloc
{
    [_grid release];
    [_gridName release];
    [_geotype release];
    [super dealloc];
}

- (id)initWithGridDBName:(id)aName geotype:(id)aGeotype
{
    self = [super init];
    if (self != nil) {
        _gridName = [aName retain];
        _geotype = [aGeotype retain];
    }
    return self;
}

@end
