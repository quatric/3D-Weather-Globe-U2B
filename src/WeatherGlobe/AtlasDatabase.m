#import "AtlasDatabase.h"

static const float *__sEntryYComparatorContext;

static int __entriesYComparator(const void *a, const void *b)
{
    float ya = __sEntryYComparatorContext[*(const int *)a * 2 + 1];
    float yb = __sEntryYComparatorContext[*(const int *)b * 2 + 1];
    if (ya < yb)
        return -1;
    return yb < ya;
}

@implementation AtlasDatabase

+ (id)database
{
    return [[AtlasController atlasController] database];
}

- (void)setNewAppleStoresData:(id)aData
{
    NSString *path = [self _appleStoresCachePath];
    if ([aData writeToFile:path atomically:YES]) {
        [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777]
                                                                                  forKey:NSFilePosixPermissions]
                                         ofItemAtPath:path error:NULL];
        [_appleStoresRep release];
        [_appleStores release];
        [_appleStoreKinds release];
        _appleStoresRep = nil;
        _appleStores = nil;
        _appleStoreKinds = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kAppleStoresChangedNotification object:self];
    }
}

- (id)appleStoreKinds
{
    if (_appleStoreKinds == nil) {
        NSArray *stores = [self appleStores];
        NSUInteger count = [stores count], i;
        NSMutableDictionary *kinds = nil;
        for (i = 0; i < count; i++) {
            AppleStoreEntry *store = [stores objectAtIndex:i];
            id title = [store infoPaletteTitle];
            if (kinds == nil)
                kinds = [NSMutableDictionary dictionary];
            if ([kinds objectForKey:title] == nil) {
                struct WeatherGlobe_anon7 c = [store markerColor];
                [kinds setObject:[NSColor colorWithDeviceRed:c.f0 green:c.f1 blue:c.f2 alpha:c.f3] forKey:title];
            }
        }
        if (kinds != nil)
            _appleStoreKinds = [[NSDictionary alloc] initWithDictionary:kinds];
    }
    return _appleStoreKinds;
}

- (id)appleStoresRep
{
    if (_appleStoresRep == nil) {
        _appleStoresRep = [[NSDictionary alloc] initWithContentsOfFile:[self _appleStoresCachePath]];
        if (_appleStoresRep == nil)
            _appleStoresRep = [[NSDictionary alloc] initWithContentsOfFile:
                [[NSBundle mainBundle] pathForResource:kAppleStoresRouteFileName ofType:kAppleStoresSetFileExt]];
    }
    return _appleStoresRep;
}

- (id)appleStores
{
    if (_appleStores == nil) {
        NSArray *entries = [[self appleStoresRep] objectForKey:@"entries"];
        NSUInteger count = [entries count], i;
        NSMutableArray *stores = [NSMutableArray arrayWithCapacity:count];
        for (i = 0; i < count; i++)
            [stores addObject:[AppleStoreEntry entryWithDictionaryRep:[entries objectAtIndex:i]]];
        _appleStores = [[NSArray alloc] initWithArray:stores];
    }
    return _appleStores;
}

- (id)_appleStoresCachePath
{
    return [[[NSFileManager defaultManager] atlasSharedFolder] stringByAppendingPathComponent:@"appleStores.plist"];
}

- (id)allCountryBordersForLOD:(NSInteger)aLOD
{
    return [[self _bordersWithShapeType:0] allPathsForLOD:aLOD];
}

- (id)allUIDsForShapeType:(NSInteger)aType
{
    return [[self _bordersWithShapeType:aType] allObjectUIDs];
}

- (id)infoWithShapeType:(NSInteger)aType underGeoPoint:(NSPoint)aPoint lod:(NSInteger)aLod
{
    return [self infoWithShapeUID:[self shapeUIDOfType:aType underGeoPoint:aPoint] lod:aLod];
}

- (id)infoWithShapeUID:(id)aUID lod:(NSInteger)aLod
{
    if (aUID == nil)
        return nil;
    YACityEntry *entry = [self dbEntryWithUID:aUID];
    IndexBuffersBLOB *shape = [entry wrapperWithRepresentationOfType:kRepTypeShapeIndices createIfNeeded:YES];
    NSRect largest = [shape largestPathBounds];
    NSRect all = [shape allPathsBounds];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [entry ownName], kBoundInfoOwnShapeNameKey,
        [entry shortCaption], kBoundInfoFullShapeNameKey,
        [shape allPathsForLOD:3], kBoundInfoPathsKey,
        [shape allPathsForLOD:aLod], kBoundInfoDrawedPathsKey,
        [NSValue valueWithRect:all], kBoundInfoEnclosingRectKey,
        [NSValue valueWithRect:largest], kBoundInfoMaxPathBoundsKey,
        nil];
}

