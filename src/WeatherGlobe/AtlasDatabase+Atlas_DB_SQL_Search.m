#import "AtlasDatabase+Atlas_DB_SQL_Search.h"

// Search results hold the columns of +searchForGeoObjectWithSubstring:
// UID, name, type, county UID, state UID, country UID. The state and country
// names are cached per sort by their UIDs.
static NSInteger __globalSortingMode;
static NSMutableDictionary *__globalStateNamesRemap;
static NSMutableDictionary *__globalCntryNamesRemap;

static const char *__cachedOwnName(NSMutableDictionary *aCache, const char *aUID, int aLength)
{
    NSString *uid = [[[NSString alloc] initWithBytes:aUID length:aLength encoding:NSMacOSRomanStringEncoding] autorelease];
    NSString *name = [aCache objectForKey:uid];
    if (name == nil) {
        name = [[[AtlasDatabase database] dbEntryWithUID:uid] ownName];
        if (name == nil)
            return NULL;
        [aCache setObject:name forKey:uid];
    }
    return [name UTF8String];
}

static int __compareOptionalNames(const char *a, const char *b)
{
    if (a == NULL)
        return b == NULL ? 0 : -1;
    if (b == NULL)
        return 1;
    return strcmp(a, b);
}

static int __sortByNameCallback(int aCols, const int *aTypes, const int *bTypes, const void *aValues, const void *bValues)
{
    BOOL byName = (unsigned)(__globalSortingMode - 2) > 1;
    const char *a = aValues, *b = bValues;
    int aLen, bLen, result;

    if (aTypes[0] != SQLITE_TEXT || bTypes[0] != SQLITE_TEXT || aTypes[1] != SQLITE_TEXT || bTypes[1] != SQLITE_TEXT) {
        NSLog(@"BLIN !!!");
        return 0;
    }
    // Skip the UID, then read the name.
    a += 4 + *(const int *)a;
    b += 4 + *(const int *)b;
    aLen = *(const int *)a;
    bLen = *(const int *)b;
    a += 4;
    b += 4;
    result = strncasecmp(a, b, MIN(aLen, bLen));
    if (result == 0) {
        if (byName && bLen - aLen != 0)
            return bLen - aLen;
    } else if (byName) {
        goto done;
    }
    a += aLen;
    b += bLen;

    // Type, then county UID.
    if (aTypes[2] == SQLITE_TEXT && bTypes[2] == SQLITE_TEXT) {
        a += 4 + *(const int *)a;
        b += 4 + *(const int *)b;
    } else {
        NSLog(@"BLIN !!!");
    }
    if (aTypes[3] == SQLITE_TEXT)
        a += 4 + *(const int *)a;
    else if (aTypes[3] != SQLITE_NULL)
        NSLog(@"BLIN !!!");
    if (bTypes[3] == SQLITE_TEXT)
        b += 4 + *(const int *)b;
    else if (bTypes[3] != SQLITE_NULL)
        NSLog(@"BLIN !!!");

    const char *aState = NULL, *bState = NULL;
    if (aTypes[4] == SQLITE_TEXT) {
        int len = *(const int *)a;
        aState = __cachedOwnName(__globalStateNamesRemap, a + 4, len);
        a += 4 + len;
    }
    if (bTypes[4] == SQLITE_TEXT) {
        int len = *(const int *)b;
        bState = __cachedOwnName(__globalStateNamesRemap, b + 4, len);
        b += 4 + len;
    }
    int location = __compareOptionalNames(aState, bState);
    if (location == 0) {
        const char *aCountry = NULL, *bCountry = NULL;
        if (aTypes[5] == SQLITE_TEXT)
            aCountry = __cachedOwnName(__globalCntryNamesRemap, a + 4, *(const int *)a);
        if (bTypes[5] == SQLITE_TEXT)
            bCountry = __cachedOwnName(__globalCntryNamesRemap, b + 4, *(const int *)b);
        location = __compareOptionalNames(aCountry, bCountry);
    }
    if (byName || location != 0)
        result = location;

done:
    if (__globalSortingMode == 3 || __globalSortingMode == 1)
        result = -result;
    return result;
}

static NSInteger __compareSampleRoutes(id a, id b, void *context)
{
    return [[a objectForKey:kColumnNameName] compare:[b objectForKey:kColumnNameName]];
}

