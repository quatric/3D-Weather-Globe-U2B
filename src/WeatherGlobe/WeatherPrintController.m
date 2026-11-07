#import "WeatherPrintController.h"

@implementation WeatherPrintController

+ (void)printCities:(id)aCities
{
    [[[[WeatherPrintController alloc] initWithCities:aCities] autorelease] doPrint:nil];
}

- (void)doPrint:(id)aPrint
{
    [self _loadNibIfNeeded];
    [[NSPrintOperation printOperationWithView:_pageView] runOperation];
}

- (void)preparePage:(NSInteger)aPage
{
    NSInteger pagesPerCity = [_data pagesCountForPageSize:[_containerView bounds].size];
    [_currentView removeFromSuperview];
    _currentView = [_data pageAtIndex:(aPage - 1) % pagesPerCity];
    [_containerView addSubview:_currentView];
    [_data setValuesFrom:[_cityEntries objectAtIndex:(aPage - 1) / pagesPerCity]];
}

- (NSInteger)pageCount
{
    [_pageView setFrameSize:[self _pageSize]];
    [self _adjustTextFields];
    float scale = [[[[NSPrintInfo sharedPrintInfo] dictionary] objectForKey:NSPrintScalingFactor] floatValue];
    [_titleImage scaleUnitSquareToSize:NSMakeSize(scale, scale)];
    [_containerView scaleUnitSquareToSize:NSMakeSize(scale, scale)];
    float additional = (float)[_data additionalScaleForPageSize:[_containerView bounds].size];
    [_containerView scaleUnitSquareToSize:NSMakeSize(additional, additional)];
    NSInteger count = [_cityEntries count];
    return count * [_data pagesCountForPageSize:[_containerView bounds].size];
}

- (id)printJobTitle
{
    NSString *format = [_cityEntries count] < 2 ? @"%@ " : @"%@ - %@ ";
    format = [format stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Weather Details" value:@"" table:nil]];
    return [NSString stringWithFormat:format, [[_cityEntries objectAtIndex:0] ownName], [[_cityEntries lastObject] ownName]];
}

- (void)setCities:(id)aCities
{
    [_cityEntries removeAllObjects];
    NSInteger count = [aCities count];
    for (NSInteger i = 0; i < count; i++) {
        id city = [aCities objectAtIndex:i];
        if ([city isKindOfClass:[YACityEntry class]])
            [_cityEntries addObject:city];
    }
}

- (void)_adjustTextFields
{
    float scale = (float)[self _additionalScale];
    NSRect pageFrame = [_pageView frame];
    float titleWidth = scale * _defaultTitleImageSize.width;
    float titleHeight = scale * _defaultTitleImageSize.height;
    [_copyrightField setFont:[NSFont systemFontOfSize:scale * _defaultCopyrightFontSize]];
    CGFloat copyrightHeight = [[_copyrightField cell] cellSize].height;
    [_titleImage setFrame:NSMakeRect((pageFrame.size.width - titleWidth) * 0.5f, pageFrame.size.height - titleHeight, titleWidth, titleHeight)];
    [_copyrightField setFrame:NSMakeRect(0, 0, pageFrame.size.width, copyrightHeight)];
    [_containerView setFrame:NSMakeRect(pageFrame.origin.x,
                                        copyrightHeight + scale * 8.0f + pageFrame.origin.y,
                                        pageFrame.size.width,
                                        pageFrame.size.height - (scale * 16.0f + titleHeight + copyrightHeight))];
}

- (CGFloat)_additionalScale
{
    CGFloat width = [_pageView frame].size.width;
    if (width < _defaultTitleImageSize.width)
        return width / _defaultTitleImageSize.width;
    return 1.0;
}

- (NSSize)_pageSize
{
    NSPrintInfo *printInfo = [[[AtlasController atlasController] mainWindowController] printInfo];
    NSSize paper = [printInfo paperSize];
    float left = [printInfo leftMargin];
    float right = [printInfo rightMargin];
    float top = [printInfo topMargin];
    float bottom = [printInfo bottomMargin];
    return NSMakeSize(floorf((float)paper.width - (left + right)), floorf((float)paper.height - (top + bottom)));
}

- (void)_loadNibIfNeeded
{
    if (!_nibWasLoaded) {
        if ([NSBundle loadNibNamed:@"WeatherPrintLayout" owner:self])
            _nibWasLoaded = YES;
    }
}

- (void)dealloc
{
    [_data release];
    [_pageView release];
    [_cityEntries release];
    [super dealloc];
}

- (id)initWithCities:(id)aCities
{
    self = [super init];
    if (self != nil) {
        _cityEntries = [NSMutableArray new];
        [self setCities:aCities];
    }
    return self;
}

- (void)awakeFromNib
{
    _defaultTitleImageSize = [_titleImage frame].size;
    _defaultCopyrightFontSize = [[_copyrightField font] pointSize];
}

@end
