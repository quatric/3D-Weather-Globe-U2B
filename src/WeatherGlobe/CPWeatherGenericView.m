#import "CPWeatherGenericView.h"

static NSAttributedString *__expiredString = nil;
static BOOL __usesMetricSystem = NO;
static BOOL __usesInternet = NO;
static BOOL __enabled = NO;

@implementation CPWeatherGenericView

+ (id)expiredString
{
    return __expiredString;
}

+ (BOOL)usesMetricSystem
{
    return __usesMetricSystem;
}

+ (void)_internetStateWasChanged:(id)aChanged
{
    __usesInternet = [Preferences usesInternet];
    __enabled = [Preferences internetState] != 0;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:@"AdjustEnableStateNotification" object:self userInfo:nil];
    [center postNotificationName:@"NeedReconstructNotification" object:self userInfo:nil];
}

+ (void)_unitsOfMeasureWereChanged:(id)aChanged
{
    __usesMetricSystem = [Preferences usesMetricSystem];
}

+ (void)initialize
{
    if (__expiredString != nil)
        return;
    NSString *text = [[NSBundle mainBundle] localizedStringForKey:@"Updating Weather" value:@"" table:nil];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0], NSForegroundColorAttributeName, [NSFont systemFontOfSize:9.0], NSFontAttributeName, nil];
    __expiredString = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    __usesMetricSystem = [Preferences usesMetricSystem];
    __usesInternet = [Preferences usesInternet];
    __enabled = [Preferences internetState] != 0;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];
    [center addObserver:self selector:@selector(_internetStateWasChanged:) name:kInternetStateWasChanged object:nil];
}

+ (NSSize)sizeForBestFit
{
    NSSize size = [__expiredString size];
    return NSMakeSize((int)size.width + 5, (int)size.height + 1);
}

- (NSUInteger)_reportType
{
    return 0;
}

- (NSUInteger)_reportMask
{
    return 0;
}

- (BOOL)enabled
{
    return __enabled;
}

- (id)reportDictionary
{
    return _report;
}

- (void)alignProgressIndicator
{
}

- (void)adjustEnableState
{
    if ([self enabled] && __usesInternet)
        [self _schedule];
    else
        [self _unschedule];
}

- (void)drawRect:(NSRect)aRect
{
    [__expiredString drawInRect:NSInsetRect(aRect, 2.0, -1.0)];
}

- (void)viewDidMoveToWindow
{
    [self _schedule];
}

- (void)setMenu:(id)aMenu
{
    [super setMenu:aMenu];
    [_progressIndicator setMenu:aMenu];
}

- (void)_acceptWindowWillClose:(id)aClose
{
    if ([aClose object] == [self window])
        [self _unschedule];
}

- (void)_acceptWindowDidShow:(id)aShow
{
    if ([aShow object] == [self window])
        [self _schedule];
}

- (void)_acceptNeedStopAnimations:(id)aAnimations
{
    [_progressIndicator stopAnimation:self];
    _isAnimating = NO;
}

- (void)_acceptNeedStartAnimations:(id)aAnimations
{
    if ([self enabled] && [_progressIndicator superview] != nil && !_isAnimating) {
        [_progressIndicator startAnimation:self];
        _isAnimating = YES;
    }
}

- (void)_adjustEnableState:(id)aState
{
    [self adjustEnableState];
}

- (void)_unitsOfMeasureWereChanged:(id)aChanged
{
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedCreateImageNotification" object:_entry userInfo:nil];
}

- (void)_reportsWereChanged:(id)aChanged
{
    NSUInteger type = [self _reportType];
    if (type != [[[aChanged userInfo] objectForKey:kReportIDKey] unsignedIntValue])
        return;
    [_report autorelease];
    _report = [[_entry dictionaryForReport:type] retain];
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
    [self setNeedsDisplay:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedCreateImageNotification" object:_entry userInfo:nil];
}

- (void)dealloc
{
    [self _unschedule];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_progressIndicator release];
    _progressIndicator = nil;
    [_accessibilityObjects release];
    [_report release];
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super initWithCityEntry:aEntry];
    if (self == nil)
        return nil;
    _report = [[_entry dictionaryForReport:[self _reportType]] retain];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_reportsWereChanged:) name:kCityEntryWasUpdatedViaOnlineNotification object:_entry];
    [center addObserver:self selector:@selector(_reportsWereChanged:) name:kCityEntryWasExpiredViaOnlineNotification object:_entry];
    [center addObserver:self selector:@selector(_adjustEnableState:) name:@"AdjustEnableStateNotification" object:nil];
    [center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];
    [center addObserver:self selector:@selector(_acceptNeedStartAnimations:) name:@"NeedStartAnimationsNotification" object:nil];
    [center addObserver:self selector:@selector(_acceptNeedStopAnimations:) name:@"NeedStopAnimationsNotification" object:nil];
    [center addObserver:self selector:@selector(_acceptWindowWillClose:) name:NSWindowWillCloseNotification object:nil];
    [center addObserver:self selector:@selector(_acceptWindowDidShow:) name:@"WindowDidShowNotification" object:nil];
    return self;
}

- (void)_unschedule
{
    if (_scheduled) {
        [_entry unscheduleReports:[self _reportMask]];
        _scheduled = NO;
    }
}

- (void)_schedule
{
    if (!_scheduled && [self enabled] && [[self window] isVisible]) {
        [_entry scheduleReports:[self _reportMask]];
        _scheduled = YES;
    }
}

@end
