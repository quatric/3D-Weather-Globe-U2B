#import "YACityEntry.h"

@implementation YACityEntry

+ (id)entryWithDictionaryRep:(id)aRep
{
    if (aRep == nil)
        return nil;
    if ([aRep objectForKey:kAppleStoreListEntryAddress] != nil)
        return [AppleStoreEntry entryWithDictionaryRep:aRep];

    NSString *uid = [aRep objectForKey:kCityEntryUID];
    if (uid != nil) {
        if ([uid length] == 10) {
            id entry = [[AtlasDatabase database] dbEntryWithUID:uid];
            if (entry != nil)
                return entry;
        }
        if ([uid length] == 10)
            NSLog(@"Broken DB city entry record(%@); probably cities DB was changed.", [aRep objectForKey:kCityEntryName]);
    }
    float lat = [[aRep objectForKey:kCityEntryLat] floatValue];
    float lon = [[aRep objectForKey:kCityEntryLong] floatValue];
    return [[[GeoLocCityEntry alloc] initWithGeoPoint:NSMakePoint(lon, lat)
                                         shortCaption:[aRep objectForKey:kCityEntryName]
                                                  uid:uid] autorelease];
}

+ (id)entryWithGeoPoint:(NSPoint)aPoint
{
    return [[[GeoLocCityEntry alloc] initWithGeoPoint:aPoint] autorelease];
}

+ (id)entryWithGeoObjectDictionary:(id)aDictionary
{
    return [[[DBCityEntry alloc] initWithGeoObjectDictionary:aDictionary] autorelease];
}

- (void)setCoordinates:(NSPoint)aCoordinates
{
}

- (void)setShortCaption:(id)aCaption
{
}

- (id)wrapperWithRepresentationOfType:(id)aType createIfNeeded:(BOOL)aNeeded
{
    id wrapper = [_BLOBwrappers objectForKey:aType];
    if (wrapper == nil && aNeeded) {
        wrapper = [BLOBWrapper wrapperForObjectWithUID:[self uid] representationType:aType];
        if (wrapper != nil) {
            if (_BLOBwrappers == nil)
                _BLOBwrappers = [NSMutableDictionary new];
            [_BLOBwrappers setObject:wrapper forKey:aType];
        }
    }
    return wrapper;
}

- (NSInteger)customWeatherID
{
    return 0;
}

- (CGFloat)population
{
    return 0.0;
}

- (id)alternativeNames
{
    return nil;
}

- (id)countryName
{
    return nil;
}

- (id)stateName
{
    return nil;
}

- (id)countyName
{
    return nil;
}

- (id)ownType
{
    return nil;
}

- (NSInteger)currentGMTOffset
{
    return 0;
}

- (id)uid
{
    return nil;
}

- (id)timeZone
{
    return nil;
}

- (id)shortCaption
{
    return nil;
}

- (id)regionName
{
    return nil;
}

- (id)ownName
{
    return nil;
}

- (CGFloat)distanceToEntry:(id)aEntry
{
    return _distanceOnEarthFromEarthVecs((const SMK_GL_Vec3 *)&_earthVec,
                                         (const SMK_GL_Vec3 *)[(YACityEntry *)aEntry vectorFromEarthCenter]);
}

- (struct WeatherGlobe_anon2 *)vectorFromEarthCenter
{
    return (struct WeatherGlobe_anon2 *)&_earthVec;
}

- (struct WeatherGlobe_anon7 *)cityMarkerColor
{
    if (!_colorIsValid) {
        long b = random();
        long g = random();
        long r = random();
        _color.r = (float)r * 4.656613e-10f + 0.0f;
        _color.g = (float)g * 4.656613e-10f + 0.0f;
        _color.b = (float)b * 4.656613e-10f + 0.0f;
        _color.a = 1.0f;
        vec3_normalize_e((SMK_GL_Vec3 *)&_color);
        _color.r *= 0.99f;
        _color.g *= 0.99f;
        _color.b *= 0.99f;
        _color.a = 1.0f;
        _colorIsValid = YES;
    }
    return (struct WeatherGlobe_anon7 *)&_color;
}

- (NSPoint)coordinates
{
    return _geoPoint;
}

- (id)entryDictionary
{
    NSPoint point = [self coordinates];
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [self shortCaption], kCityEntryName,
        [NSNumber numberWithFloat:point.x], kCityEntryLong,
        [NSNumber numberWithFloat:point.y], kCityEntryLat,
        [self uid], kCityEntryUID,
        nil];
}

- (BOOL)isPermanent
{
    return NO;
}

- (id)dictionaryForReport:(NSInteger)aReport
{
    return [[self _createWrapperIfNeeded] dictionaryForReport:aReport];
}

- (void)manualUpdateOfScheduledReports
{
    [_onlineWrapper manualUpdateOfScheduledReports];
}

- (void)unscheduleAllReports
{
    [_onlineWrapper unscheduleReports:0x1f];
}

- (void)unscheduleReports:(NSUInteger)aReports
{
    [_onlineWrapper unscheduleReports:aReports];
}

- (void)scheduleReports:(NSUInteger)aReports
{
    [[self _createWrapperIfNeeded] scheduleReports:aReports];
}

- (void)postSingleDownloadTaskForReports:(NSUInteger)aReports
{
    [[self _createWrapperIfNeeded] singleUpdateTaskForReports:aReports];
}

- (id)onlineWrapper
{
    return _onlineWrapper;
}

- (void)_wrapperDataWasExpired:(id)aExpired
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kCityEntryWasExpiredViaOnlineNotification
                                                        object:self userInfo:[aExpired userInfo]];
}

