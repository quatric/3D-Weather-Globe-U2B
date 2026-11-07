#import "CPCurrentConditionsView.h"

static NSMutableDictionary *__attrs = nil;
static NSMutableDictionary *__metricAttrs = nil;
static BOOL __enabled = NO;
static float __summaryIconScale = 1.0f;
static NSRect __summaryIconRealRect;
static NSRect __metricRect;
static NSSize __sizeForBestFit;
static NSRect __summaryIconRect;
static NSRect __temperatureRect;
static NSRect __rectForSuperView;
static NSRect __warningRect;

static NSFont *_arialFont(CGFloat aSize)
{
    NSFont *font = [NSFont fontWithName:@"Arial" size:aSize];
    if (font == nil)
        font = [NSFont systemFontOfSize:aSize];
    return font;
}

@implementation CPCurrentConditionsView

+ (void)_acceptAdjustFontSize:(id)aSize
{
    float fontSize = [Preferences paletteFontSize];
    [__attrs setObject:_arialFont(fontSize * 2.5f) forKey:NSFontAttributeName];
    [__metricAttrs setObject:_arialFont(fontSize) forKey:NSFontAttributeName];
    __summaryIconScale = fontSize / 13.0f;
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CurrentConditionsNeedAdjustSizeNotification" object:self userInfo:nil];
}

+ (void)_enabledStateMenu:(id)aMenu
{
    __enabled = ![Preferences currentConditionsEnabled];
    [Preferences setCurrentConditionsEnabled:__enabled];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"CurrentConditionsMenuNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
}

+ (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(_enabledStateMenu:)) {
        [aItem setState:[Preferences currentConditionsEnabled] ? NSControlStateValueOn : NSControlStateValueOff];
        if ([Preferences internetState] == 0)
            return NO;
    }
    return [Preferences doShowWeatherOnStartup];
}

+ (id)_menuItemsDescriptors
{
    NSString *title = [[NSBundle mainBundle] localizedStringForKey:@"Today Weather" value:@"" table:nil];
    NSArray *keys = [NSArray arrayWithObjects:@"TITLE", @"TAG", @"SELECTOR", nil];
    NSArray *values = [NSArray arrayWithObjects:title, @"0", @"_enabledStateMenu:", nil];
    return [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:values forKeys:keys], nil];
}

+ (void)initialize
{
    if (__attrs != nil)
        return;
    float fontSize = [Preferences paletteFontSize];
    __attrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSColor blackColor], NSForegroundColorAttributeName, _arialFont(fontSize * 2.5f), NSFontAttributeName, nil];
    fontSize = [Preferences paletteFontSize];
    __metricAttrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSColor blackColor], NSForegroundColorAttributeName, _arialFont(fontSize), NSFontAttributeName, nil];
    __summaryIconRealRect.origin = NSZeroPoint;
    __summaryIconRealRect.size = [[[CWManager weatherImagesForIconAtIndex:1] objectAtIndex:0] size];
    __summaryIconScale = [Preferences paletteFontSize] / 13.0f;
    __enabled = [Preferences currentConditionsEnabled];
    [self _calculateSizeForBestFit];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_acceptAdjustFontSize:) name:@"AdjustFontSizeNotification" object:nil];
}

+ (void)_calculateSizeForBestFit
{
    __sizeForBestFit = NSZeroSize;
    __rectForSuperView.size = __sizeForBestFit;
    NSString *format = [[NSBundle mainBundle] localizedStringForKey:@"ShortTemperatureFormat" value:@"" table:nil];
    NSSize size = [[NSString stringWithFormat:format, -88] sizeWithAttributes:__attrs];
    __temperatureRect.size.width = floorf(size.width) + 1.0f;
    __temperatureRect.size.height = floorf(size.height) + 1.0f;
    __summaryIconRect.size.height = __summaryIconScale * __summaryIconRealRect.size.height;
    __summaryIconRect.size.width = __summaryIconScale * __summaryIconRealRect.size.width;
    float iconX = __temperatureRect.size.width + 5.0f;
    float width = iconX + __summaryIconRect.size.width + 5.0f;
    if (width > __sizeForBestFit.width)
        __sizeForBestFit.width = width;
    float rowHeight = MAX(__temperatureRect.size.height, __summaryIconRect.size.height);
    __rectForSuperView.origin.x = floorf((__sizeForBestFit.width - __rectForSuperView.size.width) * 0.5f);
    __rectForSuperView.origin.y = 0;
    __temperatureRect.origin.y = __rectForSuperView.size.height + floorf((rowHeight - __temperatureRect.size.height) * 0.5f);
    __temperatureRect.origin.x = 0.0;
    __summaryIconRect.origin.y = __rectForSuperView.size.height + floorf((rowHeight - __summaryIconRect.size.height) * 0.5f);
    __sizeForBestFit.height = rowHeight + __sizeForBestFit.height;
    __summaryIconRect.origin.x = iconX;
    size = [@"C" sizeWithAttributes:__metricAttrs];
    __metricRect.size.width = floorf(size.width) + 1.0f;
    __metricRect.size.height = floorf(size.height) + 1.0f;
    __metricRect.origin.x = __temperatureRect.origin.x + __temperatureRect.size.width - __metricRect.size.width;
    __metricRect.origin.y = floorf(__temperatureRect.size.height * 0.12f + __temperatureRect.origin.y);
    // a warning badge in the top left corner, left of the temperature digits
    size = [@"\u26A0" sizeWithAttributes:__metricAttrs];
    __warningRect.size.width = floorf(size.width) + 1.0f;
    __warningRect.size.height = floorf(size.height) + 1.0f;
    __warningRect.origin.x = __temperatureRect.origin.x;
    __warningRect.origin.y = __temperatureRect.origin.y + __temperatureRect.size.height - __warningRect.size.height;
}

