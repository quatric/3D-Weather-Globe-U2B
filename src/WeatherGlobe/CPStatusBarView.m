#import "CPStatusBarView.h"

static NSMutableDictionary *_sAttrs = nil;
static NSSize _sSizeForBestFit;

@implementation CPStatusBarView

+ (id)_menuItemsDescriptors
{
    return nil;
}

+ (void)initialize
{
    if (_sAttrs != nil)
        return;
    _sAttrs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedWhite:0.2 alpha:1.0], NSForegroundColorAttributeName, [NSFont systemFontOfSize:9.0], NSFontAttributeName, nil];
    [self _calculateSizeForBestFit];
}

+ (void)_calculateSizeForBestFit
{
    _sSizeForBestFit = [[self _progressIndicator] frame].size;
    NSSize textSize = [[[NSBundle mainBundle] localizedStringForKey:@"Updating Weather" value:@"" table:nil] sizeWithAttributes:_sAttrs];
    _sSizeForBestFit.width = textSize.width + 4.0f + _sSizeForBestFit.width + 6.0f;
    _sSizeForBestFit.height = MAX(textSize.height, _sSizeForBestFit.height) + 4.0f;
}

+ (id)_progressIndicator
{
    NSProgressIndicator *indicator = [[NSProgressIndicator new] autorelease];
    [indicator setStyle:NSProgressIndicatorStyleSpinning];
    [indicator setControlSize:NSControlSizeSmall];
    [indicator setDisplayedWhenStopped:NO];
    [indicator sizeToFit];
    return indicator;
}

- (void)_setState:(NSInteger)aState
{
    if (_state == aState)
        return;
    _state = (int)aState;
    [_statusText release];
    _statusText = nil;
    [_accessibilityObjects release];
    _accessibilityObjects = nil;
    if (aState == 1) {
        _statusText = [[[NSBundle mainBundle] localizedStringForKey:@"Updating Weather" value:@"" table:nil] retain];
        [self addSubview:_progressIndicator];
    } else if (aState == 0 || aState == 2) {
        if (aState == 2)
            _statusText = [[[NSBundle mainBundle] localizedStringForKey:@"Updating failed" value:@"" table:nil] retain];
        [self _acceptNeedStopAnimations:nil];
        [_progressIndicator removeFromSuperview];
    }
    [self display];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedCreateImageNotification" object:_entry userInfo:nil];
}

- (BOOL)_isWeatherExpired
{
    NSDictionary *current = [_entry dictionaryForReport:0];
    BOOL expired = [Preferences currentConditionsEnabled] && (current == nil || [[current objectForKey:@"DATA_EXPIRED"] intValue] != 0);
    NSDictionary *forecast = [_entry dictionaryForReport:2];
    if (expired)
        return YES;
    if ([Preferences expandedForecastDaysCount] == 0)
        return NO;
    return forecast == nil || [[forecast objectForKey:@"DATA_EXPIRED"] intValue] != 0;
}

- (id)accessibilityObjects
{
    if (![self enabled]) {
        [_accessibilityObjects release];
        _accessibilityObjects = nil;
        return nil;
    }
    if (_accessibilityObjects == nil && [self _isWeatherExpired]) {
        id text = [[[CityPropertyAccessibilityObject alloc] initWithParentView:self frameRect:_lastTextRect description:_statusText] autorelease];
        _accessibilityObjects = [[NSArray alloc] initWithObjects:text, _state == 1 ? _progressIndicator : nil, nil];
    }
    return _accessibilityObjects;
}

- (BOOL)enabled
{
    if ([Preferences internetState] == 0)
        return NO;
    return [Preferences currentConditionsEnabled] || [Preferences expandedForecastDaysCount] != 0;
}

- (NSSize)sizeForBestFit
{
    return _sSizeForBestFit;
}

- (void)drawRect:(NSRect)aRect
{
    if (_statusText == nil)
        return;
    _lastTextRect.size = [_statusText sizeWithAttributes:_sAttrs];
    float y = floorf(([self bounds].size.height - _lastTextRect.size.height) * 0.5f);
    _lastTextRect.origin.x = [_progressIndicator frame].size.width + 3.0f + 4.0f;
    _lastTextRect.origin.y = y + 1.0f;
    [_statusText drawInRect:_lastTextRect withAttributes:_sAttrs];
}

- (void)setMenu:(id)aMenu
{
    [super setMenu:aMenu];
    [_progressIndicator setMenu:aMenu];
}

- (void)_weatherInternetStateWasChanged:(id)aChanged
{
    if ([self _isWeatherExpired])
        [self _reportsWereExpired:nil];
    else
        [self _setState:0];
}

- (void)_reportsWereUpdated:(id)aUpdated
{
    if (![self _isWeatherExpired])
        [self _setState:0];
}

- (void)_reportsWereExpired:(id)aExpired
{
    if (_isInternetAvailable())
        [self _setState:[CWManager isWeatherInternetStateOK] ? 1 : 2];
    else
        [self _setState:0];
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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_statusText release];
    [_accessibilityObjects release];
    [_progressIndicator release];
    _progressIndicator = nil;
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super initWithCityEntry:aEntry];
    if (self == nil)
        return nil;
    _progressIndicator = [[[self class] _progressIndicator] retain];
    [_progressIndicator setFrameOrigin:NSMakePoint(3.0, floorf((_sSizeForBestFit.height - [_progressIndicator frame].size.height) * 0.5f))];
    [self setAutoresizingMask:NSViewWidthSizable];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_reportsWereUpdated:) name:kCityEntryWasUpdatedViaOnlineNotification object:_entry];
    [center addObserver:self selector:@selector(_reportsWereExpired:) name:kCityEntryWasExpiredViaOnlineNotification object:_entry];
    [center addObserver:self selector:@selector(_acceptNeedStartAnimations:) name:@"NeedStartAnimationsNotification" object:nil];
    [center addObserver:self selector:@selector(_acceptNeedStopAnimations:) name:@"NeedStopAnimationsNotification" object:nil];
    [center addObserver:self selector:@selector(_weatherInternetStateWasChanged:) name:kWeatherInternetStateWasChangedNotification object:nil];
    if (_isInternetAvailable() && [self _isWeatherExpired])
        [self _setState:[CWManager isWeatherInternetStateOK] ? 1 : 2];
    return self;
}

@end