- (void)_wrapperDataWasUpdated:(id)aUpdated
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kCityEntryWasUpdatedViaOnlineNotification
                                                        object:self userInfo:[aUpdated userInfo]];
}

- (id)_createWrapperIfNeeded
{
    if (_onlineWrapper == nil) {
        _onlineWrapper = [[CWOnlineCityData alloc] initWithCityEntry:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_wrapperDataWasUpdated:)
                                                     name:kOnlineDataWasUpdatedNotification object:_onlineWrapper];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_wrapperDataWasExpired:)
                                                     name:kOnlineDataWasExpiredNotification object:_onlineWrapper];
    }
    return _onlineWrapper;
}

- (id)description
{
    return [NSString stringWithFormat:@"%@ - %@", [super description], [self shortCaption]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_onlineWrapper invalidate];
    _onlineWrapper = nil;
    [_BLOBwrappers release];
    _BLOBwrappers = nil;
    [super dealloc];
}

@end

@implementation DBCityEntry

- (NSInteger)customWeatherID
{
    return _cw_id;
}

- (CGFloat)population
{
    return _population;
}

- (id)alternativeNames
{
    if (_altNamesArray == nil && _altNamesStr != nil) {
        NSArray *names = [_altNamesStr componentsSeparatedByString:@";"];
        _altNamesArray = [[names subarrayWithRange:NSMakeRange(1, [names count] - 1)] retain];
    }
    return _altNamesArray;
}

- (id)countryName
{
    if (_countryName == nil && _country_uid != nil)
        _countryName = [[[[AtlasDatabase database] dbEntryWithUID:_country_uid] ownName] copy];
    return _countryName;
}

- (id)stateName
{
    if (_stateName == nil && _state_uid != nil)
        _stateName = [[[[AtlasDatabase database] dbEntryWithUID:_state_uid] ownName] copy];
    return _stateName;
}

- (id)countyName
{
    if (_countyName == nil && _county_uid != nil)
        _countyName = [[[[AtlasDatabase database] dbEntryWithUID:_county_uid] ownName] copy];
    return _countyName;
}

- (id)ownType
{
    return _ownType;
}

- (NSInteger)currentGMTOffset
{
    return [[self timeZone] secondsFromGMT];
}

- (id)uid
{
    return _uid;
}

- (id)timeZone
{
    if (_timeZone == nil && _timeZoneName != nil) {
        _timeZone = [[NSTimeZone timeZoneWithName:_timeZoneName] retain];
        if (_timeZone == nil)
            _timeZone = [[NSTimeZone timeZoneForSecondsFromGMT:(NSInteger)([_timeZoneName floatValue] * 3600.0f)] retain];
    }
    return _timeZone;
}

- (id)shortCaption
{
    if (_shortCaption == nil) {
        NSString *region = [self regionName];
        NSString *name = [self ownName];
        if (region == nil)
            _shortCaption = [_ownName retain];
        else
            _shortCaption = [[NSString alloc] initWithFormat:@"%@ (%@)", name, region];
    }
    return _shortCaption;
}

- (id)regionName
{
    if (_regionName == nil) {
        NSString *country = [self countryName];
        NSString *state = [self stateName];
        NSString *county = [self countyName];
        if (country != nil) {
            if (state != nil)
                _regionName = [[NSString alloc] initWithFormat:@"%@, %@", state, country];
            else
                _regionName = [country copy];
        } else if (state != nil || county != nil) {
            _regionName = [[NSString alloc] initWithFormat:@"%@ county", county];
        }
    }
    return _regionName;
}

- (id)ownName
{
    return _ownName;
}

- (BOOL)isPermanent
{
    return YES;
}

- (void)dealloc
{
    [_timeZoneName release];
    [_ownName release];
    [_regionName release];
    [_timeZone release];
    [_shortCaption release];
    [_uid release];
    [_countyName release];
    [_stateName release];
    [_countryName release];
    [_ownType release];
    [_country_uid release];
    [_state_uid release];
    [_county_uid release];
    [_altNamesStr release];
    [_altNamesArray release];
    [super dealloc];
}

- (id)initWithGeoObjectDictionary:(id)aDictionary
{
    self = [super init];
    if (self != nil) {
        _ownName = [[aDictionary objectForKey:kColumnNameName] copy];
        _uid = [[aDictionary objectForKey:kColumnNameUID] copy];
        if (_uid == nil || _ownName == nil)
            NSLog(@"Required info is missing on creating DB entry.");
        _country_uid = [[aDictionary objectForKey:kColumnNameHostCountryUID] copy];
        _state_uid = [[aDictionary objectForKey:kColumnNameHostStateUID] copy];
        _county_uid = [[aDictionary objectForKey:kColumnNameHostCountyUID] copy];
        _altNamesStr = [[aDictionary objectForKey:kColumnNameAltNames] copy];
        id population = [aDictionary objectForKey:kColumnNamePopulation];
        _population = population != nil ? [population floatValue] : -1.0f;
        id cwid = [aDictionary objectForKey:kColumnNameCWID];
        _cw_id = cwid != nil ? [cwid intValue] : -1;
        _ownType = [[aDictionary objectForKey:kColumnNameType] copy];
        _timeZoneName = [[aDictionary objectForKey:kColumnNameHostTimeZone] copy];
        float lat = [[aDictionary objectForKey:kColumnNameLat] floatValue];
        float lon = [[aDictionary objectForKey:kColumnNameLong] floatValue];
        _geoPoint = NSMakePoint(lon, lat);
        SMK_GL_Vec3 vec = _earthVecFromGeoPoint(_geoPoint);
        _earthVec.x = vec.x;
        _earthVec.y = vec.y;
        _earthVec.z = vec.z;
    }
    return self;
}

@end
