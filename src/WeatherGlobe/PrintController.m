#import "PrintController.h"

// Prints the atlas: an options sheet chooses what the map shows and a
// title, and the printing view lays out the map pages (more of them at a
// print scale above 100%) followed by the distance list pages.

static BOOL _isOn(id aButton)
{
    return [aButton state] == NSControlStateValueOn;
}

@implementation PrintController

- (void)onCancel:(id)aCancel
{
    [self _clearUndo];
    [NSApp endSheet:_optionsWindow returnCode:0];
    [_optionsWindow orderOut:aCancel];
}

- (void)onPrint:(id)aPrint
{
    [[_editTitleField target] performSelector:[_editTitleField action] withObject:_editTitleField];
    [self _clearUndo];
    [NSApp endSheet:_optionsWindow returnCode:1];
    [_optionsWindow orderOut:aPrint];
}

- (void)showPrintOptionsModalForWindow:(id)aWindow modalDelegate:(id)aDelegate didEndSelector:(SEL)aSelector contextInfo:(void *)aInfo
{
    [self _loadNibIfNeeded];
    NSView *accessory = [self accessoryView];
    if ([accessory superview] != _accessoryContainer)
        [_accessoryContainer addSubview:accessory];
    [_accessoryContainer setNextKeyView:accessory];
    [_appleStoresCheckbox setNextKeyView:_cancelButton];
    [NSApp beginSheet:_optionsWindow modalForWindow:aWindow modalDelegate:aDelegate didEndSelector:aSelector contextInfo:aInfo];
}

// edits of the title are undoable; line breaks are refused
- (void)controlTextDidChange:(id)aChange
{
    NSString *title = [_editTitleField stringValue];
    if ([title isEqualToString:_previousTitleFieldContent])
        return;
    NSString *previous = _previousTitleFieldContent != nil ? [NSString stringWithString:_previousTitleFieldContent] : @"";
    if (![self _isTitleValid]) {
        [_editTitleField setStringValue:previous];
        NSBeep();
        return;
    }
    NSUndoManager *undoManager = [_optionsWindow undoManager];
    [undoManager registerUndoWithTarget:self selector:@selector(_applyTitleTextUndo:) object:previous];
    [undoManager setActionName:@""];
    [_previousTitleFieldContent release];
    _previousTitleFieldContent = [[NSString alloc] initWithString:title];
}

- (void)_applyTitleTextUndo:(id)aUndo
{
    [_editTitleField setStringValue:aUndo];
    [self controlTextDidChange:nil];
}

- (BOOL)_isTitleValid
{
    NSCharacterSet *breaks = [NSCharacterSet characterSetWithCharactersInString:@"\n\r\x03"];
    return [[_editTitleField stringValue] rangeOfCharacterFromSet:breaks].location == NSNotFound;
}

- (void)_clearUndo
{
    NSUndoManager *undoManager = [_optionsWindow undoManager];
    if (undoManager != nil) {
        [undoManager removeAllActionsWithTarget:self];
        [_previousTitleFieldContent release];
        _previousTitleFieldContent = nil;
    }
}

- (void)changeCustomTitle:(id)aTitle
{
    [_customTitleField setStringValue:[aTitle stringValue]];
}

- (void)toggleCalcList:(id)aList
{
    [self _enablePrinting];
}

- (void)toggleAppleStores:(id)aStores
{
    [_drawView setDrawsAppleStores:_isOn(aStores)];
    [self _enablePrinting];
}

- (void)toggleAllCities:(id)aCities
{
    [_drawView setDrawsAllCities:_isOn(aCities)];
    [self _enablePrinting];
}

- (void)toggleStateNames:(id)aNames
{
    [_drawView setDrawsStateNames:_isOn(aNames)];
}

- (void)toggleStateBorders:(id)aBorders
{
    BOOL on = _isOn(aBorders);
    [_drawView setDrawsStateBorders:on];
    [self _enableStateButtons:on];
    [self _enablePrinting];
}

- (void)toggleCountryNames:(id)aNames
{
    [_drawView setDrawsCountryNames:_isOn(aNames)];
}

- (void)toggleCountryBorders:(id)aBorders
{
    BOOL on = _isOn(aBorders);
    [_drawView setDrawsCountryBorders:on];
    [self _enableCountryButtons:on];
    [self _enablePrinting];
}

