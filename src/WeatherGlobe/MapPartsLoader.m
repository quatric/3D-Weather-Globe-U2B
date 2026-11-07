#import "MapPartsLoader.h"

// Tiles per hemisphere side at each LOD: the map is 2n tiles wide and n high.
static int _tilesForLOD(NSInteger aLOD)
{
    if (aLOD < 1)
        return 1;
    if (aLOD == 1)
        return 3;
    return aLOD == 2 ? 9 : 18;
}

// map height in pixels one LOD below aLOD
static float _mapHeightBelowLOD(NSInteger aLOD)
{
    if (aLOD - 1 < 1)
        return 2049.0f;
    return aLOD - 1 == 1 ? 6145.0f : 12289.0f;
}

// width and height of a tile at aLOD, in map units of one hemisphere
static void _tileSizeForLOD(NSInteger aLOD, float *aWidth, float *aHeight)
{
    switch (aLOD < 1 ? 0 : aLOD) {
    case 0:
        *aWidth = 0.5f;
        *aHeight = 1.0f;
        break;
    case 1:
        *aWidth = 0.16666667f;
        *aHeight = 0.33333334f;
        break;
    case 2:
        *aWidth = 0.055555556f;
        *aHeight = 0.11111111f;
        break;
    default:
        *aWidth = 0.027777778f;
        *aHeight = 0.055555556f;
        break;
    }
}

@implementation MapPartsLoader

+ (id)pathForMapTextureForLOD:(NSInteger)aLOD xPos:(NSInteger)aPos yPos:(NSInteger)aPos2
{
    static NSMutableDictionary *mapPartPaths = nil;
    NSString *key = [NSString stringWithFormat:@"%d_%d_%d", (int)aLOD, (int)aPos, (int)aPos2];
    NSString *path = [mapPartPaths objectForKey:key];
    if (path != nil)
        return path;
    if (mapPartPaths == nil)
        mapPartPaths = [NSMutableDictionary new];
    int tiles = _tilesForLOD(aLOD);
    int x = (int)aPos, y = (int)aPos2;
    if (x < 0)
        x += tiles * 32;
    if (y < 0)
        y += tiles * 16;
    int column = x % (tiles * 2);
    int row = y % tiles;
    BOOL isEast = column >= tiles;
    if (isEast)
        column -= tiles;
    NSString *folder = [[[NSBundle mainBundle] pathForResource:@"Maps" ofType:@""] stringByAppendingPathComponent:isEast ? @"East" : @"West"];
    NSString *file = nil;
    switch (aLOD) {
    case 0:
        file = @"1/earth_1024.jpo";
        break;
    case 1:
        file = [NSString stringWithFormat:@"3/earth_3072_%02d.jpo", column + 1 + row * 3];
        break;
    case 2:
        file = [NSString stringWithFormat:@"9/earth_9216_%d%d_%02d.jpo", row / 3 + 1, column / 3 + 1, column % 3 + 1 + (row % 3) * 3];
        break;
    case 3:
        folder = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"18/%d%d", row / 9 + 1, column / 9 + 1]];
        column %= 9;
        row %= 9;
        file = [NSString stringWithFormat:@"earth_9216_%d%d_%02d.jpo", row / 3 + 1, column / 3 + 1, column % 3 + 1 + (row % 3) * 3];
        break;
    }
    if (file == nil)
        return nil;
    path = [folder stringByAppendingPathComponent:file];
    [mapPartPaths setObject:path forKey:key];
    return path;
}

// The cache thread waits for condition 1, recaches, and goes back to 0
// unless new parameters came in meanwhile.
- (NSInteger)_newThreadEnterFunc:(id)aFunc
{
    NSAutoreleasePool *threadPool = [NSAutoreleasePool new];
    [NSThread setThreadPriority:0.01];
    while (YES) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        [_recacheLocker lockWhenCondition:1];
        if (_threadTerminationRequested) {
            [_recacheLocker unlock];
            [pool release];
            break;
        }
        [self _recacheZoomImagesForXPos:_currXPos yPos:_currYPos currentLOD:_currLOD size:_currSize cacheZoom:_cacheZoom];
        BOOL again = _newRecacheParamsWereSpecified;
        _newRecacheParamsWereSpecified = NO;
        [_recacheLocker unlockWithCondition:again ? 1 : 0];
        [pool release];
    }
    [threadPool release];
    return 0;
}

- (void)_textureWasCreated:(id)aCreated
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMapPartWasLoadedNotification object:self];
}

- (void)enable_cache_updates
{
    [_locker unlock];
}

- (void)disable_cache_updates
{
    [_locker lock];
}

