#import "CloudsManager.h"

// newest first; for the same time "west" comes before "east"
static NSInteger _fileNameSort(id aName1, id aName2, void *aContext)
{
    NSArray *parts1 = [[aName1 stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    NSArray *parts2 = [[aName2 stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    if ([parts1 count] != 5)
        return [parts2 count] == 5 ? 1 : 0;
    if ([parts2 count] != 5)
        return -1;
    for (int i = 1; i < 5; i++) {
        int value1 = [[parts1 objectAtIndex:i] intValue];
        int value2 = [[parts2 objectAtIndex:i] intValue];
        if (value1 > value2)
            return -1;
        if (value1 < value2)
            return 1;
    }
    BOOL west1 = [[parts1 objectAtIndex:0] isEqualToString:@"west"];
    BOOL west2 = [[parts2 objectAtIndex:0] isEqualToString:@"west"];
    if (west1 > west2)
        return -1;
    if (west1 < west2)
        return 1;
    return 0;
}

@implementation CloudsManager

+ (id)cloudsFileNameForDate:(id)aDate isEast:(BOOL)aEast forToday:(BOOL)aToday
{
    NSString *side = aEast ? @"east" : @"west";
    if (aToday)
        return [NSString stringWithFormat:@"%@_tooday.jpg", side];
    return [NSString stringWithFormat:@"%@_%@_%d.jpg", side, [aDate descriptionWithCalendarFormat:@"%y_%m_%d"], (int)([aDate hourOfDay] / 6)];
}

- (void)setUseDefaultClouds:(BOOL)aClouds
{
    BOOL previous = _useDefaultClouds;
    _useDefaultClouds = aClouds;
    if (previous != aClouds) {
        [self cleanup];
        [self restoreAfterCleanup];
    }
}

- (id)currentCloudsBitmapReps
{
    [self _updateFramesIfNeeded];
    NSBitmapImageRep *east = nil;
    NSBitmapImageRep *west = nil;
    if ([_decompressedFramesSequence count] > 1) {
        NSString *eastPath = [[_decompressedFramesMap allKeysForObject:[_decompressedFramesSequence objectAtIndex:0]] objectAtIndex:0];
        NSString *westPath = [[_decompressedFramesMap allKeysForObject:[_decompressedFramesSequence objectAtIndex:1]] objectAtIndex:0];
        east = [self _24bitBitmapWithPath:eastPath];
        west = [self _24bitBitmapWithPath:westPath];
    }
    if (east == nil || west == nil) {
        NSArray *names = [self _allCloudsFileNames];
        NSInteger count = [names count];
        for (NSInteger i = 0; ; i += 2) {
            if (i + 1 >= count)
                return nil;
            east = [self _24bitBitmapWithPath:[names objectAtIndex:i]];
            west = [self _24bitBitmapWithPath:[names objectAtIndex:i + 1]];
            if (east != nil && west != nil)
                break;
        }
    }
    return [NSArray arrayWithObjects:east, west, nil];
}

- (NSUInteger)frameTextureFormat
{
    return GL_RGB5_A1;
}

- (NSSize)frameTextureSize
{
    float size;
    if (![Preferences usesInternet] || _useDefaultClouds)
        size = 1024.0f;
    else
        size = (float)[Preferences cloudsTextureWidth];
    return NSMakeSize(size, size);
}

- (void)updateTexture:(id)aTexture withContentsOfFrame:(NSInteger)aFrame forEast:(BOOL)aEast
{
    [self _updateFramesIfNeeded];
    NSInteger index = aFrame * 2 + (aEast ? 0 : 1);
    if (index < 0 || (NSUInteger)index >= [_decompressedFramesSequence count])
        return;
    SMK_GL_2DTexture *texture = aTexture;
    NSInteger expected = [texture width] * ([texture bitsPerPixel] >> 3) * [texture height];
    NSData *frame = [_decompressedFramesSequence objectAtIndex:index];
    if (expected != (NSInteger)[frame length])
        return;
    memcpy([texture lock], [frame bytes], [frame length]);
    [texture unlock];
}

- (NSInteger)framesCount
{
    [self _updateFramesIfNeeded];
    return [_decompressedFramesSequence count] >> 1;
}

- (void)_updateFramesIfNeeded
{
    [_decompMapLocker lock];
    BOOL update = _doUpdateFramesInfo;
    _doUpdateFramesInfo = NO;
    if (update) {
        [_decompressedFramesSequence removeAllObjects];
        NSArray *names = [self _allCloudsFileNames];
        NSInteger count = [names count];
        for (NSInteger i = 0; i + 1 < count; i += 2) {
            id east = [_decompressedFramesMap objectForKey:[names objectAtIndex:i]];
            id west = [_decompressedFramesMap objectForKey:[names objectAtIndex:i + 1]];
            if (east != nil && west != nil) {
                [_decompressedFramesSequence addObject:east];
                [_decompressedFramesSequence addObject:west];
            }
        }
    }
    [_decompMapLocker unlock];
}

- (NSInteger)_decompressionThreadEnterFunc:(id)aFunc
{
    NSAutoreleasePool *outerPool = [NSAutoreleasePool new];
    while (YES) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        [_schedulerLock lockWhenCondition:1];
        if (_threadTerminationRequested) {
            [pool release];
            break;
        }
        [_queueLocker lock];
        NSString *path = nil;
        if ([_queueForDecompression count] > 0) {
            path = [[[_queueForDecompression objectAtIndex:0] retain] autorelease];
            [_queueForDecompression removeObjectAtIndex:0];
        }
        [_queueLocker unlock];
        if (path != nil) {
            [self _decompressJPGWithPath:path];
            [self performSelectorOnMainThread:@selector(_decompressionSubtaskFinished) withObject:nil waitUntilDone:NO];
        }
        [_queueLocker lock];
        [_schedulerLock unlockWithCondition:[_queueForDecompression count] > 0 ? 1 : 0];
        [_queueLocker unlock];
        [pool release];
    }
    [_schedulerLock unlockWithCondition:0];
    [outerPool release];
    return 0;
}

- (void)_decompressJPGWithPath:(id)aPath
{
    CGImageRef image = _CreateCGImageFromFile(aPath);
    if (image == NULL)
        return;
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    NSMutableData *bitmap = [NSMutableData dataWithLength:width * 2 * height];
    _DrawCGImageIntoBitmap(image, [bitmap mutableBytes], width, height, 16);
    CFRelease(image);
    if (bitmap != nil) {
        [_decompMapLocker lock];
        [_decompressedFramesMap setObject:bitmap forKey:aPath];
        _doUpdateFramesInfo = YES;
        [_decompMapLocker unlock];
    }
}

- (id)_24bitBitmapWithPath:(id)aPath
{
    CGImageRef image = _CreateCGImageFromFile(aPath);
    if (image == NULL)
        return nil;
    NSInteger width = CGImageGetWidth(image);
    NSInteger height = CGImageGetHeight(image);
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:width * 4 bitsPerPixel:32] autorelease];
    _DrawCGImageIntoBitmap(image, [rep bitmapData], width, height, 32);
    CFRelease(image);
    return rep;
}

- (void)_decompressionSubtaskFinished
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SingleCloudMapWasDecompressedNotification object:self];
}

