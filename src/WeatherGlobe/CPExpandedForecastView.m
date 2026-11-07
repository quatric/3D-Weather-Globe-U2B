#import "CPExpandedForecastView.h"

// One row per forecast day, latest at the bottom: the date right-aligned
// left of the middle, then high / low temperatures and the summary icon.

static const float _kIconScale = 1.5f;
static NSMutableDictionary *_sDefaultAttrs = nil;
static NSMutableDictionary *_sHighTempAttrs = nil;
static NSMutableDictionary *_sLowTempAttrs = nil;
static NSMutableDictionary *_sDateAttrs = nil;
static NSString *_kShortTemperatureFormat = nil;
static NSColor *__evenBarColor = nil;
static NSInteger __daysCount = 0;
static BOOL __enabled = NO;
static NSSize __sizeForBestFit;
static float __rowHeight;
static NSRect __weekdayRect;
static NSRect __summaryIconRect;
static NSRect __highTempRect;
static NSRect __lowTempRect;
static NSRect __separatorRect;
static NSRect __rectForSuperView;
static NSRect __realImageRect;

static NSFont *_paletteFont(NSString *aName)
{
    float size = [Preferences paletteFontSize];
    NSFont *font = [NSFont fontWithName:aName size:size];
    return font != nil ? font : [NSFont systemFontOfSize:size];
}

// the date of the first forecast day: the download day moved on to the
// weekday the report gives
static NSCalendarDate *_firstForecastDate(NSDictionary *aReport, NSArray *aForecasts)
{
    NSCalendarDate *date = [NSCalendarDate calendarDate];
    id downloadDate = [aReport objectForKey:@"DOWNLOAD_DATE"];
    if (downloadDate == nil)
        return date;
    date = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:[downloadDate doubleValue]];
    int dayOfWeek = [[[aForecasts objectAtIndex:0] objectForKey:@"DAY_OF_WEEK"] intValue];
    if ((unsigned)(dayOfWeek - 1) < 7) {
        while ([date dayOfWeek] != dayOfWeek - 1)
            date = [date dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
    }
    return date;
}

@implementation CPExpandedForecastView

+ (void)_acceptAdjustFontSize:(id)aSize
{
    NSFont *font = _paletteFont(@"HelveticaNeue");
    [_sDefaultAttrs setObject:font forKey:NSFontAttributeName];
    [_sDateAttrs setObject:font forKey:NSFontAttributeName];
    NSFont *boldFont = _paletteFont(@"HelveticaNeue-Bold");
    [_sHighTempAttrs setObject:boldFont forKey:NSFontAttributeName];
    [_sLowTempAttrs setObject:boldFont forKey:NSFontAttributeName];
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ExpandedForecastNeedAdjustSizeNotification" object:self userInfo:nil];
}

// the menu item's tag is the number of days to show
+ (void)_enabledStateMenu:(id)aMenu
{
    [Preferences setExpandedForecastDaysCount:[aMenu tag]];
    [self _calculateSizeForBestFit];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"ExpandedForecastMenuNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
    [center postNotificationName:@"ExpandedForecastNeedAdjustSizeNotification" object:self userInfo:nil];
}

+ (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(_enabledStateMenu:)) {
        [aItem setState:[aItem tag] == __daysCount ? NSControlStateValueOn : NSControlStateValueOff];
        if ([Preferences internetState] == 0)
            return NO;
    }
    return [Preferences doShowWeatherOnStartup];
}

+ (id)_menuItemsDescriptors
{
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"Forecast" value:@"" table:nil];
    NSArray *keys = [NSArray arrayWithObjects:@"TITLE", @"SUBMENU", nil];
    NSArray *values = [NSArray arrayWithObjects:title, [self _submenu], nil];
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:values forKeys:keys], nil];
}

+ (id)_submenu
{
    NSMenu *menu = [[NSMenu new] autorelease];
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *format = [bundle localizedStringForKey:@"DaysCountFormat" value:@"" table:nil];
    [menu addItem:[self _menuItemWithTitle:[bundle localizedStringForKey:@"None" value:@"" table:nil] selector:@selector(_enabledStateMenu:) tag:0]];
    [menu addItem:[NSMenuItem separatorItem]];
    for (int days = 3; days <= 7; days += 2)
        [menu addItem:[self _menuItemWithTitle:[NSString stringWithFormat:format, days] selector:@selector(_enabledStateMenu:) tag:days]];
    return menu;
}

+ (id)_menuItemWithTitle:(id)aTitle selector:(SEL)aSelector tag:(NSInteger)aTag
{
    NSMenuItem *item = [[NSMenuItem new] autorelease];
    [item setTitle:aTitle];
    [item setTarget:self];
    [item setAction:aSelector];
    [item setTag:aTag];
    return item;
}