// The main thread holds the recache lock at condition 0 until the first
// recache; while the thread is busy the new parameters are only recorded.
- (void)startBackgroundRecacheForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoomLevels:(BOOL)aLevels
{
    [self _stopCurrentRecache];
    _currXPos = aPos;
    _currYPos = aPos2;
    _currSize = aSize;
    _currLOD = (int)aLOD;
    _cacheZoom = aLevels;
    if (![_recacheLocker tryLockWhenCondition:0] && [_recacheLocker condition] != 0) {
        _newRecacheParamsWereSpecified = YES;
        return;
    }
    [_recacheLocker unlockWithCondition:1];
}

- (void)recacheMoveImagesForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD height:(CGFloat)aHeight
{
}

// Loads the tiles not cached yet, reusing the buffers of cached tiles no
// longer needed, then drops the rest of those.
- (void)_recacheZoomImagesForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoom:(BOOL)aZoom
{
    NSArray *paths = [self _imagesPathsForXPos:aPos yPos:aPos2 currentLOD:aLOD size:aSize cacheZoom:aZoom];
    NSUInteger length = _use32BitsTextures ? 1024 * 1024 * 4 : 1024 * 1024 * 2;
    NSMutableData *buffer = [NSMutableData dataWithLength:length];
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSUInteger count = [paths count];
    for (NSUInteger i = 0; i < count; i++) {
        NSString *path = [paths objectAtIndex:i];
        if ([_cachedDatas objectForKey:path] != nil)
            continue;
        [self _loadDataBySMKJPGFromFile:path width:1024 height:1024 bitDepth:_use32BitsTextures ? 32 : 16 bitmap:[buffer mutableBytes]];
        if (_recacheTerminationRequested) {
            _recacheTerminationRequested = NO;
            break;
        }
        [_locker lock];
        NSMutableData *nextBuffer = nil;
        for (NSString *key in [_cachedDatas allKeys]) {
            if (![paths containsObject:key] && ![_pathsForbiddenToRemove containsObject:key]) {
                nextBuffer = [[[_cachedDatas objectForKey:key] retain] autorelease];
                [_cachedDatas removeObjectForKey:key];
                break;
            }
        }
        if (nextBuffer == nil && i < count - 1)
            nextBuffer = [NSMutableData dataWithLength:length];
        [_cachedDatas setObject:buffer forKey:path];
        [_locker unlock];
        [self performSelectorOnMainThread:@selector(_textureWasCreated:) withObject:nil waitUntilDone:NO];
        buffer = nextBuffer;
    }
    [pool release];
    BOOL removed;
    do {
        removed = NO;
        [_locker lock];
        for (NSString *key in [_cachedDatas allKeys]) {
            if (![paths containsObject:key] && ![_pathsForbiddenToRemove containsObject:key]) {
                [_cachedDatas removeObjectForKey:key];
                removed = YES;
                break;
            }
        }
        [_locker unlock];
    } while (removed);
}