- (void)removeCacheFiles
{
    [self cleanup];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = [manager cloudsDownloadFolder];
    NSArray *contents = [manager contentsOfDirectoryAtPath:folder error:NULL];
    NSInteger count = [contents count];
    for (NSInteger i = 0; i < count; i++) {
        NSString *path = [folder stringByAppendingPathComponent:[contents objectAtIndex:i]];
        if ([manager isDeletableFileAtPath:path])
            [manager removeItemAtPath:path error:NULL];
    }
    [_decompressedFramesSequence removeAllObjects];
}

- (void)restoreAfterCleanup
{
    [self _cloudsFilesWereUpdated:nil];
}

- (void)cleanup
{
    [_schedulerLock lock];
    [_schedulerLock unlockWithCondition:0];
    [_queueLocker lock];
    [_decompMapLocker lock];
    [_decompressedFramesMap removeAllObjects];
    [_queueForDecompression removeAllObjects];
    [_decompressedFramesSequence removeAllObjects];
    [_decompMapLocker unlock];
    [_queueLocker unlock];
}

- (void)_cloudsFilesWereUpdated:(id)aUpdated
{
    if (![Preferences cloudsEnabled]) {
        [self cleanup];
        return;
    }
    NSArray *names = [self _allCloudsFileNames];
    NSInteger count = [names count];
    for (NSInteger i = 0; i < count; i++)
        [self _scheduleJPGToDecompress:[names objectAtIndex:i]];
}

