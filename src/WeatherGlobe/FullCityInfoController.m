#import "FullCityInfoController.h"

// The Details panel for one city: general info, current conditions, the
// 7-day forecast (one day at a time) and astronomy, each section
// collapsible with a disclosure button. While it's open, the city's
// reports are kept up to date.

static FullCityInfoController *_sFullCityInfoController = nil;
static YACityEntry *_sWaitingEntry = nil;
static NSTimer *_sRefreshTimer = nil;

// image views leave the panel while they have no image
static void _showImage(NSImageView *aView, NSImage *aImage, NSView *aContainer)
{
    [aView setImage:aImage];
    if ([aView image] == nil)
        [aView removeFromSuperview];
    else if ([aView superview] == nil)
        [aContainer addSubview:aView];
}

static void _setString(NSTextField *aField, NSString *aString)
{
    [aField setStringValue:aString != nil ? aString : @""];
}

@implementation FullCityInfoController

+ (void)doPrint:(id)aPrint
{
    [[self sharedInstance] doPrint:aPrint];
}

// selecting cities in quick succession only shows the last one, after 0.5 s
+ (void)refreshWithCityEntry:(id)aEntry
{
    if (aEntry == nil)
        return;
    FullCityInfoController *controller = [self sharedInstance];
    [_sWaitingEntry release];
    _sWaitingEntry = [aEntry retain];
    [_sRefreshTimer invalidate];
    _sRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:controller selector:@selector(_timeForRefresh:) userInfo:nil repeats:NO];
}

+ (void)showWithCityEntry:(id)aEntry
{
    if (aEntry != nil)
        [[self sharedInstance] _showWithCityEntry:aEntry];
}

+ (BOOL)isVisible
{
    return [[self sharedInstance] isVisible];
}

+ (id)sharedInstance
{
    if (_sFullCityInfoController == nil)
        _sFullCityInfoController = [FullCityInfoController new];
    if (_sFullCityInfoController == (id)-1)
        return nil;
    return _sFullCityInfoController;
}

- (void)runPageLayout:(id)aLayout
{
    [[NSPageLayout pageLayout] runModal];
}

- (void)doPrint:(id)aPrint
{
    [WeatherPrintController printCities:[NSArray arrayWithObject:_entry]];
}

- (void)manualUpdate:(id)aUpdate
{
    [CWManager resetWeatherInternetState];
    [_entry manualUpdateOfScheduledReports];
}

- (void)weekdayAction:(id)aAction
{
    [self _refresh];
}

// Grows or shrinks the panel by the section's height, keeping its top
// edge; the autoresizing masks make only that section change size.
- (void)disclosureAction:(id)aAction
{
    NSInteger tag = [aAction tag];
    NSInteger state = [aAction state];
    float height;
    if (tag == 10) {
        height = _giHeight;
        [_giContainerView setAutoresizingMask:NSViewHeightSizable];
        [_separator2 setAutoresizingMask:NSViewMaxYMargin];
        [_ccContainerView setAutoresizingMask:NSViewMaxYMargin];
        [_separator3 setAutoresizingMask:NSViewMaxYMargin];
        [_efContainerView setAutoresizingMask:NSViewMaxYMargin];
    } else if (tag == 20) {
        height = _ccHeight;
        [_giContainerView setAutoresizingMask:NSViewMinYMargin];
        [_separator2 setAutoresizingMask:NSViewMinYMargin];
        [_ccContainerView setAutoresizingMask:NSViewHeightSizable];
        [_separator3 setAutoresizingMask:NSViewMaxYMargin];
        [_efContainerView setAutoresizingMask:NSViewMaxYMargin];
    } else if (tag == 30) {
        height = _efHeight;
        [_giContainerView setAutoresizingMask:NSViewMinYMargin];
        [_separator2 setAutoresizingMask:NSViewMinYMargin];
        [_ccContainerView setAutoresizingMask:NSViewMinYMargin];
        [_separator3 setAutoresizingMask:NSViewMinYMargin];
        [_efContainerView setAutoresizingMask:NSViewHeightSizable];
    } else {
        height = 0.0f;
    }
    NSRect frame = [_panel frame];
    float newHeight = state ? (float)frame.size.height + height : (float)frame.size.height - height;
    frame.origin.y = (float)(int)((float)frame.size.height + (float)frame.origin.y) - newHeight;
    frame.size.height = newHeight;
    [_panel setFrame:frame display:YES animate:YES];
    [self _refreshToolTipRects];
}

- (void)_reportsWereChanged:(id)aChanged
{
    [self _refresh];
    [self _checkProgressIndicatorAnimation];
}