// The tiles to cache: the visible ones of the current LOD from the center
// out, then, when zooming is cached too, the tiles of the other LODs
// covering the view, alternating lower and higher ones from the farthest,
// and the always kept low resolution tiles.
- (id)_imagesPathsForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoom:(BOOL)aZoom
{
    NSMutableArray *lower = [NSMutableArray array];
    NSMutableArray *higher = [NSMutableArray array];
    NSMutableArray *current = [NSMutableArray array];
    NSMutableArray *result = [NSMutableArray array];
    Class loaderClass = [self class];
    float x = aPos, y = aPos2;
    float aspectHalf = (aSize.width / aSize.height) * 0.5f;

    float scale = _mapHeightBelowLOD(aLOD) * 0.5f / aSize.height;
    float ySpan = 1.0f;
    if (scale >= 1.0f)
        ySpan = 1.0f / scale;
    else
        scale = 1.0f;
    float xSpan = aspectHalf / scale;
    float tileWidth, tileHeight;
    _tileSizeForLOD(aLOD, &tileWidth, &tileHeight);
    int left = (int)((xSpan * -0.5f + x + 1e-05f) / tileWidth);
    int right = (int)((xSpan * 0.5f + x - 1e-05f) / tileWidth);
    int bottom = (int)((ySpan * -0.5f + y + 1e-05f) / tileHeight);
    int top = (int)((ySpan * 0.5f + y - 1e-05f) / tileHeight);
    int centerX = (left + right) >> 1;
    int up = (bottom + top) >> 1, down = up;
    for (int j = 0; j < ((top - bottom) >> 1) + 1; j++, up++, down--) {
        int east = centerX, west = centerX;
        for (int i = 0; i < ((right - left) >> 1) + 1; i++, east++, west--) {
            id path;
            if (east <= right) {
                if (up <= top && (path = [loaderClass pathForMapTextureForLOD:aLOD xPos:east yPos:up]) != nil)
                    [current addObject:path];
                if (j != 0 && down <= top && (path = [loaderClass pathForMapTextureForLOD:aLOD xPos:east yPos:down]) != nil)
                    [current addObject:path];
            }
            if (i != 0 && left <= west) {
                if (up <= top && (path = [loaderClass pathForMapTextureForLOD:aLOD xPos:west yPos:up]) != nil)
                    [current addObject:path];
                if (j != 0 && down <= top && (path = [loaderClass pathForMapTextureForLOD:aLOD xPos:west yPos:down]) != nil)
                    [current addObject:path];
            }
        }
    }

    float fractionX = x - floorf(x), fractionY = y - floorf(y);
    for (int lod = 0; lod < 4; lod++) {
        scale = _mapHeightBelowLOD(lod) / aSize.height;
        ySpan = 1.0f;
        if (scale >= 1.0f)
            ySpan = 1.0f / scale;
        else
            scale = 1.0f;
        xSpan = aspectHalf / scale;
        _tileSizeForLOD(lod, &tileWidth, &tileHeight);
        int lastRow = (int)((ySpan * 0.5f + fractionY - 1e-05f) / tileHeight);
        int lastColumn = (int)((xSpan * 0.5f + fractionX - 1e-05f) / tileWidth);
        for (int row = (int)((ySpan * -0.5f + fractionY + 1e-05f) / tileHeight); row <= lastRow; row++) {
            for (int column = (int)((xSpan * -0.5f + fractionX + 1e-05f) / tileWidth); column <= lastColumn; column++) {
                id path = [loaderClass pathForMapTextureForLOD:lod xPos:column yPos:row];
                if (path == nil || [current containsObject:path])
                    continue;
                if (lod == aLOD)
                    [current addObject:path];
                else if (aLOD <= lod)
                    [higher addObject:path];
                else
                    [lower addObject:path];
            }
        }
    }

    NSUInteger lowerCount = [lower count], higherCount = [higher count];
    [result addObjectsFromArray:current];
    if (aZoom) {
        while (lowerCount > 0 || higherCount > 0) {
            if (lowerCount > 0)
                [result addObject:[lower objectAtIndex:--lowerCount]];
            if (higherCount > 0)
                [result addObject:[higher objectAtIndex:--higherCount]];
        }
    }
    for (id path in _pathsForbiddenToRemove)
        if (![result containsObject:path])
            [result addObject:path];
    return result;
}

- (id)nightTextureForContainer:(id)aContainer isEast:(BOOL)aEast
{
    SMK_GL_2DTexture **texture = aEast ? &_nightEastTexture : &_nightWestTexture;
    if (*texture == nil) {
        NSString *path = [[[NSBundle mainBundle] pathForResource:@"Maps" ofType:@""] stringByAppendingPathComponent:aEast ? @"Night/earth_1024_east.jpo" : @"Night/earth_1024_west.jpo"];
        *texture = [[self createTextureWithContentsOfFile:path container:aContainer flags:0 usage:0 withMaxBitDepth:NO] retain];
        SMK_GL_Matrix matrix;
        matrix_make_identity(&matrix);
        matrix._22 = -1.0f;
        matrix._24 = 1.0f;
        [*texture setTransformMatrix:&matrix];
    }
    return *texture;
}

- (void)fillBitmapRep:(id)aRep withContentsOfFile:(id)aFile
{
    CGImageRef image = _CreateCGImageFromFile(aFile);
    if (image == NULL)
        return;
    NSBitmapImageRep *rep = aRep;
    _DrawCGImageIntoBitmap(image, [rep bitmapData], [rep pixelsWide], [rep pixelsHigh], (int)[rep bitsPerPixel]);
    CFRelease(image);
}

- (void)fillTexture:(id)aTexture withContentsOfFile:(id)aFile
{
    SMK_GL_2DTexture *texture = aTexture;
    void *bitmap = [texture lock];
    [self _loadDataBySMKJPGFromFile:aFile width:[texture width] height:[texture height] bitDepth:[texture bitsPerPixel] bitmap:bitmap];
    [texture unlock];
}

