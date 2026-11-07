#import "IndexBuffersBLOB.h"

// The BLOB formats are big-endian, built from 32-bit words, 16-bit indices
// and 10-character object UIDs.

static uint32_t _readWord(const unsigned char *aBytes)
{
    return CFSwapInt32BigToHost(*(const uint32_t *)aBytes);
}

static uint16_t _readShort(const unsigned char *aBytes)
{
    return CFSwapInt16BigToHost(*(const uint16_t *)aBytes);
}

static NSString *_uidString(const unsigned char *aBytes)
{
    return [[[NSString alloc] initWithBytes:aBytes length:strnlen((const char *)aBytes, 10) encoding:NSASCIIStringEncoding] autorelease];
}

// key of a lookup grid cell
static NSString *_cellKey(uint32_t aX, uint32_t aY)
{
    return [NSString stringWithFormat:@"%d", (int)(aX | (aY & 0xffff) << 16)];
}

@implementation BLOBWrapper

+ (id)wrapperWithKind:(id)aKind data:(id)aData uid:(id)aUid
{
    Class wrapperClass = [self _classWrapperForKind:[aKind lowercaseString]];
    if (wrapperClass == Nil) {
        NSLog(@"Unable to find wrapper class for kind %@", aKind);
        return nil;
    }
    return [[[wrapperClass alloc] initWithData:aData kind:[aKind lowercaseString] uid:aUid] autorelease];
}

+ (id)wrapperWithBLOBUid:(id)aUid
{
    NSArray *results = [[AtlasDatabase database] simpleSearchWithRequest:[NSString selectBLOBKindWithUID:aUid]];
    if ([results count] != 1)
        return nil;
    return [self wrapperWithKind:[[results objectAtIndex:0] objectForKey:kColumnNameKind] data:nil uid:aUid];
}

+ (id)wrapperForObjectWithUID:(id)aUID representationType:(id)aType
{
    NSArray *results = [[AtlasDatabase database] simpleSearchWithRequest:[NSString selectBLOBUIDWithRepresentationOfType:aType forObject:aUID]];
    if ([results count] != 1)
        return nil;
    return [self wrapperWithBLOBUid:[[results objectAtIndex:0] objectForKey:kColumnNameBLOBUid]];
}

+ (Class)_classWrapperForKind:(id)aKind
{
    static NSDictionary *remap = nil;
    if (remap == nil) {
        NSString *image = NSStringFromClass([ImageBLOB class]);
        remap = [[NSDictionary alloc] initWithObjectsAndKeys:
            image, @"gif",
            image, @"jpg",
            image, @"jpeg",
            image, @"png",
            image, @"tif",
            image, @"tiff",
            NSStringFromClass([PlistBLOB class]), @"plist",
            NSStringFromClass([LookupGridBLOB class]), @"lookupgrid",
            NSStringFromClass([VertexBuffersBLOB class]), @"shape_verts",
            NSStringFromClass([IndexBuffersBLOB class]), @"poly_inds",
            nil];
    }
    NSString *className = [remap objectForKey:aKind];
    return className != nil ? NSClassFromString(className) : Nil;
}

- (id)blobData
{
    if (_data == nil) {
        NSArray *results = [[AtlasDatabase database] searchWithRequest:[NSString selectBLOBDataWithUID:_uid]];
        if ([results count] != 1)
            NSLog(@"Unable to find BLOB data for uid %@", _uid);
        if ([results count] == 0)
            return nil;
        _data = [[[results objectAtIndex:0] objectForKey:kColumnNameBLOBData] retain];
    }
    return _data;
}

- (void)dealloc
{
    [_data release];
    [_uid release];
    [super dealloc];
}

- (id)initWithData:(id)aData kind:(id)aKind uid:(id)aUid
{
    self = [super init];
    if (self != nil) {
        _data = [aData retain];
        _uid = [aUid retain];
    }
    return self;
}

@end

@implementation IndexBuffersBLOB

- (NSRect)allPathsBounds
{
    [self allPathsForLOD:0];
    return _allPathsBounds;
}

- (NSRect)largestPathBounds
{
    [self allPathsForLOD:0];
    return _largestPathBounds;
}

- (BOOL)hitTestForGeoPoint:(NSPoint)aPoint
{
    NSArray *paths = [self allPathsForLOD:3];
    NSUInteger count = [paths count];
    for (NSUInteger i = 0; i < count; i++)
        if ([[paths objectAtIndex:i] containsPoint:aPoint])
            return YES;
    return NO;
}