+ (void)initialize
{
    if (_sDefaultAttrs != nil)
        return;
    _sDefaultAttrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSFont systemFontOfSize:[Preferences paletteFontSize]], NSFontAttributeName, nil];
    _sHighTempAttrs = [[NSMutableDictionary alloc] initWithDictionary:_sDefaultAttrs];
    _sLowTempAttrs = [[NSMutableDictionary alloc] initWithDictionary:_sDefaultAttrs];
    [_sDefaultAttrs setObject:[NSColor colorWithCalibratedWhite:0.0 alpha:0.7] forKey:NSForegroundColorAttributeName];
    [_sDefaultAttrs setObject:_paletteFont(@"HelveticaNeue") forKey:NSFontAttributeName];
    NSFont *boldFont = _paletteFont(@"HelveticaNeue-Bold");
    [_sHighTempAttrs setObject:boldFont forKey:NSFontAttributeName];
    [_sLowTempAttrs setObject:boldFont forKey:NSFontAttributeName];
    [_sHighTempAttrs setObject:[NSColor colorWithCalibratedRed:0.51 green:0.09 blue:0.09 alpha:1.0] forKey:NSForegroundColorAttributeName];
    [_sLowTempAttrs setObject:[NSColor colorWithCalibratedRed:0.09 green:0.24 blue:0.51 alpha:1.0] forKey:NSForegroundColorAttributeName];
    _sDateAttrs = [[NSMutableDictionary alloc] initWithDictionary:_sDefaultAttrs];
    NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setAlignment:NSTextAlignmentRight];
    [_sDateAttrs setObject:style forKey:NSParagraphStyleAttributeName];
    __realImageRect.origin = NSZeroPoint;
    __realImageRect.size = [[[CWManager weatherImagesForIconAtIndex:1] objectAtIndex:0] size];
    _kShortTemperatureFormat = [[[NSBundle mainBundle] localizedStringForKey:@"ShortTemperatureFormat" value:@"" table:nil] retain];
    [self _calculateSizeForBestFit];
    __evenBarColor = [[NSColor colorWithDeviceWhite:0.98 alpha:1.0] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_acceptAdjustFontSize:) name:@"AdjustFontSizeNotification" object:nil];
}

