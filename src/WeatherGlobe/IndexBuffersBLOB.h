#import "WeatherGlobePrefix.h"


@interface BLOBWrapper : NSObject
{
    NSData *_data;
    NSString *_uid;
}
+ (id)wrapperWithKind:(id)aKind data:(id)aData uid:(id)aUid;
+ (id)wrapperWithBLOBUid:(id)aUid;
+ (id)wrapperForObjectWithUID:(id)aUID representationType:(id)aType;
+ (Class)_classWrapperForKind:(id)aKind;
- (id)blobData;
- (void)dealloc;
- (id)initWithData:(id)aData kind:(id)aKind uid:(id)aUid;
@end

@interface IndexBuffersBLOB : BLOBWrapper
{
    NSDictionary *_paths;
    NSRect _largestPathBounds;
    NSRect _allPathsBounds;
}
- (NSRect)allPathsBounds;
- (NSRect)largestPathBounds;
- (BOOL)hitTestForGeoPoint:(NSPoint)aPoint;
- (id)allPathsForLOD:(NSInteger)aLOD;
- (void)dealloc;
@end

@interface VertexBuffersBLOB : BLOBWrapper
{
    BOOL _isValid;
    void * _pointers[100][4];
}
+ (id)verticesWithUID:(id)aUID;
- (const float *)pointsForBufferAtIndex:(NSInteger)aIndex lod:(NSInteger)aLod;
@end

@interface LookupGridBLOB : BLOBWrapper
{
    NSDictionary *_fastLookup;
    float _cellWidth;
    float _cellHeight;
    int _num_cells_x;
    int _num_cells_y;
}
- (id)objectUIDsBelowGeoPoint:(NSPoint)aPoint;
- (id)_lookupDict;
- (void)dealloc;
@end

@interface PlistBLOB : BLOBWrapper
{
    NSDictionary *_dict;
}
- (id)object;
- (id)name;
- (id)_dictionary;
- (void)dealloc;
@end

@interface ImageBLOB : BLOBWrapper
{
}
@end