- (id)shapeUIDOfType:(NSInteger)aType underGeoPoint:(NSPoint)aPoint
{
    id uid = [[self _bordersWithShapeType:aType] objectUIDBelowGeoPoint:aPoint];
    if (uid != nil && [self dbEntryWithUID:uid] != nil)
        return uid;
    return nil;
}

- (id)_bordersWithShapeType:(NSInteger)aType
{
    switch (aType) {
    case 0:
        if (_countryBorders == nil)
            _countryBorders = [[BoundariesContainer alloc] initWithGridDBName:kRepTypeLookupGridCountries
                                                                       geotype:kGeoTypeCountry];
        return _countryBorders;
    case 1:
        if (_stateBorders == nil)
            _stateBorders = [[BoundariesContainer alloc] initWithGridDBName:kRepTypeLookupGridStates
                                                                     geotype:kGeoTypeState];
        return _stateBorders;
    case 2:
        if (_countyBorders == nil)
            _countyBorders = [[BoundariesContainer alloc] initWithGridDBName:kRepTypeLookupGridCounties
                                                                      geotype:kGeoTypeCounty];
        return _countyBorders;
    case 3:
        if (_tzBorders == nil)
            _tzBorders = [[BoundariesContainer alloc] initWithGridDBName:kRepTypeLookupGridTimezones
                                                                  geotype:kGeoTypeTimezone];
        return _tzBorders;
    }
    return nil;
}

- (void)_rescanWasFinishedWithResult:(id)aResult
{
    [NSApp abortModal];
    NSLog(@"_rescanWasFinished");
    if ([aResult boolValue]) {
        [self _invalidateDBCaches];
        [_allPointsArray release];
        _allPointsArray = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kMainDatabaseChangedNotification object:self];
    }
}

- (void)_rescanAndApplyUpdates:(id)aUpdates
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [_dbLocker lock];
    NSArray *files = [self _allUpdateFiles];
    // The original returned here without unlocking or releasing the pool.
    if ([files count] == 0) {
        [_dbLocker unlock];
        [pool release];
        return;
    }
    BOOL result = [self _processDumpsFromFiles:files postNotifications:NO];
    [_dbLocker unlock];
    NSLog(@"_processDumpsFromFiles complete");
    [self performSelectorOnMainThread:@selector(_rescanWasFinishedWithResult:)
                           withObject:[NSNumber numberWithBool:result]
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
    [pool release];
}

- (void)rescanForUpdatesWithModalWindow:(id)aWindow
{
    if ([[self _allUpdateFiles] count] != 0) {
        [NSThread detachNewThreadSelector:@selector(_rescanAndApplyUpdates:) toTarget:self withObject:nil];
        [NSApp runModalForWindow:aWindow];
    }
}

- (id)dbEntryWithSystemTimeZoneCity
{
    [NSUserDefaults resetStandardUserDefaults];
    NSArray *city = [[NSUserDefaults standardUserDefaults] objectForKey:@"com.apple.TimeZonePref.Last_Selected_City"];
    NSInteger count = [city count];
    id timeZoneName = nil, cityName = nil, regionName = nil;
    if (count >= 4) {
        timeZoneName = [city objectAtIndex:3];
        if (count > 5) {
            cityName = [city objectAtIndex:count > 7 ? 7 : 5];
            if (count >= 7)
                regionName = [city objectAtIndex:count > 8 ? 8 : 6];
        }
    }

    NSArray *rows = [self searchWithRequest:[NSString selectCitiesUIDsWithCityName:cityName]];
    NSUInteger rowCount = [rows count], i;
    int bestScore = 0;
    YACityEntry *best = nil;
    for (i = 0; i < rowCount; i++) {
        YACityEntry *entry = [self dbEntryWithUID:[[rows objectAtIndex:i] objectForKey:kColumnNameUID]];
        NSRange range = regionName ? [[entry regionName] rangeOfString:regionName] : NSMakeRange(NSNotFound, 0);
        int score = (range.location == NSNotFound || range.length == 0) ? 1 : 2;
        if ([[[entry timeZone] name] isEqualToString:timeZoneName])
            score++;
        if (score > bestScore) {
            bestScore = score;
            best = entry;
        }
        if (bestScore == 3)
            break;
    }
    if (best != nil)
        return best;

    rows = [self searchWithRequest:[NSString selectCitiesUIDsWithCityName:@"Cupertino"]];
    rowCount = [rows count];
    if (rowCount > 0) {
        YACityEntry *entry = nil;
        for (i = 0; i < rowCount; i++) {
            entry = [self dbEntryWithUID:[[rows objectAtIndex:i] objectForKey:kColumnNameUID]];
            NSRange range = [[entry regionName] rangeOfString:@"California"];
            if (range.location != NSNotFound && range.length != 0)
                break;
        }
        if (entry != nil)
            return entry;
    }
    rows = [self searchWithRequest:[NSString selectAnyCityUID]];
    if ([rows count] == 0)
        return nil;
    return [self dbEntryWithUID:[[rows objectAtIndex:0] objectForKey:kColumnNameUID]];
}