// sizes the columns for the widest date and temperatures
+ (void)_calculateSizeForBestFit
{
    __daysCount = [Preferences expandedForecastDaysCount];
    __enabled = __daysCount != 0;
    __rectForSuperView.size = NSZeroSize;
    NSSize separator = [@"/" sizeWithAttributes:_sDefaultAttrs];
    __separatorRect.size = NSMakeSize((int)separator.width + 1, separator.height);
    __summaryIconRect.size.width = __summaryIconRect.size.height = separator.height * _kIconScale;
    NSString *temperature = [NSString stringWithFormat:_kShortTemperatureFormat, -88];
    NSSize high = [temperature sizeWithAttributes:_sHighTempAttrs];
    __highTempRect.size = NSMakeSize((int)high.width + 1, high.height);
    NSSize low = [temperature sizeWithAttributes:_sLowTempAttrs];
    __lowTempRect.size = NSMakeSize((int)low.width + 1, low.height);
    NSCalendarDate *date = [NSCalendarDate dateWithYear:2222 month:[NSCalendarDate monthWithMaxAbbrDescriptionWidth] day:22 hour:22 minute:22 second:22 timeZone:nil];
    NSInteger weekday = [NSCalendarDate weekdayWithMaxAbbrDescriptionWidth];
    while ([date dayOfWeek] != weekday)
        date = [date dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
    __weekdayRect.size = [[date descriptionWithCalendarFormat:@"%a, %b %e"] sizeWithAttributes:_sDateAttrs];

    float superWidth = __rectForSuperView.size.width;
    float half = __summaryIconRect.size.width + 20.0f + __highTempRect.size.width + __separatorRect.size.width + __lowTempRect.size.width;
    if (half < __weekdayRect.size.width + 5.0f)
        half = __weekdayRect.size.width + 5.0f;
    __sizeForBestFit.width = half + half;
    if (superWidth <= __sizeForBestFit.width) {
        __weekdayRect.origin.x = 0.0f;
    } else {
        __weekdayRect.origin.x = floorf((superWidth - __sizeForBestFit.width) * 0.5f);
        __sizeForBestFit.width = superWidth;
    }
    __rectForSuperView.origin = NSMakePoint(floorf((__sizeForBestFit.width - superWidth) * 0.5f), 0.0f);
    __highTempRect.origin.x = 5.0f;
    __separatorRect.origin.x = __highTempRect.size.width + 5.0f + 5.0f;
    __lowTempRect.origin.x = __separatorRect.origin.x + __separatorRect.size.width;
    __summaryIconRect.origin.x = __lowTempRect.origin.x + __lowTempRect.size.width + 5.0f;
    float lineHeight = __separatorRect.size.height;
    if (lineHeight <= __summaryIconRect.size.height + 2.0f)
        lineHeight = __summaryIconRect.size.height + 2.0f;
    __rowHeight = floorf(lineHeight) + 1.0f;
    __sizeForBestFit.height = __rowHeight * (float)__daysCount + __rectForSuperView.size.height;
}

- (id)accessibilityObjects
{
    if (![self enabled]) {
        [_accessibilityObjects release];
        _accessibilityObjects = nil;
        return nil;
    }
    if (_accessibilityObjects != nil)
        return _accessibilityObjects;
    NSMutableArray *objects = [NSMutableArray new];
    NSArray *forecasts = [_report objectForKey:@"SEVEN_FORECASTS"];
    NSCalendarDate *date = _firstForecastDate(_report, forecasts);
    float middle = floorf([self bounds].size.width * 0.5f);
    float y = __rectForSuperView.size.height;
    NSInteger count = [forecasts count];
    for (NSInteger day = __daysCount - 1; day >= 0; day--, y += __rowHeight) {
        id report = day < count ? [forecasts objectAtIndex:day] : nil;
        NSString *dateString = [[date dateByAddingYears:0 months:0 days:day hours:0 minutes:0 seconds:0] descriptionWithCalendarFormat:@"%a, %b %e"];
        [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:NSMakeRect(0.0f, y, middle, __rowHeight) description:dateString] autorelease]];
        NSString *high = [self _temperatureFromOneDayReport:report high:YES];
        if (high != nil)
            [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:NSMakeRect(middle + __highTempRect.origin.x, y, __highTempRect.size.width, __rowHeight) description:high] autorelease]];
        NSString *low = [self _temperatureFromOneDayReport:report high:NO];
        if (low != nil)
            [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:NSMakeRect(middle + __lowTempRect.origin.x, y, __lowTempRect.size.width, __rowHeight) description:low] autorelease]];
        if ([self _summaryIconFromOneDayReport:report] != nil) {
            NSString *description = [[NSBundle mainBundle] localizedStringForKey:@"Weather Icon" value:@"" table:nil];
            [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:NSMakeRect(middle + __summaryIconRect.origin.x, y, __summaryIconRect.size.width, __rowHeight) description:description] autorelease]];
        }
    }
    _accessibilityObjects = objects;
    return _accessibilityObjects;
}

- (NSUInteger)_reportType
{
    return 2;
}

- (NSUInteger)_reportMask
{
    return 4;
}

- (BOOL)enabled
{
    return __enabled && [super enabled];
}

- (NSSize)sizeForBestFit
{
    return __sizeForBestFit;
}

- (id)view:(id)aView stringForToolTip:(NSInteger)aTip point:(NSPoint)aPoint userData:(void *)aData
{
    NSRect iconRect = __summaryIconRect;
    iconRect.origin.x += floorf([self bounds].size.width * 0.5f);
    iconRect.origin.y = __rectForSuperView.size.height + 2.0f;
    for (NSInteger day = __daysCount - 1; day >= 0; day--, iconRect.origin.y += __rowHeight) {
        if (!NSPointInRect(aPoint, iconRect))
            continue;
        NSArray *forecasts = [[_entry dictionaryForReport:[self _reportType]] objectForKey:@"SEVEN_FORECASTS"];
        if (day >= (NSInteger)[forecasts count])
            return nil;
        return [[forecasts objectAtIndex:day] weatherDescription];
    }
    return nil;
}

