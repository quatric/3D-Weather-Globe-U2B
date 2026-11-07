#import "WeatherPrintingData.h"

// Lays the weather report out over as many pages of the given size as it needs:
// general info, current conditions, then the extended forecast and its seven days.
@implementation WeatherPrintingData

- (id)pageAtIndex:(NSInteger)aIndex
{
    if (aIndex >= 0 && (NSUInteger)aIndex < [_pages count])
        return [_pages objectAtIndex:aIndex];
    return nil;
}

- (NSInteger)pagesCountForPageSize:(NSSize)aSize
{
    if (!NSEqualSizes(_currentPageSize, aSize)) {
        _currentPagesCount = 0;
        _currentPageSize = aSize;
        [_pages removeAllObjects];
        NSRect rest = [self _restRectAfterAddingSubview:_generalInfoView
                                                 toRect:NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, aSize.width, aSize.height)];
        rest = [self _restRectAfterAddingSubview:_currentConditionsView toRect:rest];
        [self _addExtendedForecastToRect:rest];
    }
    return _currentPagesCount;
}

- (CGFloat)additionalScaleForPageSize:(NSSize)aSize
{
    NSRect frame = [_generalInfoView frame];
    float scale = 1.0f, inverse = 1.0f;
    if (aSize.width < NSWidth(frame)) {
        scale = aSize.width / NSWidth(frame);
        inverse = 1.0f / scale;
    }
    [_summary scaleUnitSquareToSize:NSMakeSize(inverse, inverse)];
    [_windDirection scaleUnitSquareToSize:NSMakeSize(inverse, inverse)];
    NSUInteger count = [_efOneDayControllers count], i;
    for (i = 0; i < count; i++)
        [[_efOneDayControllers objectAtIndex:i] setScaleCoef:inverse];
    return scale;
}

- (void)setValuesFrom:(id)aFrom
{
    [_cityName setStringValue:[aFrom ownName]];
    NSString *region = [aFrom regionName];
    [_region setStringValue:region ? region : @""];
    [_coordinates setStringValue:[NSString shortGeoCoordinatesDescription:[aFrom coordinates]]];
    NSCalendarDate *date = [NSCalendarDate calendarDate];
    [date setTimeZone:[aFrom timeZone]];
    [_dateTime setStringValue:[date descriptionDateTime]];
    [self _setCurrentConditions:[aFrom dictionaryForReport:0]];
    NSArray *forecasts = [[aFrom dictionaryForReport:2] objectForKey:@"SEVEN_FORECASTS"];
    NSUInteger count = [forecasts count], i;
    for (i = 0; i < count; i++)
        [[_efOneDayControllers objectAtIndex:i] setValues:[forecasts objectAtIndex:i]];
}

- (NSView *)_addPage
{
    NSView *page = [[NSView new] autorelease];
    [page setFrameSize:_currentPageSize];
    [_pages addObject:page];
    _currentPagesCount++;
    return page;
}

- (void)_addExtendedForecastToRect:(NSRect)aRect
{
    NSRect frame = [_extendedForecastView frame];
    NSRect dayFrame = [[[_efOneDayControllers objectAtIndex:0] dataView] frame];
    CGFloat needed = NSHeight(frame) + NSHeight(dayFrame);
    if (needed > _currentPageSize.height)
        return;
    NSView *page = [_pages lastObject];
    if (NSHeight(aRect) < needed) {
        page = [self _addPage];
        aRect = [page frame];
    }
    frame.origin.x = MAX(0.0, roundf((NSWidth(aRect) - NSWidth(frame)) * 0.5f) + NSMinX(aRect));
    frame.origin.y = NSHeight(aRect) + NSMinY(aRect) - NSHeight(frame);
    [_extendedForecastView setFrame:frame];
    [page addSubview:_extendedForecastView];
    [self _addWeekdaysViewsFromIndex:0
                              toRect:NSMakeRect(NSMinX(aRect), NSMinY(aRect), NSWidth(aRect), NSHeight(aRect) - NSHeight(frame))];
}