- (id)dbEntryWithAddressBookCity
{
    ABMultiValue *addresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABAddressProperty];
    NSDictionary *address = [addresses valueAtIndex:[addresses indexForIdentifier:[addresses primaryIdentifier]]];
    id cityName = [address objectForKey:kABAddressCityKey];
    id country = [address objectForKey:kABAddressCountryKey];
    YACityEntry *entry = nil;
    if (cityName != nil) {
        NSArray *rows = [self searchWithRequest:[NSString selectCitiesUIDsWithCityName:cityName]];
        NSUInteger count = [rows count], i;
        for (i = 0; i < count; i++) {
            entry = [self dbEntryWithUID:[[rows objectAtIndex:i] objectForKey:kColumnNameUID]];
            if ([[entry regionName] isEqualToString:country])
                return entry;
        }
    }
    return entry;
}

- (NSPoint)geoPointForDBEntryWithUID:(id)aUID
{
    return [[self dbEntryWithUID:aUID] coordinates];
}

- (struct WeatherGlobe_anon2 *)earthVecForDBEntryWithUID:(id)aUID
{
    return [[self dbEntryWithUID:aUID] vectorFromEarthCenter];
}

- (id)dbEntryWithUID:(id)aUID
{
    if (aUID == nil)
        return nil;
    id entry = [_geoObjects objectForKey:aUID];
    if (entry == nil) {
        if (_geoObjects == nil)
            _geoObjects = [NSMutableDictionary new];
        entry = [self _createSQL_DB_EntryWithUID:aUID];
        if (entry != nil)
            [_geoObjects setObject:entry forKey:aUID];
    }
    return entry;
}

- (id)_createSQL_DB_EntryWithUID:(id)aUID
{
    if (_entryByUIDStatement == nil)
        _entryByUIDStatement = [[SQLiteStatement alloc] initWithDB:_db
                                                           request:[NSString selectGeoObjectWithBondUID:aUID]];
    else
        [_entryByUIDStatement reset];
    SQLiteResultsContainer *results = [_entryByUIDStatement processWithParameters:
        [NSDictionary dictionaryWithObject:aUID forKey:@"UID_VAL"]];
    if (results != nil && [results count] == 1)
        return [YACityEntry entryWithGeoObjectDictionary:[results objectAtIndex:0]];
    return nil;
}

- (void)rescanForUpdates
{
    NSArray *files = [self _allUpdateFiles];
    if ([files count] != 0)
        [self _processDumpsFromFiles:files postNotifications:YES];
}

- (id)_allUpdateFiles
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *folder = [manager updatesDownloadFolder];
    NSArray *contents = [manager contentsOfDirectoryAtPath:folder error:NULL];
    NSMutableArray *files = [NSMutableArray array];
    NSUInteger count = [contents count], i;
    for (i = 0; i < count; i++) {
        NSString *name = [contents objectAtIndex:i];
        if ([name hasPrefix:@"upd"])
            [files addObject:[folder stringByAppendingPathComponent:name]];
    }
    [files sortUsingSelector:@selector(compare:)];
    return files;
}