- (id)accessibilityObjects
{
    if (![self enabled]) {
        [_accessibilityObjects release];
        _accessibilityObjects = nil;
        return nil;
    }
    if (_accessibilityObjects == nil) {
        NSMutableArray *objects = [NSMutableArray new];
        NSString *temperature = [self _temperatureFromReport:_report];
        if (temperature != nil)
            [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:__temperatureRect description:temperature] autorelease]];
        if ([self _summaryIconFromReport:_report] != nil) {
            NSString *description = [[NSBundle mainBundle] localizedStringForKey:@"Weather Icon" value:@"" table:nil];
            [objects addObject:[[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:__summaryIconRect description:description] autorelease]];
        }
        _accessibilityObjects = objects;
    }
    return _accessibilityObjects;
}

- (NSUInteger)_reportType
{
    return 0;
}

- (NSUInteger)_reportMask
{
    return 1;
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
    return [[_entry dictionaryForReport:[self _reportType]] weatherDescription];
}

- (void)drawRect:(NSRect)aRect
{
    NSDictionary *report = [self reportDictionary];
    NSString *temperature = [self _temperatureFromReport:report];
    NSRect rect = __temperatureRect;
    rect.origin.x = (__temperatureRect.size.width - [temperature sizeWithAttributes:__attrs].width) + __temperatureRect.origin.x;
    [temperature drawInRect:rect withAttributes:__attrs];
    NSString *unit = temperature;
    if ([temperature length] != 0)
        unit = [[self class] usesMetricSystem] ? @"C" : @"F";
    [unit drawInRect:__metricRect withAttributes:__metricAttrs];
    [[self _summaryIconFromReport:report] drawInRect:__summaryIconRect fromRect:__summaryIconRealRect operation:NSCompositingOperationSourceOver fraction:1.0];
    NSColor *warningColor = [report warningColor];
    if (warningColor != nil) {
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:__metricAttrs];
        [attrs setObject:warningColor forKey:NSForegroundColorAttributeName];
        [@"\u26A0" drawInRect:__warningRect withAttributes:attrs];
    }
}

- (void)_acceptMenuChanges:(id)aChanges
{
    [self adjustEnableState];
}

- (void)_acceptAdjustSize:(id)aSize
{
    [self alignProgressIndicator];
    [self _checkToolTipRect];
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
}

- (id)_temperatureFromReport:(id)aReport
{
    if (aReport == nil)
        return nil;
    return [aReport shortTempratureForKey:@"TEMPERATURE"];
}

- (id)_summaryIconFromReport:(id)aReport
{
    if (aReport == nil)
        return nil;
    NSInteger index = [aReport weatherImageIndexForKey:@"SUMMARY_CODE"];
    if (index == 0)
        return nil;
    return [[CWManager weatherImagesForIconAtIndex:index] objectAtIndex:0];
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
        [self _checkToolTipRect];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_acceptMenuChanges:) name:@"CurrentConditionsMenuNotification" object:nil];
        [center addObserver:self selector:@selector(_acceptAdjustSize:) name:@"CurrentConditionsNeedAdjustSizeNotification" object:nil];
        [self setAutoresizingMask:NSViewMinXMargin];
    }
    return self;
}

- (void)_checkToolTipRect
{
    [self removeAllToolTips];
    [self addToolTipRect:__summaryIconRect owner:self userData:NULL];
    [self addToolTipRect:__warningRect owner:self userData:NULL];
}

@end