// Days go in rows of as many as fit; the first in each row also carries the help labels.
- (void)_addWeekdaysViewsFromIndex:(NSInteger)aIndex toRect:(NSRect)aRect
{
    if (aIndex < 0 || (NSUInteger)aIndex >= [_efOneDayControllers count])
        return;
    NSView *page = [_pages lastObject];
    EFOneDayController *first = [_efOneDayControllers objectAtIndex:0];
    NSRect dayFrame = [[first dataView] frame];
    NSRect helpFrame = [[first helpTextView] frame];
    float columnWidth = NSWidth(dayFrame) + 8.0f;
    int columns = (int)((NSWidth(aRect) - NSWidth(helpFrame)) / columnWidth);
    if (columns < 1)
        columns = 1;
    int left = (int)(roundf(((NSWidth(aRect) - NSWidth(helpFrame)) - columns * columnWidth) * 0.5f) + NSMinX(aRect));
    if (left < 0)
        left = 0;
    int slot;
    for (slot = 0; slot != 7 && (NSUInteger)aIndex < [_efOneDayControllers count]; slot++, aIndex++) {
        EFOneDayController *day = [_efOneDayControllers objectAtIndex:aIndex];
        NSView *dataView = [day dataView];
        NSView *helpView = [day helpTextView];
        float x = (float)(slot % columns) * columnWidth + (float)(int)(left + NSWidth(helpFrame) + 8.0f);
        float y = (NSHeight(aRect) - (float)(slot / columns) * (NSHeight(dayFrame) + 2.0f)) - NSHeight(dayFrame);
        if (y < 0.0f) {
            page = [self _addPage];
            [self _addWeekdaysViewsFromIndex:aIndex toRect:[page frame]];
            return;
        }
        [page addSubview:dataView];
        if (slot % columns == 0) {
            [helpView setFrameOrigin:NSMakePoint(x - NSWidth(helpFrame) - 8.0f, y)];
            [page addSubview:helpView];
        } else if ([helpView superview] != nil) {
            [helpView removeFromSuperview];
        }
        [dataView setFrameOrigin:NSMakePoint(x, y)];
    }
}

- (NSRect)_restRectAfterAddingSubview:(id)aSubview toRect:(NSRect)aRect
{
    NSRect frame = [aSubview frame];
    NSView *page = [_pages lastObject];
    if (page == nil || NSHeight(aRect) < NSHeight(frame)) {
        page = [self _addPage];
        aRect = [page frame];
    }
    frame.origin.x = MAX(0.0, NSMinX(aRect) + roundf((NSWidth(aRect) - NSWidth(frame)) * 0.5f));
    frame.origin.y = NSMinY(aRect) + NSHeight(aRect) - NSHeight(frame);
    [aSubview setFrame:frame];
    [page addSubview:aSubview];
    aRect.size.height -= NSHeight(frame) + 8.0;
    return aRect;
}

- (void)_setAstronomyForecast:(id)aForecast
{
    NSString *format = [Preferences uses24HourClock] ? @"%H:%M" : @"%I:%M %p";
    NSString *keys[4] = { @"SUNRISE", @"SUNSET", @"MOONRISE", @"MOONSET" };
    NSTextField *fields[4] = { _sunrise, _sunset, _moonrise, _moonset };
    int i;
    for (i = 0; i < 4; i++) {
        NSString *value = [aForecast objectForKey:keys[i]];
        NSString *text = @"";
        if (value != nil)
            text = [[NSCalendarDate dateWithString:value calendarFormat:@"%I:%M%p"] descriptionWithCalendarFormat:format];
        [fields[i] setStringValue:text ? text : @""];
    }
}

- (void)_setCurrentConditions:(id)aConditions
{
    NSString *value = [aConditions temperatureForKey:@"COMFORT_LEVEL"];
    [_comfortLevel setStringValue:value ? value : @""];
    value = [aConditions speedForKey:@"WIND_SPEED"];
    [_windSpeed setStringValue:value ? value : @""];
    value = [aConditions percentsForKey:@"HUMIDITY"];
    [_humidity setStringValue:value ? value : @""];
    [_summary setImage:[aConditions weatherImageForKey:@"SUMMARY_CODE"]];
    [_windDirection setImage:[aConditions windImageForKey:@"WIND_DIR"]];
    value = [aConditions temperatureForKey:@"TEMPERATURE"];
    [_temperature setStringValue:value ? value : @""];
    value = [aConditions distanceForKey:@"VISIBILITY"];
    [_visibility setStringValue:value ? value : @""];
    value = [aConditions temperatureForKey:@"DEW_POINT"];
    [_dewPoint setStringValue:value ? value : @""];
    value = [aConditions pressureForKey:@"BAROMETRIC_PRESSURE"];
    [_pressure setStringValue:value ? value : @""];
}

- (void)dealloc
{
    [_generalInfoView release];
    [_astronomyForecastView release];
    [_currentConditionsView release];
    [_extendedForecastView release];
    [_pages release];
    [_efOneDayControllers release];
    [super dealloc];
}

- (void)awakeFromNib
{
    NSMutableArray *controllers = [NSMutableArray arrayWithCapacity:7];
    int i;
    for (i = 0; i < 7; i++)
        [controllers addObject:[[EFOneDayController new] autorelease]];
    _efOneDayControllers = [[NSArray alloc] initWithArray:controllers];
    _pages = [NSMutableArray new];
    _currentPageSize = NSZeroSize;
    _currentPagesCount = 0;
}

@end
