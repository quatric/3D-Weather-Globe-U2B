#import "CityInfoController.h"

@implementation CityInfoController

+ (id)optionsMenuItems
{
    NSArray *lines = [self _allPropertyViewClasses];
    NSMutableArray *items = [NSMutableArray array];
    NSInteger count = [lines count];
    for (NSInteger i = 0; i < count; i++) {
        NSArray *classes = [lines objectAtIndex:i];
        NSInteger classCount = [classes count];
        for (NSInteger j = 0; j < classCount; j++)
            [items addObject:[[classes objectAtIndex:j] optionsMenuItems]];
    }
    return items;
}

- (void)_manualUpdateWeather:(id)aWeather
{
    [_entry manualUpdateOfScheduledReports];
}

- (void)_acceptNeedCreateImage:(id)aImage
{
    [_mainView setNeedsCreateImage];
}

- (void)_acceptMainViewSizeChanged:(id)aChanged
{
    [self _allignViews];
}

- (id)accessibilityObjects
{
    return _accessibilityObjects;
}

- (void)reconstructMainView
{
    [_mainView setPostsFrameChangedNotifications:NO];
    _sizeForBestFit = NSZeroSize;
    NSInteger lineCount = [_cityPropertyViews count];
    for (NSInteger i = 0; i < lineCount; i++) {
        NSArray *views = [_cityPropertyViews objectAtIndex:i];
        NSView *container = [_lineViewsContainers objectAtIndex:i];
        NSSize lineSize = NSZeroSize;
        NSInteger count = [views count];
        for (NSInteger j = 0; j < count; j++) {
            id view = [views objectAtIndex:j];
            if ([view enabled]) {
                NSSize size = [view sizeForBestFit];
                lineSize.width += size.width;
                if (size.height > lineSize.height)
                    lineSize.height = size.height;
            }
        }
        if (!NSEqualSizes(lineSize, [container frame].size)) {
            [_contentView setNeedsDisplayInRect:[container frame]];
            [container setFrameSize:lineSize];
        }
        CGFloat x = 0.0;
        for (NSInteger j = 0; j < count; j++) {
            id view = [views objectAtIndex:j];
            if (![view enabled]) {
                [view removeFromSuperview];
                continue;
            }
            if ([view superview] != container)
                [container addSubview:view];
            NSSize size = [view sizeForBestFit];
            [view setFrame:NSMakeRect(x, ceilf((lineSize.height - size.height) * 0.5f), size.width, size.height)];
            x += size.width;
        }
        if (lineSize.height == 0.0) {
            [container removeFromSuperview];
        } else {
            _sizeForBestFit.height = lineSize.height + _sizeForBestFit.height;
            _sizeForBestFit.width = MAX(lineSize.width, _sizeForBestFit.width);
            if ([container superview] != _contentView)
                [_contentView addSubview:container];
        }
    }
    _sizeForBestFit.width = (int)_sizeForBestFit.width + 1;
    _sizeForBestFit.height = (int)_sizeForBestFit.height + 1;
    [_contentView setFrameSize:_sizeForBestFit];
    [_mainView setAutoresizesSubviews:NO];
    [_mainView setFrameFromContentFrame:[_contentView frame]];
    [_mainView setAutoresizesSubviews:YES];
    _sizeForBestFit = [_mainView frame].size;
    [self _allignViews];
    [_mainView setPostsFrameChangedNotifications:YES];
}

- (void)setMenu:(id)aMenu
{
    [_mainView setMenu:aMenu];
    [_contentView setMenu:aMenu];
    [_lineViewsContainers makeObjectsPerformSelector:@selector(setMenu:) withObject:aMenu];
    NSInteger count = [_cityPropertyViews count];
    for (NSInteger i = 0; i < count; i++)
        [[_cityPropertyViews objectAtIndex:i] makeObjectsPerformSelector:@selector(setMenu:) withObject:aMenu];
}