- (id)createTextureWithContentsOfFile:(id)aFile container:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage withMaxBitDepth:(BOOL)aDepth
{
    BOOL is32Bits = aDepth || _use32BitsTextures;
    [aContainer beginAccumulationBlock];
    CGImageRef image = _CreateCGImageFromFile(aFile);
    if (image == NULL) {
        [aContainer endAccumulationBlock];
        return nil;
    }
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    SMK_GL_2DTexture *texture = [[[SMK_GL_2DTexture alloc] initWithContainer:aContainer flags:aFlags usage:aUsage width:width height:height dataFormat:is32Bits ? GL_RGBA8 : GL_RGB5_A1] autorelease];
    _DrawCGImageIntoBitmap(image, [texture lock], width, height, is32Bits ? 32 : 16);
    CFRelease(image);
    [texture unlock];
    [aContainer endAccumulationBlock];
    [texture setWrapS:GL_CLAMP_TO_EDGE T:GL_CLAMP_TO_EDGE];
    return texture;
}

// takes a cached tile's pixels if there is one, else decodes the file
- (void)_loadDataBySMKJPGFromFile:(id)aFile width:(NSInteger)aWidth height:(NSInteger)aHeight bitDepth:(NSInteger)aDepth bitmap:(void *)aBitmap
{
    [_locker lock];
    NSData *data = [_cachedDatas objectForKey:aFile];
    if (data != nil) {
        memcpy(aBitmap, [data bytes], aWidth * aHeight * (aDepth >> 3));
        [_locker unlock];
        return;
    }
    [_locker unlock];
    CGImageRef image = _CreateCGImageFromFile(aFile);
    if (image == NULL)
        return;
    _DrawCGImageIntoBitmap(image, aBitmap, aWidth, aHeight, (int)aDepth);
    CFRelease(image);
}

// The cached tile of the highest LOD up to aLOD covering a tile, with the
// scale and offset that map the tile into it.
- (id)nearestCachedLowResPathForLOD:(NSInteger)aLOD xPos:(NSInteger)aPos yPos:(NSInteger)aPos2 translation:(struct WeatherGlobe_anon5 *)aTranslation scaling:(struct WeatherGlobe_anon5 *)aScaling
{
    NSInteger x = aPos, y = aPos2;
    for (NSInteger lod = aLOD; lod >= 0; lod--) {
        id path = [[self class] pathForMapTextureForLOD:lod xPos:x yPos:y];
        if ([_cachedDatas objectForKey:path] != nil) {
            int tiles = _tilesForLOD(aLOD);
            int lodTiles = _tilesForLOD(lod);
            if (aScaling != NULL)
                aScaling->f0 = aScaling->f1 = (float)(tiles / lodTiles);
            if (aTranslation != NULL) {
                aTranslation->f0 = (float)aPos * ((float)lodTiles / (float)tiles) - (float)x;
                aTranslation->f1 = ((float)lodTiles / (float)tiles) * (float)aPos2 - (float)y;
            }
            return path;
        }
        if (lod == 1 || lod == 2) {
            x /= 3;
            y /= 3;
        } else if (lod == 3) {
            x /= 2;
            y /= 2;
        }
    }
    return nil;
}

- (void)dealloc
{
    [_cachedDatas release];
    [_locker release];
    [_recacheLocker release];
    [_pathsForbiddenToRemove release];
    [super dealloc];
}

// stops the cache thread and gives up the owner's reference
- (void)invalidate
{
    [self _stopCurrentRecache];
    if ([_recacheLocker condition] != 0)
        [_recacheLocker lockWhenCondition:0];
    else
        [_recacheLocker tryLockWhenCondition:0];
    _threadTerminationRequested = YES;
    [_recacheLocker unlockWithCondition:1];
    [_nightWestTexture release];
    _nightWestTexture = nil;
    [_nightEastTexture release];
    _nightEastTexture = nil;
    [self release];
}

- (void)_stopCurrentRecache
{
    if ([_recacheLocker condition] != 0)
        _recacheTerminationRequested = YES;
}

- (id)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _use32BitsTextures = [[AtlasController atlasController] enableMaxQuality];
    _cachedDatas = [NSMutableDictionary new];
    _locker = [NSRecursiveLock new];
    _recacheLocker = [[NSConditionLock alloc] initWithCondition:0];
    [_recacheLocker lockWhenCondition:0];
    // the whole map at LOD 0 and 1 always stays cached
    _pathsForbiddenToRemove = [NSMutableArray new];
    Class loaderClass = [self class];
    [_pathsForbiddenToRemove addObject:[loaderClass pathForMapTextureForLOD:0 xPos:0 yPos:0]];
    [_pathsForbiddenToRemove addObject:[loaderClass pathForMapTextureForLOD:0 xPos:1 yPos:0]];
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 6; x++)
            [_pathsForbiddenToRemove addObject:[loaderClass pathForMapTextureForLOD:1 xPos:x yPos:y]];
    [NSThread detachNewThreadSelector:@selector(_newThreadEnterFunc:) toTarget:self withObject:nil];
    return self;
}

@end