- (BOOL)_processDumpsFromFiles:(id)aFiles postNotifications:(BOOL)aNotifications
{
    NSUInteger count = [aFiles count], i;
    BOOL applied = NO;
    if (count == 0)
        return NO;
    if (aNotifications)
        [[NSNotificationCenter defaultCenter] postNotificationName:kMainDatabaseWillStartUpdate object:self];
    for (i = 0; i < count; i++) {
        NSString *path = [aFiles objectAtIndex:i];
        NSString *name = [[path lastPathComponent] lowercaseString];
        id existing = [self simpleSearchWithRequest:[NSString selectFilenameFromUpdatesThatIsLike:name]];
        if (existing == nil) {
            NSLog(@"Unable to process the request.");
            return NO;
        }
        if ([existing count] != 0)
            continue;
        @try {
            NSData *dump = [[NSData dataWithContentsOfFile:path] originalRepresentation];
            if (dump == nil) {
                NSLog(@"Unable to load and decomress data at path %@", path);
            } else if (![_db processRequestsWithData:dump ignoringErrors:YES]) {
                @try {
                    [self simpleSearchWithRequest:@"ROLLBACK TRANSACTION"];
                } @catch (NSException *exception) {
                }
                NSLog(@"Unable to execute dump at %@", path);
            } else {
                [self simpleSearchWithRequest:[NSString insertFilenameIntoUpdates:name]];
                applied = YES;
            }
        } @catch (NSException *exception) {
        }
    }
    if (applied) {
        [self _invalidateDBCaches];
        [_allPointsArray release];
        _allPointsArray = nil;
        if (!aNotifications)
            return YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:kMainDatabaseChangedNotification object:self];
    } else if (!aNotifications) {
        return NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kMainDatabaseDidEndUpdate object:self];
    return applied;
}

- (void)_invalidateDBCaches
{
    [_geoObjects release];
    _geoObjects = nil;
    [_allSampleRoutes release];
    _allSampleRoutes = nil;
    [_allPointsArray release];
    _allPointsArray = nil;
    [_allPointUIDsArray release];
    _allPointUIDsArray = nil;
    [_entriesIndsSortedByY release];
    _entriesIndsSortedByY = nil;
}

- (int *)indicesSortedByY
{
    if (_entriesIndsSortedByY == nil) {
        NSData *points = [self allCityPointsArray];
        int count = (int)([points length] / 8), i;
        _entriesIndsSortedByY = [[NSMutableData alloc] initWithLength:count * 4];
        int *indices = (int *)[_entriesIndsSortedByY bytes];
        for (i = 0; i < count; i++)
            indices[i] = i;
        __sEntryYComparatorContext = [points bytes];
        qsort(indices, count, 4, __entriesYComparator);
    }
    return (int *)[_entriesIndsSortedByY bytes];
}

- (void)cleanupOnWindowClose
{
    [_countryBorders release];
    [_stateBorders release];
    [_countyBorders release];
    [_tzBorders release];
    _countryBorders = nil;
    _stateBorders = nil;
    _countyBorders = nil;
    _tzBorders = nil;
}

- (void)dealloc
{
    [_entriesIndsSortedByY release];
    [_countryBorders release];
    [_stateBorders release];
    [_countyBorders release];
    [_tzBorders release];
    [_appleStoresRep release];
    [_appleStoreKinds release];
    [_appleStores release];
    [_db release];
    [_dbLocker release];
    [_searchLocker release];
    [_geoObjects release];
    _geoObjects = nil;
    [_allPointsArray release];
    _allPointsArray = nil;
    [_allPointUIDsArray release];
    _allPointUIDsArray = nil;
    [_entryByUIDStatement release];
    [_allSampleRoutes release];
    [_allSampleRouteBLOBs release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        [self _initializeSQLDatabase];
        [self _initializeEntries];
    }
    return self;
}

- (void)_initializeEntries
{
}

- (void)_initializeSQLDatabase
{
    _dbLocker = [NSRecursiveLock new];
    _searchLocker = [NSRecursiveLock new];
    NSString *workingPath = _atlasDBWorkingFilePath();
    NSString *originalPath = _atlasDBOriginalFilePath();
    NSFileManager *manager = [NSFileManager defaultManager];

    if ([manager isWritableFileAtPath:workingPath] && [manager isReadableFileAtPath:workingPath]) {
        NSDate *workingDate = [[manager attributesOfItemAtPath:workingPath error:NULL] fileModificationDate];
        NSDate *originalDate = [[manager attributesOfItemAtPath:originalPath error:NULL] fileModificationDate];
        if ([originalDate timeIntervalSinceReferenceDate] <= [workingDate timeIntervalSinceReferenceDate]) {
            _db = [[SQLiteDatabase alloc] initWithDatabasePath:workingPath];
            if (_db != nil)
                return;
        }
    }

    [manager removeItemAtPath:workingPath error:NULL];
    if (![manager copyItemAtPath:originalPath toPath:workingPath error:NULL]) {
        NSLog(@"Failed to copy atlas DB file to it's default location");
        return;
    }
    if (![manager setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777]
                                                            forKey:NSFilePosixPermissions]
                   ofItemAtPath:workingPath error:NULL])
        NSLog(@"Failed to set correct privileges to atlas DB file at it's default location");
    if (![manager isWritableFileAtPath:workingPath] || ![manager isReadableFileAtPath:workingPath])
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
            file:@"/Users/3dwgbuilder/Projects/3DWGBuildFolder/WBAll/WBAtlas/Sources/Database/AtlasDatabase.m"
            lineNumber:0x73 description:@"Failed to get full access to DB file."];
    _db = [[SQLiteDatabase alloc] initWithDatabasePath:workingPath];
}