- (void)_acceptAdjustTime:(id)aTime
{
    [self _adjustTime];
}

- (void)_clocksMeasureWereChanged:(id)aChanged
{
    [self _adjustTime];
}

- (void)_unitsOfMeasureWereChanged:(id)aChanged
{
    [self _refresh];
}

- (void)_internetStateWasChanged:(id)aChanged
{
    [self _refresh];
    [self _checkInternet];
    [_manualUpdateButt setEnabled:_usesInternet];
    if (_usesInternet)
        [self _schedule];
    else
        [self _unschedule];
    [self _checkProgressIndicatorAnimation];
}

- (void)windowWillClose:(id)aClose
{
    [self _unschedule];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"FCIEntryChangedNotification" object:nil];
}

- (BOOL)isVisible
{
    return [_panel isVisible];
}

// the summary icons' tool tips describe the weather
- (id)view:(id)aView stringForToolTip:(NSInteger)aTip point:(NSPoint)aPoint userData:(void *)aData
{
    if (aTip == _ccSummaryToolTipTag)
        return [[_entry dictionaryForReport:0] weatherDescription];
    if (aTip != _efSummaryToolTipTag)
        return nil;
    NSArray *forecasts = [[_entry dictionaryForReport:2] objectForKey:@"SEVEN_FORECASTS"];
    return [[forecasts objectAtIndex:[_weekdays selectedSegment]] weatherDescription];
}

- (void)_timeForRefresh:(id)aRefresh
{
    _sRefreshTimer = nil;
    [self _refreshWithCityEntry:_sWaitingEntry];
    [_sWaitingEntry release];
    _sWaitingEntry = nil;
}

- (void)_showWithCityEntry:(id)aEntry
{
    [self _refreshWithCityEntry:aEntry];
    [NSApp activateIgnoringOtherApps:YES];
    if (![_panel isVisible]) {
        [_panel orderFront:self];
        [self _schedule];
    }
}

- (void)_refreshWithCityEntry:(id)aEntry
{
    [self _loadNibIfNeeded];
    if (_entry != aEntry) {
        [self _unschedule];
        [_entry release];
        _entry = [aEntry retain];
        [self _checkProgressIndicatorAnimation];
        [self _schedule];
    }
    [self _refresh];
}

