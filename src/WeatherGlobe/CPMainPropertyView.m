#import "CPMainPropertyView.h"

static NSCell *__drawCell = nil;
static NSInteger __detailViewFlags = 0;
static NSString *__calendarFormat = nil;
static NSCalendarDate *__date = nil;

static void __refreshCalendarFormat(BOOL resetDate)
{
    NSMutableArray *parts = [NSMutableArray array];
    if (__detailViewFlags & 4)
        [parts addObject:@"%a"];
    if (__detailViewFlags & 0x20) {
        NSMutableString *time = [NSMutableString stringWithString:[Preferences uses24HourClock] ? @"%H:%M" : @"%I:%M %p"];
        if (__detailViewFlags & 2)
            [time appendString:@","];
        [parts addObject:time];
    }
    if (__detailViewFlags & 2)
        [parts addObject:@"%b %e"];
    if (__detailViewFlags & 8)
        [parts addObject:@"%z"];
    [__calendarFormat release];
    __calendarFormat = [[parts componentsJoinedByString:@" "] retain];
    if (resetDate) {
        [__date release];
        __date = [[NSCalendarDate calendarDate] retain];
    }
}

@implementation CPMainPropertyView

+ (void)initialize
{
    if (__drawCell != nil)
        return;
    __drawCell = [NSCell new];
    [__drawCell setAlignment:NSTextAlignmentCenter];
    __detailViewFlags = [Preferences mainPropertiesDetailViewFlags];
    __refreshCalendarFormat(YES);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_acceptAdjustFontSize:) name:@"AdjustFontSizeNotification" object:nil];
    [center addObserver:self selector:@selector(_clocksMeasureWereChanged:) name:@"AdjustTimeFormatNotification" object:nil];
}

+ (void)_acceptAdjustFontSize:(id)aSize
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AdjustSizeForBestFitNotification" object:self userInfo:nil];
}

+ (void)_clocksMeasureWereChanged:(id)aChanged
{
    __refreshCalendarFormat(YES);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"MainPropertyMenuNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
}

+ (void)_detailViewMenu:(id)aMenu
{
    __detailViewFlags = [Preferences mainPropertiesDetailViewFlags] ^ [aMenu tag];
    [Preferences setMainPropertiesDetailViewFlags:__detailViewFlags];
    __refreshCalendarFormat(YES);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"MainPropertyMenuNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
}

+ (BOOL)validateMenuItem:(id)aItem
{
    NSInteger tag = [aItem tag];
    if ([aItem action] == @selector(_detailViewMenu:)) {
        __detailViewFlags = [Preferences mainPropertiesDetailViewFlags];
        [aItem setState:(__detailViewFlags & tag) != 0];
    }
    return [Preferences doShowWeatherOnStartup];
}

+ (id)_menuItemsDescriptors
{
    NSMutableArray *descriptors = [NSMutableArray array];
    NSArray *titles = [NSArray arrayWithObjects:@"Country/Location", @"Time", @"Date", @"Weekday", @"GMT Offset", nil];
    NSArray *tags = [NSArray arrayWithObjects:[NSNumber numberWithInt:1], [NSNumber numberWithInt:0x20], [NSNumber numberWithInt:2], [NSNumber numberWithInt:4], [NSNumber numberWithInt:8], nil];
    NSInteger count = [titles count];
    for (NSInteger i = 0; i < count; i++) {
        NSString *title = [[NSBundle mainBundle] localizedStringForKey:[titles objectAtIndex:i] value:@"" table:nil];
        NSArray *keys = [NSArray arrayWithObjects:@"TITLE", @"TAG", @"SELECTOR", nil];
        NSArray *values = [NSArray arrayWithObjects:title, [tags objectAtIndex:i], @"_detailViewMenu:", nil];
        [descriptors addObject:[NSDictionary dictionaryWithObjects:values forKeys:keys]];
    }
    return descriptors;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_accessibilityObjects release];
    [_title release];
    [_formatedTime release];
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super initWithCityEntry:aEntry];
    if (self != nil) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_acceptMenuChanges:) name:@"MainPropertyMenuNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptAdjustTime:) name:@"AdjustTimeNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptAdjustSizeForBestFit:) name:@"AdjustSizeForBestFitNotification" object:nil];
        [self _acceptMenuChanges:nil];
        [self setAutoresizingMask:NSViewWidthSizable];
    }
    return self;
}

