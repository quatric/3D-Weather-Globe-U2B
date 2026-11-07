#import "CPAstronomyForecastView.h"

static NSMutableDictionary *__attrs = nil;
static BOOL __enabled = NO;
static NSString *_kSunriseFormat = nil;
static NSString *_kSunsetFormat = nil;
static NSString *_kMoonriseFormat = nil;
static NSString *_kMoonsetFormat = nil;
static NSSize __sizeForBestFit;
static NSRect __rectForSuperView;
static NSRect __rectForSunrise;
static NSRect __rectForSunset;
static NSRect __rectForMoonrise;
static NSRect __rectForMoonset;

static NSString *_timeString(id aValue, NSString *aFormat)
{
    if (aValue == nil)
        return @"?";
    return [[NSCalendarDate dateWithString:aValue calendarFormat:@"%I:%M%p"] descriptionWithCalendarFormat:aFormat];
}

@implementation CPAstronomyForecastView

+ (void)_clocksMeasureWereChanged:(id)aChanged
{
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AstronomyForecastAdjustSizeNotification" object:self userInfo:nil];
}

+ (void)_acceptAdjustFontSize:(id)aSize
{
    [__attrs setObject:[NSFont systemFontOfSize:[Preferences paletteFontSize]] forKey:NSFontAttributeName];
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AstronomyForecastAdjustSizeNotification" object:self userInfo:nil];
}

+ (void)_enabledStateMenu:(id)aMenu
{
    __enabled = ![Preferences astronomyForecastEnabled];
    [Preferences setAstronomyForecastEnabled:__enabled];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"AstronomyForecastMenuNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
}

+ (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(_enabledStateMenu:)) {
        [aItem setState:[Preferences astronomyForecastEnabled] ? NSControlStateValueOn : NSControlStateValueOff];
        if ([Preferences internetState] == 0)
            return NO;
    }
    return [Preferences doShowWeatherOnStartup];
}

+ (id)_menuItemsDescriptors
{
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"AstronomyReport" value:@"" table:nil];
    NSArray *keys = [NSArray arrayWithObjects:@"TITLE", @"TAG", @"SELECTOR", nil];
    NSArray *values = [NSArray arrayWithObjects:title, @"0", @"_enabledStateMenu:", nil];
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:values forKeys:keys], nil];
}

+ (void)initialize
{
    if (__attrs != nil)
        return;
    __attrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSColor blackColor], NSForegroundColorAttributeName, [NSFont systemFontOfSize:[Preferences paletteFontSize]], NSFontAttributeName, nil];
    __enabled = [Preferences astronomyForecastEnabled];
    NSBundle *bundle = [NSBundle mainBundle];
    _kSunriseFormat = [[bundle localizedStringForKey:@"SunriseFormat" value:@"" table:nil] retain];
    _kSunsetFormat = [[bundle localizedStringForKey:@"SunsetFormat" value:@"" table:nil] retain];
    _kMoonriseFormat = [[bundle localizedStringForKey:@"MoonriseFormat" value:@"" table:nil] retain];
    _kMoonsetFormat = [[bundle localizedStringForKey:@"MoonsetFormat" value:@"" table:nil] retain];
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_acceptAdjustFontSize:) name:@"AdjustFontSizeNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_clocksMeasureWereChanged:) name:@"AdjustTimeFormatNotification" object:nil];
}

+ (void)_calculateSizeForBestFit
{
    NSSize superSize = [super sizeForBestFit];
    __rectForSuperView.size = superSize;

    NSCalendarDate *date = [NSCalendarDate calendarDate];
    if ([date hourOfDay] >= 12)
        date = [date dateByAddingYears:0 months:0 days:0 hours:12 minutes:0 seconds:0];
    NSString *time = [date descriptionWithCalendarFormat:[Preferences uses24HourClock] ? @"%H:%M" : @"%I:%M %p"];
    __rectForSunrise.size = [[NSString stringWithFormat:_kSunriseFormat, time] sizeWithAttributes:__attrs];
    __rectForSunset.size = [[NSString stringWithFormat:_kSunsetFormat, time] sizeWithAttributes:__attrs];
    __rectForMoonrise.size = [[NSString stringWithFormat:_kMoonriseFormat, time] sizeWithAttributes:__attrs];
    __rectForMoonset.size = [[NSString stringWithFormat:_kMoonsetFormat, time] sizeWithAttributes:__attrs];

    float left = MAX(__rectForSunrise.size.width, __rectForMoonrise.size.width);
    float right = MAX(__rectForSunset.size.width, __rectForMoonset.size.width);
    float total = left + 4.0f + right;
    float width = total <= superSize.width ? (float)superSize.width : total;
    __sizeForBestFit.width = width;
    __sizeForBestFit.height = __rectForSunrise.size.height + __rectForSunrise.size.height + superSize.height;
    float offset = ceilf((width - total) * 0.5f);
    __rectForSuperView.origin.x = ceilf((width - (float)superSize.width) * 0.5f);
    __rectForSuperView.origin.y = 0;
    float leftEdge = left + offset;
    float rightEdge = offset + total;
    __rectForMoonrise.origin = NSMakePoint(leftEdge - __rectForMoonrise.size.width, superSize.height);
    __rectForSunrise.origin = NSMakePoint(leftEdge - __rectForSunrise.size.width, superSize.height + __rectForMoonrise.size.height);
    __rectForMoonset.origin = NSMakePoint(rightEdge - __rectForMoonset.size.width, superSize.height);
    __rectForSunset.origin = NSMakePoint(rightEdge - __rectForSunset.size.width, superSize.height + __rectForMoonrise.size.height);
}

- (NSUInteger)_reportType
{
    return 3;
}

- (NSUInteger)_reportMask
{
    return 8;
}

- (BOOL)enabled
{
    return __enabled && [super enabled];
}

- (NSSize)sizeForBestFit
{
    return __sizeForBestFit;
}

- (void)drawRect:(NSRect)aRect
{
    NSDictionary *report = [self reportDictionary];
    if (report == nil)
        return;
    if ([[report objectForKey:@"DATA_EXPIRED"] intValue] != 0)
        [super drawRect:__rectForSuperView];
    NSString *format = [Preferences uses24HourClock] ? @"%H:%M" : @"%I:%M %p";
    [[NSString stringWithFormat:_kSunriseFormat, _timeString([report objectForKey:@"SUNRISE"], format)] drawInRect:__rectForSunrise withAttributes:__attrs];
    [[NSString stringWithFormat:_kSunsetFormat, _timeString([report objectForKey:@"SUNSET"], format)] drawInRect:__rectForSunset withAttributes:__attrs];
    [[NSString stringWithFormat:_kMoonriseFormat, _timeString([report objectForKey:@"MOONRISE"], format)] drawInRect:__rectForMoonrise withAttributes:__attrs];
    [[NSString stringWithFormat:_kMoonsetFormat, _timeString([report objectForKey:@"MOONSET"], format)] drawInRect:__rectForMoonset withAttributes:__attrs];
}

- (void)_acceptMenuChanges:(id)aChanges
{
    [self adjustEnableState];
}

- (void)_acceptRefresh:(id)aRefresh
{
    [self alignProgressIndicator];
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
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_acceptMenuChanges:) name:@"AstronomyForecastMenuNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptRefresh:) name:@"AstronomyForecastAdjustSizeNotification" object:nil];
    }
    return self;
}

@end