- (id)_allCloudsFileNames
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableArray *names = [NSMutableArray array];
    NSCalendarDate *date;
    NSString *folder;
    if (![Preferences usesInternet] || _useDefaultClouds) {
        NSArray *downloaded = [self lastDownloadedCloudsFileNames];
        if ([downloaded count] > 13)
            return downloaded;
        date = [NSCalendarDate dateWithYear:2004 month:9 day:30 hour:1 minute:0 second:0 timeZone:nil];
        folder = [[NSBundle mainBundle] pathForResource:@"CloudsDefault" ofType:@""];
    } else {
        date = [NSCalendarDate calendarDate];
        folder = [manager cloudsDownloadFolder];
    }
    NSString *east = [folder stringByAppendingPathComponent:[CloudsManager cloudsFileNameForDate:date isEast:YES forToday:YES]];
    if ([manager fileExistsAtPath:east]) {
        NSString *west = [folder stringByAppendingPathComponent:[CloudsManager cloudsFileNameForDate:date isEast:NO forToday:YES]];
        if ([manager fileExistsAtPath:west]) {
            [names addObject:east];
            [names addObject:west];
        }
    }
    for (int i = 12; i != 0; i--) {
        NSString *eastPath = [folder stringByAppendingPathComponent:[CloudsManager cloudsFileNameForDate:date isEast:YES forToday:NO]];
        BOOL eastExists = [manager fileExistsAtPath:eastPath];
        NSString *westPath = [folder stringByAppendingPathComponent:[CloudsManager cloudsFileNameForDate:date isEast:NO forToday:NO]];
        if ([manager fileExistsAtPath:westPath] && eastExists) {
            [names addObject:eastPath];
            [names addObject:westPath];
        }
        date = [date dateByAddingYears:0 months:0 days:0 hours:-6 minutes:0 seconds:0];
    }
    return names;
}

- (id)lastDownloadedCloudsFileNames
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = [manager cloudsDownloadFolder];
    NSMutableArray *files = [NSMutableArray arrayWithArray:[manager contentsOfDirectoryAtPath:folder error:NULL]];
    [files removeObject:@"west_tooday"];
    [files removeObject:@"east_tooday"];
    NSArray *sorted = [files sortedArrayUsingFunction:_fileNameSort context:NULL];
    NSMutableArray *names = [NSMutableArray array];
    NSInteger count = [sorted count];
    NSInteger i = 0;
    while (i < count && [names count] <= 13) {
        // find the next west file and pair it with the east file after it
        while (i < count) {
            NSString *west = [sorted objectAtIndex:i++];
            if (![west hasPrefix:@"west"])
                continue;
            NSString *east = nil;
            if (i < count) {
                NSString *next = [sorted objectAtIndex:i];
                if ([next hasPrefix:@"east"]) {
                    i++;
                    if ([[next substringFromIndex:4] isEqualToString:[west substringFromIndex:4]])
                        east = next;
                }
            }
            if (east != nil) {
                [names addObject:[folder stringByAppendingPathComponent:east]];
                [names addObject:[folder stringByAppendingPathComponent:west]];
            }
            break;
        }
    }
    return names;
}

- (void)_scheduleJPGToDecompress:(id)aDecompress
{
    [_queueLocker lock];
    [_decompMapLocker lock];
    if (![_queueForDecompression containsObject:aDecompress] && [_decompressedFramesMap objectForKey:aDecompress] == nil) {
        [_queueForDecompression addObject:aDecompress];
        if ([_schedulerLock tryLock])
            [_schedulerLock unlockWithCondition:1];
    }
    [_decompMapLocker unlock];
    [_queueLocker unlock];
}

- (void)removeDataForFile:(id)aFile
{
    [_decompMapLocker lock];
    [_queueLocker lock];
    [_decompressedFramesMap removeObjectForKey:aFile];
    [_queueForDecompression removeObject:aFile];
    [_decompMapLocker unlock];
    [_queueLocker unlock];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_decompressedFramesSequence release];
    [_decompMapLocker release];
    _decompMapLocker = nil;
    [_schedulerLock release];
    _schedulerLock = nil;
    [_queueLocker release];
    _queueLocker = nil;
    [_queueForDecompression release];
    [super dealloc];
}

- (void)invalidate
{
    _threadTerminationRequested = YES;
    [_schedulerLock lock];
    [_schedulerLock unlockWithCondition:1];
    [self release];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cloudsFilesWereUpdated:) name:kCloudsWereUpdatedNotification object:nil];
        _decompressedFramesSequence = [NSMutableArray new];
        _decompressedFramesMap = [NSMutableDictionary new];
        _queueForDecompression = [NSMutableArray new];
        _decompMapLocker = [NSRecursiveLock new];
        _queueLocker = [NSRecursiveLock new];
        _schedulerLock = [[NSConditionLock alloc] initWithCondition:0];
        [NSThread detachNewThreadSelector:@selector(_decompressionThreadEnterFunc:) toTarget:self withObject:nil];
    }
    return self;
}

@end