- (id)cityEntry
{
    return _entry;
}

- (NSSize)sizeForBestFit
{
    return _sizeForBestFit;
}

- (id)mainView
{
    return _mainView;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_accessibilityObjects release];
    [_mainView release];
    [_contentView release];
    [_lineViewsContainers release];
    [_cityPropertyViews release];
    [_entry release];
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    if (aEntry == nil) {
        [self release];
        return nil;
    }
    self = [super init];
    if (self != nil) {
        _entry = [aEntry retain];
        [self _createAllViews];
        [self reconstructMainView];
    }
    return self;
}

@end

@implementation NSView (Extension)

- (BOOL)acceptsFirstMouse:(id)aMouse
{
    return YES;
}

@end

@implementation CityInfoController (Private)

+ (id)_allPropertyViewClasses
{
    NSArray *statusLine = [NSArray arrayWithObjects:[CPStatusBarView class], nil];
    NSArray *forecastLine = [NSArray arrayWithObjects:[CPExpandedForecastView class], nil];
    NSArray *mainLine = [NSArray arrayWithObjects:[CPMainPropertyView class], [CPCurrentConditionsView class], nil];
    return [NSArray arrayWithObjects:mainLine, forecastLine, statusLine, nil];
}

- (void)_allignViews
{
    NSRect contentFrame = [_contentView frame];
    NSInteger count = [_lineViewsContainers count];
    CGFloat top = contentFrame.size.height;
    for (NSInteger i = 0; i < count; i++) {
        NSView *container = [_lineViewsContainers objectAtIndex:i];
        CGFloat height = [container frame].size.height;
        [container setFrame:NSMakeRect(0, top - height, contentFrame.size.width, height)];
        top -= height;
    }
    [_mainView setNeedsCreateImage];
}

- (void)_createAllViews
{
    _cityPropertyViews = [[self _allPropertyViews] retain];
    _contentView = [NSView new];
    [_contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_contentView setPostsFrameChangedNotifications:NO];
    _mainView = [CityInfoView new];
    [_mainView setTitlePosition:NSNoTitle];
    [_mainView setContentView:_contentView];
    [_mainView setOwner:self];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_acceptMainViewSizeChanged:) name:kCIViewSizeDidChangeNotification object:_mainView];
    [center addObserver:self selector:@selector(_acceptNeedCreateImage:) name:@"NeedCreateImageNotification" object:_entry];
    [center addObserver:self selector:@selector(_manualUpdateWeather:) name:@"ManualUpdateWeatherNotification" object:nil];
}

- (id)_allPropertyViews
{
    NSArray *lines = [CityInfoController _allPropertyViewClasses];
    NSMutableArray *views = [NSMutableArray array];
    NSMutableArray *containers = [NSMutableArray new];
    NSMutableArray *accessibility = [NSMutableArray new];
    NSInteger count = [lines count];
    for (NSInteger i = 0; i < count; i++) {
        NSView *container;
        if (i == 0 || i == count - 1) {
            CIBackgroundImageView *background = [[CIBackgroundImageView new] autorelease];
            [background setImage:[NSImage imageNamed:i == 0 ? @"city_info_title" : @"city_info_status_bar"]];
            [background setImageViewStyle:0];
            [background setImageScaling:NSImageScaleAxesIndependently];
            container = background;
        } else {
            container = [[NSView new] autorelease];
        }
        [containers addObject:container];
        NSArray *classes = [lines objectAtIndex:i];
        NSMutableArray *lineViews = [NSMutableArray array];
        NSInteger classCount = [classes count];
        for (NSInteger j = 0; j < classCount; j++) {
            id view = [[[[classes objectAtIndex:j] alloc] initWithCityEntry:_entry] autorelease];
            [lineViews addObject:view];
            [accessibility addObject:view];
        }
        [views addObject:lineViews];
    }
    _lineViewsContainers = containers;
    _accessibilityObjects = accessibility;
    return views;
}

@end