- (void)drawRect:(NSRect)aRect
{
    NSDictionary *report = [self reportDictionary];
    NSArray *forecasts = [report objectForKey:@"SEVEN_FORECASTS"];
    NSCalendarDate *date = _firstForecastDate(report, forecasts);
    NSRect bounds = [self bounds];
    float middle = floorf(bounds.size.width * 0.5f);
    float y = __rectForSuperView.size.height;
    NSRect weekdayRect = __weekdayRect;
    weekdayRect.origin.x = floorf(middle - 5.0f - __weekdayRect.size.width);
    weekdayRect.origin.y = floorf((__rowHeight - __weekdayRect.size.height) * 0.5f) + y;
    NSInteger count = [forecasts count];
    for (NSInteger day = __daysCount - 1; day >= 0; day--, y += __rowHeight) {
        id dayReport = day < count ? [forecasts objectAtIndex:day] : nil;
        NSString *dateString = [[date dateByAddingYears:0 months:0 days:day hours:0 minutes:0 seconds:0] descriptionWithCalendarFormat:@"%a, %b %e"];
        [dateString drawInRect:weekdayRect withAttributes:_sDateAttrs];
        weekdayRect.origin.y += __rowHeight;
        if (day & 1) {
            [[__evenBarColor colorWithAlphaComponent:[Preferences paletteTransparencyLevel]] set];
            NSRectFill(NSMakeRect(middle, y, bounds.size.width - middle, __rowHeight));
        }
        NSImage *icon = [self _summaryIconFromOneDayReport:dayReport];
        [icon drawInRect:NSMakeRect(middle + __summaryIconRect.origin.x, y + 2.0f, __summaryIconRect.size.width, __summaryIconRect.size.height) fromRect:__realImageRect operation:NSCompositingOperationSourceOver fraction:1.0];

        NSString *low = [self _temperatureFromOneDayReport:dayReport high:NO];
        NSRect lowRect = __lowTempRect;
        lowRect.origin.x = floorf(__lowTempRect.size.width - [low sizeWithAttributes:_sLowTempAttrs].width) + middle + __lowTempRect.origin.x;
        lowRect.origin.y = y + floorf((__rowHeight - __lowTempRect.size.height) * 0.5f);
        [low drawInRect:lowRect withAttributes:_sLowTempAttrs];

        NSString *high = [self _temperatureFromOneDayReport:dayReport high:YES];
        NSRect highRect = __highTempRect;
        highRect.origin.x = middle + floorf(__highTempRect.origin.x + __highTempRect.size.width - [high sizeWithAttributes:_sHighTempAttrs].width);
        highRect.origin.y = y + floorf((__rowHeight - __highTempRect.size.height) * 0.5f);
        [high drawInRect:highRect withAttributes:_sHighTempAttrs];

        if (low != nil || high != nil) {
            NSRect separatorRect = __separatorRect;
            separatorRect.origin.x = middle + __separatorRect.origin.x;
            separatorRect.origin.y = floorf((__rowHeight - __separatorRect.size.height) * 0.5f) + y;
            [@"/" drawInRect:separatorRect withAttributes:_sDefaultAttrs];
        }
    }
    [[NSColor colorWithCalibratedWhite:[Preferences separatorColorWhiteComponent] alpha:[Preferences paletteTransparencyLevel]] set];
    NSFrameRect(NSMakeRect(middle, 0.0, 1.0, bounds.size.height));
    NSFrameRect(NSMakeRect(0.0, 0.0, bounds.size.width, 1.0));
}

- (void)_viewSizeWasChanged:(id)aChanged
{
    [self _checkToolTipRects];
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
}

- (void)_acceptMenuChanges:(id)aChanges
{
    [self adjustEnableState];
}

- (void)_acceptAdjustSize:(id)aSize
{
    [self alignProgressIndicator];
}

- (id)_temperatureFromOneDayReport:(id)aReport high:(BOOL)aHigh
{
    id value = [aReport objectForKey:aHigh ? @"TEMPERATURE_HIGH" : @"TEMPERATURE_LOW"];
    if (value == nil)
        return nil;
    float temperature = [value floatValue];
    if (![[self class] usesMetricSystem])
        temperature = _fahrenheitFromCelsius(temperature);
    return [NSString stringWithFormat:_kShortTemperatureFormat, (int)lroundf(temperature)];
}

- (id)_summaryIconFromOneDayReport:(id)aReport
{
    if (aReport == nil)
        return nil;
    int code = [[aReport objectForKey:@"SUMMARY_CODE"] intValue];
    if (code == 0)
        return nil;
    return [[CWManager weatherImagesForIconAtIndex:code] objectAtIndex:0];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super initWithCityEntry:aEntry];
    if (self != nil) {
        [self _checkToolTipRects];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_acceptMenuChanges:) name:@"ExpandedForecastMenuNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptAdjustSize:) name:@"ExpandedForecastNeedAdjustSizeNotification" object:nil];
        [center addObserver:self selector:@selector(_viewSizeWasChanged:) name:NSViewFrameDidChangeNotification object:self];
        [self setAutoresizingMask:NSViewWidthSizable];
    }
    return self;
}

// a tool tip with the weather description over each day's icon
- (void)_checkToolTipRects
{
    [self removeAllToolTips];
    NSRect iconRect = __summaryIconRect;
    iconRect.origin.x += floorf([self bounds].size.width * 0.5f);
    iconRect.origin.y = __rectForSuperView.size.height + 2.0f;
    for (NSInteger day = __daysCount - 1; day >= 0; day--, iconRect.origin.y += __rowHeight)
        [self addToolTipRect:NSInsetRect(iconRect, 0.0, 1.0) owner:self userData:NULL];
}

@end