- (void)toggleGrid:(id)aGrid
{
    [_drawView setDrawsGrid:_isOn(aGrid)];
    [self _enablePrinting];
}

- (void)toggleRouteNames:(id)aNames
{
    [_drawView setDrawsRouteNames:_isOn(aNames)];
}

- (void)toggleRouteLines:(id)aLines
{
    [_drawView setDrawsRouteLines:_isOn(aLines)];
}

- (void)toggleRouteMarkers:(id)aMarkers
{
    BOOL on = _isOn(aMarkers);
    [_drawView setDrawsRouteMarkers:on];
    [self _enableRouteButtons:on];
    [self _enablePrinting];
}

- (void)toggleDayNight:(id)aNight
{
    [_drawView setDrawsDayNight:_isOn(aNight)];
}

- (void)toggleClouds:(id)aClouds
{
    [_drawView setDrawsClouds:_isOn(aClouds)];
}

- (void)toggleMap:(id)aMap
{
    BOOL on = _isOn(aMap);
    [_drawView setDrawsMap:on];
    [self _enableMapButtons:on];
    [self _enablePrinting];
}

// something must be selected to print
- (void)_enablePrinting
{
    [_printButton setEnabled:[self isPrintAtlas] || [self isPrintCalcList]];
}

- (id)printJobTitle
{
    return [_customTitleField stringValue];
}

// pages 1 to mapPageCount are the map, the rest the distance list
- (void)preparePage:(NSInteger)aPage
{
    if ([self mapPageCount] < aPage || ![self isPrintAtlas]) {
        if ([_drawView superview] != nil) {
            [_drawView removeFromSuperview];
            _drawView = nil;
            [[self containerView] setFrameSize:_viewSize];
            [self _adjustTextFieldsForMapView:NO];
        }
        if ([_calcListView superview] == nil) {
            NSRect frame = {NSZeroPoint, [_placeView frame].size};
            [_calcListView setFrame:frame];
            [_placeView addSubview:_calcListView];
        }
        [_calcListView preparePage:aPage - ([self isPrintAtlas] ? [self mapPageCount] : 0)];
        return;
    }
    if (!_needSetupDrawView && _drawView != nil)
        return;
    // the map is drawn larger and tiled over several pages
    NSSize size = _viewSize;
    if (_printScale > 1.0f) {
        size.width = (float)size.width * _printScale;
        size.height = _printScale * (float)size.height;
    }
    [[self containerView] setFrameSize:size];
    [self _adjustTextFieldsForMapView:YES];
    if ([_calcListView superview] != nil)
        [_calcListView removeFromSuperview];
    [self _setupDrawView];
}

- (NSInteger)pageCount
{
    NSSize size = [self containerViewSize];
    _printScale = [[[[_controller printInfo] dictionary] objectForKey:NSPrintScalingFactor] floatValue];
    [self _calcAdditionalScalesForSize:size];
    [self setContainerViewSize:size];
    NSInteger count = 0;
    if ([self isPrintAtlas]) {
        count = [self mapPageCount];
        _needSetupDrawView = YES;
    }
    if ([self isPrintCalcList]) {
        NSRect frame = {NSZeroPoint, [_placeView frame].size};
        [_calcListView setFrame:frame];
        [_calcListView setEntries:[_controller entriesOnMap]];
        [_calcListView setScaleCoef:_printScale * _additionalScale];
        count += [_calcListView pageCount];
    }
    return count;
}

- (CGFloat)printScale
{
    return _printScale;
}

// a square of pages per whole step of the print scale
- (NSInteger)mapPageCount
{
    int side = (int)(_printScale - 0.001f) + 1;
    return side * side;
}

- (void)printOperationDidRun:(id)aRun success:(BOOL)aSuccess contextInfo:(void *)aInfo
{
    [_drawView invalidateCashes];
}

- (void)_setupDrawView
{
    if (_mapMode == 0)
        [self _setDrawViewOfClass:[SphereDrawView class]];
    else if (_mapMode == 1)
        [self _setDrawViewOfClass:[FlatDrawView class]];
}

- (void)setMapMode:(NSInteger)aMode
{
    _mapMode = (int)aMode;
}