- (id)accessibilityObjects
{
    if (_accessibilityObjects == nil) {
        id title = [[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:_lastTitleRect description:_title] autorelease];
        id date = [[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:_lastDateRect description:_formatedTime] autorelease];
        _accessibilityObjects = [[NSArray alloc] initWithObjects:date, title, nil];
    }
    return _accessibilityObjects;
}

- (BOOL)enabled
{
    return YES;
}

- (NSSize)sizeForBestFit
{
    return _sizeForBestFit;
}

- (void)drawRect:(NSRect)aRect
{
    float fontSize = [Preferences paletteFontSize];
    [__drawCell setFont:[NSFont systemFontOfSize:fontSize - 2.0f]];
    [__drawCell setStringValue:_formatedTime];
    NSSize size = [__drawCell cellSize];
    _lastDateRect = NSMakeRect(0, 5, floorf(size.width) + 1.0f, floorf(size.height) + 1.0f);
    [__drawCell drawInteriorWithFrame:_lastDateRect inView:self];
    float y = _lastDateRect.size.height + 0.0f + 5.0f;
    [__drawCell setFont:[NSFont boldSystemFontOfSize:fontSize]];
    [__drawCell setStringValue:_title];
    size = [__drawCell cellSize];
    _lastTitleRect = NSMakeRect(0, y, floorf(size.width) + 1.0f, floorf(size.height) + 1.0f);
    [__drawCell drawInteriorWithFrame:_lastTitleRect inView:self];
}

- (void)_acceptAdjustTime:(id)aTime
{
    if (![[aTime object] isKindOfClass:[NSCalendarDate class]])
        return;
    if ([aTime object] != __date) {
        __refreshCalendarFormat(NO);
        [__date release];
        __date = [[aTime object] retain];
    }
    [self _adjustTime];
    if ([aTime userInfo] != nil)
        [self _calculateSizeForBestFit];
}

- (void)_acceptMenuChanges:(id)aChanges
{
    NSMutableArray *parts = [NSMutableArray array];
    [parts addObject:[_entry ownName]];
    if (__detailViewFlags & 1) {
        NSString *region = [_entry regionName];
        [parts addObject:region != nil ? region : @""];
    }
    [_title release];
    _title = [[parts componentsJoinedByString:@", "] retain];
    [self _adjustTime];
    [self _calculateSizeForBestFit];
}

- (void)_acceptAdjustSizeForBestFit:(id)aFit
{
    [self _calculateSizeForBestFit];
}

- (void)_calculateSizeForBestFit
{
    float fontSize = [Preferences paletteFontSize];
    [__drawCell setFont:[NSFont boldSystemFontOfSize:fontSize]];
    [__drawCell setStringValue:_title];
    NSSize size = [__drawCell cellSize];
    _sizeForBestFit.width = floorf(size.width) + 1.0f;
    _sizeForBestFit.height = floorf(size.height) + 1.0f;
    [__drawCell setFont:[NSFont systemFontOfSize:fontSize - 2.0f]];
    [__drawCell setStringValue:_formatedTime];
    size = [__drawCell cellSize];
    float timeWidth = floorf(size.width) + 1.0f;
    _sizeForBestFit.height = floorf(size.height) + 1.0f + 0.0f + 10.0f + _sizeForBestFit.height;
    if (_sizeForBestFit.width < timeWidth)
        _sizeForBestFit.width = timeWidth;
    _sizeForBestFit.width += 0.0f;
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
}

- (void)_adjustTime
{
    [__date setTimeZone:[_entry timeZone]];
    NSString *format = [[__calendarFormat componentsSeparatedByString:@"%z"] componentsJoinedByString:[__date descriptionGMTOffset]];
    format = [[format componentsSeparatedByString:@"%D"] componentsJoinedByString:[__date descriptionDate]];
    [_formatedTime release];
    _formatedTime = [[__date descriptionWithCalendarFormat:format] retain];
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedCreateImageNotification" object:_entry userInfo:nil];
}

@end