- (void)_refresh
{
    NSString *details = [[NSBundle mainBundle] localizedStringForKey:@"Details" value:@"" table:nil];
    [_panel setTitle:[NSString stringWithFormat:@"%@ %@", [_entry ownName], details]];
    _setString(_cityName, [_entry ownName]);
    _setString(_region, [_entry regionName]);
    [_coordinates setStringValue:[NSString shortGeoCoordinatesDescription:[_entry coordinates]]];
    [self _adjustTime];
    [self _setCurrentConditions:[_entry dictionaryForReport:0]];
    NSDictionary *forecast = [_entry dictionaryForReport:2];
    if ([self _isExpandedForecastExpired]) {
        if ([_efExpiredText superview] == nil)
            [_efContainerView addSubview:_efExpiredText];
        NSString *key = [CWManager isWeatherInternetStateOK] ? @"Updating Weather" : @"Updating failed";
        [_efExpiredText setStringValue:[[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil]];
    } else {
        [_efExpiredText removeFromSuperview];
    }
    // one segment per day, labelled with its weekday
    NSArray *days = [forecast objectForKey:@"SEVEN_FORECASTS"];
    int count = (int)[days count];
    for (int i = 0; i < count; i++) {
        id dayOfWeek = [[days objectAtIndex:i] objectForKey:@"DAY_OF_WEEK"];
        NSString *label = dayOfWeek != nil ? [NSString weekdayAbbreviation:[dayOfWeek intValue] - 1] : @"";
        [_weekdays setLabel:label forSegment:i];
    }
    [_weekdays setNeedsDisplay:YES];
    [self _setExpandedForecast:[days objectAtIndex:[_weekdays selectedSegment]]];
}

- (void)_setExpandedForecast:(id)aForecast
{
    _setString(_efComfortLevel, [aForecast temperatureForKey:@"COMFORT_LEVEL"]);
    _setString(_efWindSpeed, [aForecast speedForKey:@"WIND_SPEED"]);
    _setString(_efHumidity, [aForecast percentsForKey:@"HUMIDITY"]);
    _showImage(_efSummary, [aForecast weatherImageForKey:@"SUMMARY_CODE"], _efContainerView);
    _showImage(_efWindDirection, [aForecast windImageForKey:@"WIND_DIR"], _efContainerView);
    _setString(_temperatureHigh, [aForecast temperatureForKey:@"TEMPERATURE_HIGH"]);
    _setString(_temperatureLow, [aForecast temperatureForKey:@"TEMPERATURE_LOW"]);
    _setString(_precipitation, [aForecast percentsForKey:@"PRECIPTATIONS_PROBABILITY"]);
    _setString(_ffDewPoint, [aForecast temperatureForKey:@"DEW_POINT"]);
    _setString(_uvIndex, [aForecast objectForKey:@"UV_TEXT"]);
}

- (void)_setCurrentConditions:(id)aConditions
{
    _setString(_ccComfortLevel, [aConditions temperatureForKey:@"COMFORT_LEVEL"]);
    _setString(_ccWindSpeed, [aConditions speedForKey:@"WIND_SPEED"]);
    _setString(_ccHumidity, [aConditions percentsForKey:@"HUMIDITY"]);
    _showImage(_ccSummary, [aConditions weatherImageForKey:@"SUMMARY_CODE"], _ccContainerView);
    _showImage(_ccWindDirection, [aConditions windImageForKey:@"WIND_DIR"], _ccContainerView);
    _setString(_temperature, [aConditions temperatureForKey:@"TEMPERATURE"]);
    _setString(_visibility, [aConditions distanceForKey:@"VISIBILITY"]);
    _setString(_ccDewPoint, [aConditions temperatureForKey:@"DEW_POINT"]);
    _setString(_pressure, [aConditions pressureForKey:@"BAROMETRIC_PRESSURE"]);
    if ([self _isCurrentConditionExpired]) {
        if ([_ccExpiredText superview] == nil)
            [_ccContainerView addSubview:_ccExpiredText];
        NSString *key = [CWManager isWeatherInternetStateOK] ? @"Updating Weather" : @"Updating failed";
        [_ccExpiredText setStringValue:[[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil]];
    } else {
        [_ccExpiredText removeFromSuperview];
    }
}

// the city's local date and time
- (void)_adjustTime
{
    NSCalendarDate *date = [NSCalendarDate calendarDate];
    [date setTimeZone:[_entry timeZone]];
    [_dateTime setStringValue:[date descriptionDateTime]];
}

- (void)_unschedule
{
    if (!_scheduled)
        return;
    [_entry unscheduleReports:5];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCityEntryWasUpdatedViaOnlineNotification object:_entry];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCityEntryWasExpiredViaOnlineNotification object:_entry];
    _scheduled = NO;
}

// current conditions and forecast reports (mask 1 | 4)
- (void)_schedule
{
    if (_scheduled || !_usesInternet || ![_panel isVisible])
        return;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reportsWereChanged:) name:kCityEntryWasUpdatedViaOnlineNotification object:_entry];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reportsWereChanged:) name:kCityEntryWasExpiredViaOnlineNotification object:_entry];
    [_entry scheduleReports:5];
    _scheduled = YES;
}

- (void)_checkProgressIndicatorAnimation
{
    if ([self _isWeatherExpired] && _usesInternet && [CWManager isWeatherInternetStateOK]) {
        if ([_progressIndicator superview] == nil)
            [[_panel contentView] addSubview:_progressIndicator];
        [_progressIndicator startAnimation:self];
        return;
    }
    [_progressIndicator stopAnimation:self];
    [_progressIndicator removeFromSuperview];
}

- (BOOL)_isWeatherExpired
{
    return [self _isCurrentConditionExpired] || [self _isExpandedForecastExpired];
}

// an open section with no data, or with expired data
- (BOOL)_isExpandedForecastExpired
{
    NSDictionary *report = [_entry dictionaryForReport:2];
    if ([_efDisclosure state] != NSControlStateValueOn)
        return NO;
    return report == nil || [[report objectForKey:@"DATA_EXPIRED"] intValue] != 0;
}

- (BOOL)_isCurrentConditionExpired
{
    NSDictionary *report = [_entry dictionaryForReport:0];
    if ([_ccDisclosure state] != NSControlStateValueOn)
        return NO;
    return report == nil || [[report objectForKey:@"DATA_EXPIRED"] intValue] != 0;
}

- (void)_loadNibIfNeeded
{
    if (_panel == nil)
        [NSBundle loadNibNamed:@"FullCityInfo" owner:self];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_ccExpiredText release];
    [_efExpiredText release];
    [_afExpiredText release];
    [_ccSummary release];
    [_ccWindDirection release];
    [_efSummary release];
    [_efWindDirection release];
    [_progressIndicator release];
    [_entry release];
    [super dealloc];
}