// below 100% the map is shrunk in the middle of its place
- (void)_setDrawViewOfClass:(Class)aClass
{
    if (![_drawView isMemberOfClass:aClass]) {
        [_drawView removeFromSuperview];
        _drawView = [[aClass alloc] initWithFrame:[_placeView bounds]];
        [_drawView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [_drawView setAtlasPanelController:[_controller currentPanelController]];
        [_placeView addSubview:_drawView];
        [_drawView release];
    }
    NSRect frame = [_placeView bounds];
    float scale = _printScale;
    if (scale < 1.0f) {
        float width = (float)frame.size.width, height = (float)frame.size.height;
        frame.size.width = scale * width;
        frame.origin.x = ceilf((width - (float)frame.size.width) * 0.5f);
        frame.origin.y = ceilf((height - scale * height) * 0.5f);
        frame.size.height = scale * height;
    }
    [_drawView setFrame:frame];
    [_drawView setScale:_printScale * _additionalScale];
    [_drawView setDrawsMap:_isOn(_mapCheckbox)];
    [_drawView setDrawsClouds:_isOn(_cloudsCheckbox)];
    [_drawView setDrawsDayNight:_isOn(_dayNightCheckbox)];
    [_drawView setDrawsGrid:_isOn(_gridCheckbox)];
    [_drawView setDrawsCountryBorders:_isOn(_countryBordersCheckbox)];
    [_drawView setDrawsCountryNames:_isOn(_countryNamesCheckbox)];
    [_drawView setDrawsStateBorders:_isOn(_stateBordersCheckbox)];
    [_drawView setDrawsStateNames:_isOn(_stateNamesCheckbox)];
    [_drawView setDrawsAllCities:_isOn(_allCitiesCheckbox)];
    [_drawView setDrawsRouteMarkers:_isOn(_routeMarkersCheckbox)];
    [_drawView setDrawsRouteLines:_isOn(_routeLinesCheckbox)];
    [_drawView setDrawsRouteNames:_isOn(_routeNamesCheckbox)];
    [_drawView setDrawsAppleStores:_isOn(_appleStoresCheckbox)];
    _needSetupDrawView = NO;
}

- (void)setContainerViewSize:(NSSize)aSize
{
    _viewSize = aSize;
    [[self containerView] setFrameSize:_viewSize];
    [self _adjustTextFieldsForMapView:NO];
}

// the paper's printable area
- (NSSize)containerViewSize
{
    NSPrintInfo *printInfo = [_controller printInfo];
    NSSize paper = [printInfo paperSize];
    return NSMakeSize((float)paper.width - ((float)[printInfo leftMargin] + (float)[printInfo rightMargin]),
                      (float)paper.height - ((float)[printInfo topMargin] + (float)[printInfo bottomMargin]));
}

// Title image at the top, the custom title under it, the copyright line at
// the bottom and the map or list in between.
- (void)_adjustTextFieldsForMapView:(BOOL)aView
{
    NSRect frame = [[self containerView] frame];
    float width = (float)frame.size.width, height = (float)frame.size.height;
    NSString *title = [_customTitleField stringValue];
    float titleImageWidth = _additionalScaleForTitle * (float)_defaultTitleImageSize.width;
    float titleImageHeight = _additionalScaleForTitle * (float)_defaultTitleImageSize.height;
    [_customTitleField setFont:[NSFont boldSystemFontOfSize:_defaultCustomTitleFontSize * _printScale * _additionalScaleForCustomTitle]];
    float titleWidth, titleHeight;
    if (title != nil && [title length] != 0) {
        titleHeight = _defaultCustomTitleFieldHeight * _printScale * _additionalScaleForCustomTitle;
        titleWidth = width;
    } else {
        titleHeight = (float)NSZeroSize.height;
        titleWidth = (float)NSZeroSize.width;
    }
    [_copyrightField setFont:[NSFont systemFontOfSize:_defaultCopyrightFontSize * _additionalScaleForTitle]];
    float copyrightHeight = (float)_defaultCopyrightFieldSize.height * _additionalScaleForTitle;
    [_titleImage setFrame:NSMakeRect((width - titleImageWidth) * 0.5f, height - titleImageHeight, titleImageWidth, titleImageHeight)];
    [_titleImage setBounds:NSMakeRect(0.0, 0.0, titleImageWidth / _printScale, titleImageHeight / _printScale)];
    [_customTitleField setFrame:NSMakeRect(0.0, height - (titleImageHeight + titleHeight + _additionalScaleForCustomTitle * 8.0f), titleWidth, titleHeight)];
    [_copyrightField setFrame:NSMakeRect(0.0, 5.0, width, copyrightHeight)];
    [_placeView setFrame:NSMakeRect(frame.origin.x, copyrightHeight * 1.25f + 5.0f + (float)frame.origin.y, width,
                                    height - (_additionalScaleForCustomTitle * 8.0f + titleImageHeight * 1.25f + copyrightHeight * 1.25f + titleHeight + 5.0f))];
}

// Scales that shrink the titles to fit the page width, and the map and
// list to fit a page smaller than A4/Letter.
- (void)_calcAdditionalScalesForSize:(NSSize)aSize
{
    float pageWidth = (float)aSize.width, pageHeight = (float)aSize.height;
    [_customTitleField setFont:[NSFont boldSystemFontOfSize:_printScale * _defaultCustomTitleFontSize]];
    float titleWidth = (float)[[_customTitleField cell] cellSize].width + 1.0f;
    float scale = pageWidth < titleWidth ? pageWidth / titleWidth : 1.0f;
    _additionalScaleForCustomTitle = scale;
    if (scale < 1.0f) {
        float shrunk = pageWidth / (titleWidth + (1.0f - scale) * 50.0f);
        _additionalScaleForCustomTitle = shrunk;
        float fontSize = _defaultCustomTitleFontSize * _printScale * shrunk;
        if (fontSize < 1.0f)
            _additionalScaleForCustomTitle = shrunk / fontSize;
    }
    float widest = (float)_defaultTitleImageSize.width;
    if (widest <= (float)_defaultCopyrightFieldSize.width)
        widest = (float)_defaultCopyrightFieldSize.width;
    _additionalScaleForTitle = pageWidth < widest ? pageWidth / widest : 1.0f;
    if (pageHeight <= pageWidth)
        _additionalScale = pageHeight < 722.0f ? pageHeight / 722.0f : 1.0f;
    else
        _additionalScale = pageWidth < 552.0f ? pageWidth / 552.0f : 1.0f;
}

- (id)accessoryView
{
    [self _loadNibIfNeeded];
    [self _updateControls];
    return _accessoryView;
}

- (id)containerView
{
    [self _loadNibIfNeeded];
    return _containerView;
}

- (void)_loadNibIfNeeded
{
    if (_containerView == nil)
        [NSBundle loadNibNamed:@"PrintLayout.nib" owner:self];
}

// The options start from what the map shows; the title is the route's
// file name, the city, the route's ends or "Untitled".
- (void)_updateControls
{
    NSArray *entries = [_controller entriesOnMap];
    BOOL hasEntries = [entries count] != 0;
    [self setPrintMap:_isPrintAtlas];
    [self setPrintRoute:_isPrintAtlas && hasEntries];
    [self setPrintGrid:_isPrintAtlas && [Preferences gridEnabled]];
    NSInteger mode = [Preferences regionHighLightMode];
    BOOL regions = [Preferences regionHighlightIsEnabled];
    [self setPrintCountries:_isPrintAtlas && regions && mode <= 1];
    [self setPrintStates:_isPrintAtlas && regions && (mode == 0 || mode == 2)];
    [self setPrintAllCities:_isPrintAtlas && [Preferences doDrawAllCities]];
    [self setPrintAppleStores:_isPrintAtlas && [_controller showsApples]];
    [_routeMarkersCheckbox setEnabled:hasEntries];
    [_calcListCheckbox setState:hasEntries && _isPrintCalcList];
    [_calcListCheckbox setEnabled:hasEntries];
    NSString *title;
    if (![_controller currentPathNameIsInvalid] && [_controller currentRoutePath] != nil) {
        title = [[[_controller currentRoutePath] lastPathComponent] stringByDeletingPathExtension];
    } else {
        entries = [_controller entriesOnMap];
        if ([entries count] == 1) {
            id entry = [entries objectAtIndex:0];
            NSString *region = [entry regionName];
            if (region == nil)
                title = [NSString stringWithFormat:@"%@", [entry ownName]];
            else
                title = [NSString stringWithFormat:@"%@ (%@)", [entry ownName], region];
        } else if ([entries count] >= 2) {
            title = [NSString stringWithFormat:@"%@ - %@ Route", [[entries objectAtIndex:0] ownName], [[entries lastObject] ownName]];
        } else {
            title = [[NSBundle mainBundle] localizedStringForKey:@"Untitled" value:@"" table:nil];
        }
    }
    [_editTitleField setStringValue:title];
    [_previousTitleFieldContent release];
    _previousTitleFieldContent = [[NSString alloc] initWithString:title];
    [_customTitleField setStringValue:[_editTitleField stringValue]];
    [_copyrightField setStringValue:[[NSBundle mainBundle] copyrightString]];
}

- (void)setPrintCalcList:(BOOL)aList
{
    _isPrintCalcList = aList;
}

- (BOOL)isPrintCalcList
{
    return _isOn(_calcListCheckbox);
}

- (void)setPrintAtlas:(BOOL)aAtlas
{
    _isPrintAtlas = aAtlas;
}

// the map prints if anything on it is selected
- (BOOL)isPrintAtlas
{
    return _isOn(_mapCheckbox) || _isOn(_gridCheckbox) || _isOn(_countryBordersCheckbox) || _isOn(_stateBordersCheckbox)
        || _isOn(_allCitiesCheckbox) || _isOn(_appleStoresCheckbox) || _isOn(_routeMarkersCheckbox);
}

- (void)setPrintAppleStores:(BOOL)aStores
{
    [_appleStoresCheckbox setState:aStores];
}

- (void)setPrintAllCities:(BOOL)aCities
{
    [_allCitiesCheckbox setState:aCities];
}

- (void)setPrintStates:(BOOL)aStates
{
    [_stateBordersCheckbox setState:aStates != NO];
    [_stateNamesCheckbox setState:NSControlStateValueOff];
    [self _enableStateButtons:aStates];
}

- (void)setPrintCountries:(BOOL)aCountries
{
    [_countryBordersCheckbox setState:aCountries != NO];
    [_countryNamesCheckbox setState:NSControlStateValueOff];
    [self _enableCountryButtons:aCountries];
}

- (void)setPrintGrid:(BOOL)aGrid
{
    [_gridCheckbox setState:aGrid];
}

- (void)setPrintRoute:(BOOL)aRoute
{
    [_routeMarkersCheckbox setState:aRoute != NO];
    [_routeLinesCheckbox setState:aRoute && [Preferences showRouteLines]];
    [_routeNamesCheckbox setState:aRoute && [Preferences showLocationNamesEnabled]];
    [self _enableRouteButtons:aRoute];
}

- (void)setPrintMap:(BOOL)aMap
{
    [_mapCheckbox setState:aMap != NO];
    [_cloudsCheckbox setState:aMap && [Preferences cloudsEnabled]];
    [_dayNightCheckbox setState:aMap && [Preferences dayNightIsEnabled]];
    [self _enableMapButtons:aMap];
}

- (void)_enableStateButtons:(BOOL)aButtons
{
    [_stateNamesCheckbox setEnabled:aButtons];
}

- (void)_enableCountryButtons:(BOOL)aButtons
{
    [_countryNamesCheckbox setEnabled:aButtons];
}

- (void)_enableRouteButtons:(BOOL)aButtons
{
    [_routeLinesCheckbox setEnabled:aButtons];
    [_routeNamesCheckbox setEnabled:aButtons];
}

- (void)_enableMapButtons:(BOOL)aButtons
{
    [_cloudsCheckbox setEnabled:aButtons];
    [_dayNightCheckbox setEnabled:aButtons];
}

- (void)dealloc
{
    [_containerView release];
    [_accessoryView release];
    [_calcListView release];
    [_previousTitleFieldContent release];
    [super dealloc];
}

// the nib's sizes are the defaults the scales apply to
- (void)awakeFromNib
{
    [_containerView setPrintController:self];
    _defaultTitleImageSize = [_titleImage frame].size;
    _defaultCopyrightFontSize = (float)[[_copyrightField font] pointSize];
    _defaultCopyrightFieldSize = [_copyrightField frame].size;
    _defaultCustomTitleFontSize = (float)[[_customTitleField font] pointSize];
    _defaultCustomTitleFieldHeight = (float)[_customTitleField frame].size.height;
    [_optionsWindow setExcludedFromWindowsMenu:YES];
}

- (id)initWithSize:(NSSize)aSize controller:(id)aController
{
    self = [super init];
    if (self != nil) {
        _viewSize = aSize;
        _controller = aController;
    }
    return self;
}

@end