@end

@implementation AtlasDatabase (NearestCitySearching)

// Walks outward from the target latitude through the cities sorted by Y,
// stopping once the latitude difference alone rules out anything closer.
- (id)cityNearestToGeoPoint:(NSPoint)aPoint
{
    const float *points = [[self allCityPointsArray] bytes];
    int count = (int)([[self allCityPointsArray] length] / 8);
    if (count == 0)
        return nil;
    const int *indices = [self indicesSortedByY];
    float y = (float)aPoint.y;
    SMK_GL_Vec3 target = _earthVecFromGeoPoint(aPoint);

    int lo = 0, hi = count - 1, mid = 0, dir = 0;
    BOOL exact = NO;
    while (lo <= hi) {
        mid = (lo + hi) / 2;
        float delta = y - points[indices[mid] * 2 + 1];
        if (delta > 0) {
            lo = mid + 1;
            dir = 1;
        } else if (delta < 0) {
            hi = mid - 1;
            dir = -1;
        } else {
            exact = YES;
            break;
        }
    }
    if (!exact && dir > 0)
        mid++;
    // The original could index one past the end here and when stepping up.
    if (mid >= count)
        mid = count - 1;

    int down = mid;
    int up = mid + 1 < count ? mid + 1 : 0;
    float downBound = -cosf(_deg2radf(y - points[indices[down] * 2 + 1]));
    float upBound = -cosf(_deg2radf(y - points[indices[up] * 2 + 1]));
    SMK_GL_Vec3 vec = _earthVecFromGeoPoint(NSMakePoint(points[indices[down] * 2], points[indices[down] * 2 + 1]));
    float bestDist = _distEstimationFromEarthVecs(&target, &vec);
    int best = indices[down];
    float passed;

    do {
        int index;
        if (downBound > upBound) {
            up = up + 1 < count ? up + 1 : 0;
            index = indices[up];
            passed = upBound;
            upBound = -cosf(_deg2radf(y - points[index * 2 + 1]));
        } else {
            down = down != 0 ? down - 1 : count - 1;
            index = indices[down];
            passed = downBound;
            downBound = -cosf(_deg2radf(y - points[index * 2 + 1]));
        }
        vec = _earthVecFromGeoPoint(NSMakePoint(points[index * 2], points[index * 2 + 1]));
        float dist = _distEstimationFromEarthVecs(&target, &vec);
        if (dist < bestDist) {
            best = index;
            bestDist = dist;
        }
    } while (passed < bestDist);

    const char *uids = [[self allCityUIDsArray] bytes];
    return [self dbEntryWithUID:[[[NSString alloc] initWithBytes:uids + best * 10 length:10
                                                        encoding:NSASCIIStringEncoding] autorelease]];
}

@end

@implementation NSDictionary (WBAtlasBoundaries)

- (NSInteger)countryRin
{
    return 0;
}

- (NSRect)maxPathBounds
{
    return [[self objectForKey:kBoundInfoMaxPathBoundsKey] rectValue];
}

- (NSRect)enclosingRect
{
    return [[self objectForKey:kBoundInfoEnclosingRectKey] rectValue];
}

- (id)drawedBorderPaths
{
    return [self objectForKey:kBoundInfoDrawedPathsKey];
}

- (id)borderPaths
{
    return [self objectForKey:kBoundInfoPathsKey];
}

- (id)fullShapeName
{
    return [self objectForKey:kBoundInfoFullShapeNameKey];
}

- (id)ownShapeName
{
    return [self objectForKey:kBoundInfoOwnShapeNameKey];
}

@end