@implementation AtlasDatabase (Atlas_DB_SQL_Search)

- (id)sampleRouteWithUID:(id)aUID
{
    id route = [[_allSampleRouteBLOBs objectForKey:aUID] object];
    if ([route isKindOfClass:[NSDictionary class]])
        return [route objectForKey:@"entries"];
    return route;
}

- (id)allSampleRoutes
{
    if (_allSampleRoutes == nil) {
        [_allSampleRouteBLOBs release];
        _allSampleRouteBLOBs = nil;
        NSMutableArray *routes = [NSMutableArray array];
        NSArray *rows = [self simpleSearchWithRequest:[NSString selectBLOBUIDsForSampleRoutes]];
        NSUInteger count = [rows count], i;
        for (i = 0; i < count; i++) {
            id uid = [[rows objectAtIndex:i] objectForKey:kColumnNameBLOBUid];
            id blob = [BLOBWrapper wrapperWithBLOBUid:uid];
            if (blob != nil && [blob isKindOfClass:[PlistBLOB class]]) {
                if (_allSampleRouteBLOBs == nil)
                    _allSampleRouteBLOBs = [NSMutableDictionary new];
                [_allSampleRouteBLOBs setObject:blob forKey:uid];
                [routes addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                    [[blob name] stringByDeletingPathExtension], kColumnNameName,
                    uid, kColumnNameBLOBUid, nil]];
            }
        }
        [routes sortUsingFunction:__compareSampleRoutes context:NULL];
        _allSampleRoutes = [[NSArray alloc] initWithArray:routes];
    }
    return _allSampleRoutes;
}

- (id)allCityUIDsArray
{
    [self allCityPointsArray];
    return _allPointUIDsArray;
}

- (id)allCityPointsArray
{
    if (_allPointsArray == nil) {
        SQLiteResultsContainer *results = [[AtlasDatabase database] searchWithRequest:[NSString selectAllCoordinatesAndUIDs]];
        NSUInteger count = [results count], i;
        _allPointsArray = [[NSMutableData alloc] initWithLength:count * 8];
        float *points = [(NSMutableData *)_allPointsArray mutableBytes];
        [_allPointUIDsArray release];
        _allPointUIDsArray = [[NSMutableData alloc] initWithLength:count * 10];
        char *uids = [(NSMutableData *)_allPointUIDsArray mutableBytes];
        int formats[3] = { 2, 2, 3 };
        for (i = 0; i < count; i++) {
            void *values[3] = { points, points + 1, uids };
            [results loadValues:values format:formats count:3 atIndex:i];
            points += 2;
            uids += 10;
        }
    }
    return _allPointsArray;
}

- (id)searchWithRequest:(id)aRequest sorting:(NSInteger)aSorting
{
    id results = [self searchWithRequest:aRequest];
    [self sortSearchResults:results mode:aSorting];
    return results;
}

- (void)sortSearchResults:(id)aResults mode:(NSInteger)aMode
{
    [_searchLocker lock];
    __globalSortingMode = aMode;
    __globalStateNamesRemap = [[NSMutableDictionary alloc] initWithCapacity:1000];
    __globalCntryNamesRemap = [[NSMutableDictionary alloc] initWithCapacity:1000];
    [aResults sortWithCallback:(void *)__sortByNameCallback];
    [__globalStateNamesRemap release];
    __globalStateNamesRemap = nil;
    [__globalCntryNamesRemap release];
    __globalCntryNamesRemap = nil;
    [_searchLocker unlock];
}

- (id)searchWithRequest:(id)aRequest parameters:(id)aParameters
{
    SQLiteStatement *statement = nil;
    id results;
    [_dbLocker lock];
    @try {
        statement = [[SQLiteStatement alloc] initWithDB:_db request:aRequest];
        results = aParameters != nil ? [statement processWithParameters:aParameters] : [statement process];
    } @catch (NSException *exception) {
        results = nil;
    }
    [statement release];
    [_dbLocker unlock];
    return results;
}

- (id)searchWithRequest:(id)aRequest
{
    return [self searchWithRequest:aRequest parameters:nil];
}

- (id)simpleSearchWithRequest:(id)aRequest
{
    id results;
    [_dbLocker lock];
    @try {
        results = [_db processRequest:aRequest];
    } @catch (NSException *exception) {
        results = nil;
    }
    [_dbLocker unlock];
    return results;
}

@end