// Builds the outline paths of every LOD: per LOD a list of polygons, each
// indexing into a vertex buffer BLOB. The overall bounds take the narrowest
// of the plain, -360 and +360 degree unions, as a shape may cross the
// date line.
- (id)allPathsForLOD:(NSInteger)aLOD
{
    if (_paths == nil) {
        NSMutableDictionary *paths = [NSMutableDictionary dictionary];
        NSData *data = [self blobData];
        if (data == nil)
            return nil;
        const unsigned char *bytes = [data bytes];
        uint32_t lodCount = _readWord(bytes);
        bytes += 4;
        _allPathsBounds = NSZeroRect;
        _largestPathBounds = NSZeroRect;
        for (uint32_t lodIndex = 0; lodIndex < lodCount; lodIndex++) {
            int lod = (int)_readWord(bytes);
            uint32_t polygonCount = _readWord(bytes + 4);
            bytes += 8;
            NSMutableArray *lodPaths = nil;
            for (uint32_t polygon = 0; polygon < polygonCount; polygon++) {
                if (_readWord(bytes) != polygon) {
                    NSLog(@"Corrupted indices blob data.");
                    return nil;
                }
                NSString *vertsUID = _uidString(bytes + 4);
                uint32_t buffer = _readWord(bytes + 14);
                uint32_t indexCount = _readWord(bytes + 18);
                const unsigned char *indices = bytes + 22;
                bytes = indices + indexCount * 2;
                VertexBuffersBLOB *verts = [VertexBuffersBLOB verticesWithUID:vertsUID];
                if (verts == nil) {
                    NSLog(@"Broken reference to the points BLOB.");
                    continue;
                }
                const float *points = [verts pointsForBufferAtIndex:buffer lod:lod];
                if (points == NULL)
                    continue;
                NSBezierPath *path = [[NSBezierPath new] autorelease];
                for (uint32_t i = 0; i < indexCount; i++) {
                    uint16_t index = _readShort(indices + i * 2);
                    NSPoint point = NSMakePoint(points[index * 2], points[index * 2 + 1]);
                    if (i == 0)
                        [path moveToPoint:point];
                    else
                        [path lineToPoint:point];
                }
                [path closePath];
                NSRect bounds = [path bounds];
                if (_largestPathBounds.size.width + _largestPathBounds.size.height < bounds.size.width + bounds.size.height)
                    _largestPathBounds = bounds;
                if (polygon == 0) {
                    _allPathsBounds = bounds;
                } else {
                    NSRect plain = NSUnionRect(_allPathsBounds, bounds);
                    NSRect west = NSUnionRect(_allPathsBounds, NSOffsetRect(bounds, -360.0, 0.0));
                    NSRect east = NSUnionRect(_allPathsBounds, NSOffsetRect(bounds, 360.0, 0.0));
                    _allPathsBounds = west.size.width <= plain.size.width ? west : plain;
                    if (east.size.width < _allPathsBounds.size.width)
                        _allPathsBounds = east;
                }
                if (lodPaths == nil) {
                    lodPaths = [NSMutableArray array];
                    [paths setObject:lodPaths forKey:[NSString stringWithFormat:@"%d", lod]];
                }
                [lodPaths addObject:path];
            }
        }
        _paths = [paths retain];
    }
    return [_paths objectForKey:[NSString stringWithFormat:@"%d", (int)aLOD]];
}

- (void)dealloc
{
    [_paths release];
    [super dealloc];
}

@end

@implementation VertexBuffersBLOB

+ (id)verticesWithUID:(id)aUID
{
    static NSMutableDictionary *createdVerts = nil;
    if (createdVerts == nil)
        createdVerts = [NSMutableDictionary new];
    id verts = [createdVerts objectForKey:aUID];
    if (verts == nil) {
        verts = [BLOBWrapper wrapperWithBLOBUid:aUID];
        if (![verts isKindOfClass:[VertexBuffersBLOB class]]) {
            NSLog(@"Unable to create VB BLOB with blob_uid %@", aUID);
            return nil;
        }
        [createdVerts setObject:verts forKey:aUID];
    }
    return verts;
}

