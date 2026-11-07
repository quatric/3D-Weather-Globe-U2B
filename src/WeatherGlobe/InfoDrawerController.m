#import "InfoDrawerController.h"

@implementation InfoDrawerController

- (id)drawInfo
{
    if (_drawInfo == nil)
        [self _reconstructData];
    return _drawInfo;
}

- (void)_entriesWereChanged:(id)aChanged
{
    [self _unscheduleWeather];
    [_entries release];
    _entries = [[self _getEntries] retain];
    [self _scheduleWeather];
    [self _reconstructData];
}

- (void)_weatherReportsWereChanged:(id)aChanged
{
    if ([[[aChanged userInfo] objectForKey:kReportIDKey] unsignedIntValue] == 0)
        [self _reconstructData];
}

- (void)_unitsOfMeasureWereChanged:(id)aChanged
{
    [self _reconstructData];
}

- (void)_showWeatherOnMapStateWasChanged:(id)aChanged
{
    if ([Preferences doShowWeatherOnMap] && [Preferences usesInternet])
        [self _enableWeather];
    else
        [self _disableWeather];
}

- (void)dealloc
{
    [self _disableWeather];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_drawInfo release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_showWeatherOnMapStateWasChanged:) name:kShowWeatherOnMapStateWasChanged object:nil];
        [center addObserver:self selector:@selector(_showWeatherOnMapStateWasChanged:) name:kInternetStateWasChanged object:nil];
        if ([Preferences doShowWeatherOnMap] && [Preferences usesInternet])
            [self _enableWeather];
    }
    return self;
}

- (void)_disableWeather
{
    if (_entries == nil)
        return;
    [self _unscheduleWeather];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:kUnitsOfMeasureWereChanged object:nil];
    [center removeObserver:self name:kCitiesListWasChanged object:nil];
    [_entries release];
    _entries = nil;
    [self _reconstructData];
}

- (void)_enableWeather
{
    if (_entries != nil)
        return;
    _entries = [[self _getEntries] retain];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];
    [center addObserver:self selector:@selector(_entriesWereChanged:) name:kCitiesListWasChanged object:nil];
    [self _scheduleWeather];
    [self _reconstructData];
}

- (id)_getEntries
{
    AtlasDatabase *database = [AtlasDatabase database];
    NSArray *list = [Preferences citiesList];
    NSInteger count = [list count];
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++)
        [entries addObject:[database dbEntryWithUID:[list objectAtIndex:i]]];
    return entries;
}

- (void)_unscheduleWeather
{
    if (!_entriesScheduled)
        return;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSInteger count = [_entries count];
    for (NSInteger i = 0; i < count; i++) {
        id entry = [_entries objectAtIndex:i];
        [center removeObserver:self name:kCityEntryWasUpdatedViaOnlineNotification object:entry];
        [entry unscheduleReports:1];
    }
    _entriesScheduled = NO;
}

- (void)_scheduleWeather
{
    if (_entriesScheduled)
        return;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSInteger count = [_entries count];
    for (NSInteger i = 0; i < count; i++) {
        id entry = [_entries objectAtIndex:i];
        [entry scheduleReports:1];
        [center addObserver:self selector:@selector(_weatherReportsWereChanged:) name:kCityEntryWasUpdatedViaOnlineNotification object:entry];
    }
    _entriesScheduled = YES;
}

- (void)_reconstructData
{
    NSInteger count = [_entries count];
    NSUInteger length = count * sizeof(InfoDrawerRecord);
    if (_drawInfo == nil)
        _drawInfo = [[NSMutableData alloc] initWithLength:length];
    else if ([_drawInfo length] < length)
        [_drawInfo setLength:length];
    InfoDrawerRecord *record = [_drawInfo mutableBytes];
    NSUInteger used = 0;
    for (NSInteger i = 0; i < count; i++) {
        id entry = [_entries objectAtIndex:i];
        NSDictionary *report = [entry dictionaryForReport:0];
        NSInteger imageIndex = [report weatherImageIndexForKey:@"SUMMARY_CODE"];
        NSString *temperature = [report temperatureForKey:@"TEMPERATURE"];
        if (imageIndex == 0 && temperature == nil)
            continue;
        if (temperature == nil)
            temperature = @"";
        NSPoint coordinates = [entry coordinates];
        record->x = (float)coordinates.x;
        record->y = (float)coordinates.y;
        record->imageIndex = (int)imageIndex;
        strlcpy(record->temperature, [temperature UTF8String] ?: "", sizeof(record->temperature));
        strlcpy(record->name, [[entry ownName] UTF8String] ?: "", sizeof(record->name));
        record++;
        used++;
    }
    if ([_drawInfo length] != used * sizeof(InfoDrawerRecord))
        [_drawInfo setLength:used * sizeof(InfoDrawerRecord)];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDrawDataWasChanged object:self userInfo:nil];
}

@end