static void _setRoleDescription(NSControl *aControl, NSString *aKey)
{
    id cell = [aControl cell];
    if ([cell respondsToSelector:@selector(accessibilitySetOverrideValue:forAttribute:)])
        [cell accessibilitySetOverrideValue:[[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil] forAttribute:NSAccessibilityRoleDescriptionAttribute];
}

// Views that come and go are retained so they survive leaving the panel;
// each section's height (less its 15 point title) is what disclosure adds
// or removes.
- (void)awakeFromNib
{
    if (floor(NSAppKitVersionNumber) > 1038.0)
        [[_panel contentView] setWantsLayer:YES];
    [_progressIndicator setDisplayedWhenStopped:NO];
    _giHeight = (float)[_giContainerView frame].size.height - 15.0f;
    _ccHeight = (float)[_ccContainerView frame].size.height - 15.0f;
    _efHeight = (float)[_efContainerView frame].size.height - 15.0f;
    _afHeight = (float)[_afContainerView frame].size.height - 15.0f;
    _ccDisclosureState = (int)[_ccDisclosure state];
    _efDisclosureState = (int)[_efDisclosure state];
    _afDisclosureState = (int)[_afDisclosure state];
    [self _checkInternet];
    [_manualUpdateButt setEnabled:_usesInternet];
    [_ccWindDirection setToolTip:[[NSBundle mainBundle] localizedStringForKey:@"Wind direction" value:@"" table:nil]];
    [_efWindDirection setToolTip:[_ccWindDirection toolTip]];
    [self _refreshToolTipRects];
    NSString *updating = [[NSBundle mainBundle] localizedStringForKey:@"Updating Weather" value:@"" table:nil];
    [_ccExpiredText setStringValue:updating];
    [_efExpiredText setStringValue:updating];
    [_afExpiredText setStringValue:updating];
    [_ccExpiredText retain];
    [_efExpiredText retain];
    [_afExpiredText retain];
    [_ccSummary retain];
    [_ccWindDirection retain];
    [_efSummary retain];
    [_efWindDirection retain];
    [_progressIndicator retain];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_acceptAdjustTime:) name:@"AdjustTimeNotification" object:nil];
    [center addObserver:self selector:@selector(_clocksMeasureWereChanged:) name:kClockFormatWasChanged object:nil];
    [center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];
    [center addObserver:self selector:@selector(_internetStateWasChanged:) name:kInternetStateWasChanged object:nil];
    [center addObserver:self selector:@selector(_reportsWereChanged:) name:kWeatherInternetStateWasChangedNotification object:nil];
    _setRoleDescription(_ccWindDirection, @"Wind Icon");
    _setRoleDescription(_efWindDirection, @"Wind Icon");
    _setRoleDescription(_ccSummary, @"Weather Icon");
    _setRoleDescription(_efSummary, @"Weather Icon");
}

- (void)_refreshToolTipRects
{
    [_ccSummary removeAllToolTips];
    _ccSummaryToolTipTag = (int)[_ccSummary addToolTipRect:[_ccSummary bounds] owner:self userData:NULL];
    [_efSummary removeAllToolTips];
    _efSummaryToolTipTag = (int)[_efSummary addToolTipRect:[_efSummary bounds] owner:self userData:NULL];
}

// Without internet the weather sections are closed and disabled; with it
// they reopen if they were open before.
- (void)_checkInternet
{
    _usesInternet = [Preferences usesInternet];
    if ([Preferences internetState] == 0) {
        _ccDisclosureState = (int)[_ccDisclosure state];
        if (_ccDisclosureState == NSControlStateValueOn)
            [_ccDisclosure performClick:self];
        [_ccDisclosure setEnabled:NO];
        _efDisclosureState = (int)[_efDisclosure state];
        if (_efDisclosureState == NSControlStateValueOn)
            [_efDisclosure performClick:self];
        [_efDisclosure setEnabled:NO];
    } else {
        [_ccDisclosure setEnabled:YES];
        if ([_ccDisclosure state] == NSControlStateValueOff && _ccDisclosureState == NSControlStateValueOn)
            [_ccDisclosure performClick:self];
        [_efDisclosure setEnabled:YES];
        if ([_efDisclosure state] == NSControlStateValueOff && _efDisclosureState == NSControlStateValueOn)
            [_efDisclosure performClick:self];
    }
}

@end

@implementation EFBox

- (void)drawRect:(NSRect)aRect
{
    [[NSColor whiteColor] set];
    NSRectFill(aRect);
    [super drawRect:aRect];
}

@end