// Returns the x, y float pairs of a buffer. The BLOB is swapped to host
// order in a private copy the first time: per LOD a list of buffers, each a
// point count followed by the points.
- (const float *)pointsForBufferAtIndex:(NSInteger)aIndex lod:(NSInteger)aLod
{
    if (!_isValid) {
        if ([self blobData] == nil)
            return NULL;
        NSMutableData *data = [_data mutableCopy];
        [_data release];
        _data = data;
        uint32_t *words = [data mutableBytes];
        uint32_t lodCount = CFSwapInt32BigToHost(*words++);
        for (uint32_t lodIndex = 0; lodIndex < lodCount; lodIndex++) {
            uint32_t lod = CFSwapInt32BigToHost(words[0]);
            uint32_t bufferCount = CFSwapInt32BigToHost(words[1]);
            words += 2;
            for (uint32_t buffer = 0; buffer < bufferCount; buffer++) {
                if (CFSwapInt32BigToHost(words[0]) != buffer || buffer >= 100 || lod >= 4) {
                    NSLog(@"Corrupted blob data.");
                    return NULL;
                }
                _pointers[buffer][lod] = words + 1;
                uint32_t pointCount = CFSwapInt32BigToHost(words[1]);
                words[1] = pointCount;
                words += 2;
                for (uint32_t i = 0; i < pointCount * 2; i++, words++)
                    *words = CFSwapInt32BigToHost(*words);
            }
        }
        _isValid = YES;
    }
    if (_pointers[aIndex][aLod] == NULL)
        return NULL;
    return (const float *)((const uint32_t *)_pointers[aIndex][aLod] + 1);
}

@end

static float _readFloat(const unsigned char *aBytes)
{
    union { uint32_t word; float value; } bits;
    bits.word = _readWord(aBytes);
    return bits.value;
}

@implementation LookupGridBLOB

- (id)objectUIDsBelowGeoPoint:(NSPoint)aPoint
{
    NSDictionary *lookup = [self _lookupDict];
    if (lookup == nil)
        return nil;
    NSData *cell = [lookup objectForKey:_cellKey((uint32_t)(int)((aPoint.x + 180.0) / _cellWidth), (uint32_t)(int)((aPoint.y + 90.0) / _cellHeight))];
    if (cell == nil)
        return nil;
    const unsigned char *bytes = [cell bytes];
    uint32_t count = _readWord(bytes);
    bytes += 4;
    NSMutableSet *uids = [NSMutableSet set];
    for (uint32_t i = 0; i < count; i++, bytes += 12)
        [uids addObject:_uidString(bytes)];
    return [uids allObjects];
}

// the grid: cell size, cell counts, then per cell its coordinates and the
// UIDs of the objects in it
- (id)_lookupDict
{
    if (_fastLookup == nil) {
        NSData *data = [self blobData];
        if (data == nil)
            return nil;
        const unsigned char *bytes = [data bytes];
        // the cell size is a big-endian float (1.0 degree in the shipped grids)
        _cellWidth = _readFloat(bytes);
        _cellHeight = _readFloat(bytes + 4);
        _num_cells_x = _readShort(bytes + 8);
        _num_cells_y = _readShort(bytes + 10);
        uint32_t count = _readWord(bytes + 12);
        bytes += 16;
        NSMutableDictionary *lookup = [[NSMutableDictionary alloc] initWithCapacity:count];
        _fastLookup = lookup;
        for (uint32_t i = 0; i < count; i++) {
            NSString *key = _cellKey(_readWord(bytes), _readWord(bytes + 4));
            uint32_t uidCount = _readWord(bytes + 8);
            [lookup setObject:[NSData dataWithBytesNoCopy:(void *)(bytes + 8) length:uidCount * 12 + 4 freeWhenDone:NO] forKey:key];
            bytes += 12 + uidCount * 12;
        }
    }
    return _fastLookup;
}

- (void)dealloc
{
    [_fastLookup release];
    [super dealloc];
}

@end

@implementation PlistBLOB

- (id)object
{
    return [[self _dictionary] objectForKey:@"plist"];
}

- (id)name
{
    return [[self _dictionary] objectForKey:@"name"];
}

// the BLOB is a zipped typedstream archive, which only NSUnarchiver reads
- (id)_dictionary
{
    if (_dict == nil) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _dict = [[NSUnarchiver unarchiveObjectWithData:[[self blobData] originalRepresentation]] retain];
#pragma clang diagnostic pop
    }
    return _dict;
}

- (void)dealloc
{
    [_dict release];
    [super dealloc];
}

@end

@implementation ImageBLOB
@end
