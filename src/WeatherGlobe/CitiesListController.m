#import "CitiesListController.h"

static NSImage *_sortIndicator(int aSortingMode)
{
    switch (aSortingMode) {
    case 0:
    case 2:
        return [NSImage imageNamed:@"NSAscendingSortIndicator"];
    case 1:
    case 3:
        return [NSImage imageNamed:@"NSDescendingSortIndicator"];
    }
    return nil;
}

@implementation CitiesListController

- (void)tableViewSelectionDidChange:(id)aChange
{
    [FullCityInfoController refreshWithCityEntry:[self selectedItem]];
}

- (void)searchFieldAction:(id)aAction
{
    NSEvent *event = [[_filterTextField window] currentEvent];
    if ([event type] != NSEventTypeKeyDown && [event type] != NSEventTypeKeyUp)
        return;
    if ([[event characters] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n\003"]].location == NSNotFound)
        return;
    NSString *value = [_filterTextField stringValue];
    [[_filterTextField window] makeFirstResponder:_filterTextField];
    NSText *editor = [[_filterTextField window] fieldEditor:NO forObject:_filterTextField];
    [editor setSelectedRange:NSMakeRange(0, [value length])];
    if ([[event characters] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\003"]].location != NSNotFound) {
        [[_filterTextField window] performKeyEquivalent:event];
        return;
    }
    NSString *term = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([term isEqualToString:_searchString])
        return;
    [_searchString release];
    _searchString = [term copy];
    NSTimeInterval delay = [NSString fastLookupIsPossibleForSearchWithSubstring:term] ? 0.1 : 0.5;
    _defferedResearchTimer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(_renewSearchResults) userInfo:nil repeats:NO];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:_defferedResearchTimer forMode:NSDefaultRunLoopMode];
    [runLoop addTimer:_defferedResearchTimer forMode:NSModalPanelRunLoopMode];
}

- (void)controlTextDidChange:(id)aChange
{
    [_defferedResearchTimer invalidate];
    _defferedResearchTimer = nil;
    NSString *term = [[_filterTextField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![NSString fastLookupIsPossibleForSearchWithSubstring:term] && ([term length] != 0 || _showsAllEntries))
        return;
    [_searchString release];
    _searchString = [term copy];
    _defferedResearchTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(_renewSearchResults) userInfo:nil repeats:NO];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:_defferedResearchTimer forMode:NSDefaultRunLoopMode];
    [runLoop addTimer:_defferedResearchTimer forMode:NSModalPanelRunLoopMode];

    // autocomplete the last search term while typing
    NSText *editor = [[_filterTextField window] fieldEditor:NO forObject:_filterTextField];
    NSEvent *event = [[_filterTextField window] currentEvent];
    if ([event type] != NSEventTypeKeyDown)
        return;
    if ([[event characters] rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]].location == NSNotFound || editor == nil)
        return;
    NSArray *terms = [term separatedSearchTerms];
    if ([terms count] == 0)
        return;
    NSString *lastTerm = [terms objectAtIndex:[terms count] - 1];
    id request = [NSString autocompleteRequestForTerm:lastTerm];
    if (request == nil)
        return;
    NSArray *results = [[AtlasDatabase database] simpleSearchWithRequest:request];
    if ([results count] == 0)
        return;
    NSString *keyword = [[results objectAtIndex:0] objectForKey:@"kw"];
    if (keyword == nil || [keyword length] <= [lastTerm length])
        return;
    NSString *lastCharacter = [term substringWithRange:NSMakeRange([term length] - 1, 1)];
    if ([lastCharacter isEqualToString:[lastCharacter lowercaseString]])
        keyword = [keyword lowercaseString];
    NSString *completion = [keyword substringFromIndex:[lastTerm length]];
    [_filterTextField setStringValue:[NSString stringWithFormat:@"%@%@", term, completion]];
    [editor setSelectedRange:NSMakeRange([term length], [completion length])];
}

- (void)_renewSearchResults
{
    _defferedResearchTimer = nil;
    _isResearch = YES;
    [self invalCurrentEntries];
    [_citiesTableView reloadData];
    [_citiesTableView deselectAll:nil];
}

- (void)_applyFilterTextUndo:(id)aUndo
{
    [_filterTextField setStringValue:aUndo];
    [self controlTextDidChange:nil];
}

- (void)setDraggedEntries:(id)aEntries
{
    [aEntries retain];
    [_draggedEntries release];
    _draggedEntries = aEntries;
}

- (id)draggedEntries
{
    return _draggedEntries;
}

- (void)pasteboard:(id)aPasteboard provideDataForType:(id)aType
{
    [self provideCityEntriesDataForType:aType toPasteboard:aPasteboard];
}

- (void)tableView:(id)aView didClickTableColumn:(id)aColumn
{
    [aView setIndicatorImage:nil inTableColumn:[aView highlightedTableColumn]];
    if ([[aColumn identifier] isEqual:kCityColumnIdentifier])
        _sortingMode = _sortingMode == 0;
    else if ([[aColumn identifier] isEqual:kRegionColumnIdentifier])
        _sortingMode = (_sortingMode == 2) + 2;
    [aView setHighlightedTableColumn:aColumn];
    NSImage *indicator = [[aColumn identifier] isEqual:kMarkColumnIdentifier] ? nil : _sortIndicator(_sortingMode);
    [aView setIndicatorImage:indicator inTableColumn:aColumn];
    [[AtlasDatabase database] sortSearchResults:_searchResults mode:_sortingMode];
    [_searchedEntries release];
    _searchedEntries = nil;
    [_citiesTableView reloadData];
    [_citiesTableView deselectAll:nil];
}

- (BOOL)tableView:(id)aView writeRows:(id)aRows toPasteboard:(id)aPasteboard
{
    if (![_delegate respondsToSelector:@selector(dragIsSupportedForController:)] || ![_delegate dragIsSupportedForController:self])
        return NO;
    NSUInteger count = [aRows count];
    if (count - 1 >= 200)
        return NO;
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++)
        [entries addObject:[self searchedEntryAtIndex:[[aRows objectAtIndex:i] intValue] createIfNeeded:YES]];
    [self declareCitiesEntries:entries inPasteboard:aPasteboard withAdditionTypes:[NSArray arrayWithObject:kCitiesListPasteboardType]];
    return YES;
}

// current AppKit asks the index set version first
- (BOOL)tableView:(NSTableView *)aView writeRowsWithIndexes:(NSIndexSet *)aIndexes toPasteboard:(NSPasteboard *)aPasteboard
{
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger index;

    for (index = [aIndexes firstIndex]; index != NSNotFound; index = [aIndexes indexGreaterThanIndex:index])
        [rows addObject:[NSNumber numberWithInteger:index]];
    return [self tableView:aView writeRows:rows toPasteboard:aPasteboard];
}

- (id)tableView:(id)aView objectValueForTableColumn:(id)aColumn row:(NSInteger)aRow
{
    id entry = [self searchedEntryAtIndex:aRow createIfNeeded:YES];
    if ([[aColumn identifier] isEqual:kCityColumnIdentifier])
        return [entry ownName];
    if ([[aColumn identifier] isEqual:kRegionColumnIdentifier])
        return [entry regionName];
    if ([[aColumn identifier] isEqual:kMarkColumnIdentifier] && [_delegate respondsToSelector:@selector(cityIsMarked:)])
        return [NSNumber numberWithBool:[_delegate cityIsMarked:entry]];
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(id)aView
{
    return [[self currentSearchResults] count];
}

- (void)setDelegate:(id)aDelegate
{
    _delegate = aDelegate;
}

- (id)delegate
{
    return _delegate;
}

- (void)_markColumnAction:(id)aAction
{
    if (![_delegate respondsToSelector:@selector(markerColumnAction:forCity:)] || ![_delegate respondsToSelector:@selector(cityIsMarked:)])
        return;
    id entry = [self searchedEntryAtIndex:[_citiesTableView clickedRow] createIfNeeded:YES];
    [_delegate markerColumnAction:[NSNumber numberWithBool:![_delegate cityIsMarked:entry]] forCity:entry];
}

- (id)selectedItemsWithLimit:(NSInteger)aLimit createIfNeeded:(BOOL)aNeeded
{
    NSInteger count = [_citiesTableView numberOfSelectedRows];
    if (count < 1)
        return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:count];
    NSIndexSet *rows = [_citiesTableView selectedRowIndexes];
    for (NSUInteger row = [rows firstIndex]; row != NSNotFound; row = [rows indexGreaterThanIndex:row]) {
        id entry = [self searchedEntryAtIndex:row createIfNeeded:aNeeded];
        if (entry != nil)
            [items addObject:entry];
        if (aLimit > 0 && [items count] >= (NSUInteger)aLimit)
            break;
    }
    return items;
}

- (BOOL)singleItemIsSelected
{
    return [self _selectedRow] > 0;
}

- (id)selectedItem
{
    NSInteger row = [self _selectedRow];
    if (row < 0)
        return nil;
    return [self searchedEntryAtIndex:row createIfNeeded:YES];
}

- (void)setSearchTerm:(id)aTerm andRefreshResults:(BOOL)aResults
{
    [_filterTextField setStringValue:aTerm != nil ? aTerm : @""];
    if (aResults)
        [self controlTextDidChange:nil];
}

- (NSInteger)_selectedRow
{
    if ([_citiesTableView numberOfSelectedRows] > 1)
        return -1;
    return [_citiesTableView selectedRow];
}

- (void)reloadTableData
{
    [_citiesTableView reloadData];
}

- (id)citiesTableView
{
    return _citiesTableView;
}

- (void)loadNibIfNeeded
{
    if (!_nibWasLoaded && [NSBundle loadNibNamed:[self nibName] owner:self])
        _nibWasLoaded = YES;
}

- (void)dealloc
{
    [_draggedEntries release];
    [_previousFilterTextFieldContent release];
    [_sortedCityEntries release];
    [_defferedResearchTimer invalidate];
    [_searchResults release];
    [_allResults release];
    [_searchedEntries release];
    [_searchString release];
    [super dealloc];
}

- (void)awakeFromNib
{
    NSTableColumn *markColumn = [_citiesTableView tableColumnWithIdentifier:kMarkColumnIdentifier];
    if (markColumn != nil) {
        NSButtonCell *cell = [[[NSButtonCell alloc] init] autorelease];
        [markColumn setDataCell:cell];
        [cell setButtonType:NSButtonTypeSwitch];
        [cell setControlSize:NSControlSizeSmall];
        [cell setTarget:self];
        [cell setAction:@selector(_markColumnAction:)];
        [cell setTitle:nil];
    }
    NSTableColumn *cityColumn = [_citiesTableView tableColumnWithIdentifier:kCityColumnIdentifier];
    [_citiesTableView setHighlightedTableColumn:cityColumn];
    [_citiesTableView setIndicatorImage:_sortIndicator(_sortingMode) inTableColumn:cityColumn];
}

- (id)nibName
{
    return @"";
}

- (id)searchedEntryAtIndex:(NSInteger)aIndex createIfNeeded:(BOOL)aNeeded
{
    id entry = [_searchedEntries objectAtIndex:aIndex];
    if (entry != [NSNull null])
        return entry;
    if (!aNeeded)
        return nil;
    AtlasDatabase *database = [AtlasDatabase database];
    entry = [database dbEntryWithUID:[[_searchResults objectAtIndex:aIndex] objectForKey:kColumnNameUID]];
    [_searchedEntries replaceObjectAtIndex:aIndex withObject:entry];
    return entry;
}

- (id)currentSearchResults
{
    if (_searchResults == nil) {
        _showsAllEntries = [_searchString length] == 0;
        id request = [NSString searchForGeoObjectWithSubstring:_searchString];
        if (_showsAllEntries && _allResults != nil) {
            _searchResults = [_allResults retain];
        } else {
            _searchResults = [[[AtlasDatabase database] searchWithRequest:request sorting:_sortingMode] retain];
            if (_showsAllEntries)
                _allResults = [_searchResults retain];
        }
    }
    if (_searchedEntries == nil) {
        NSUInteger count = [_searchResults count];
        _searchedEntries = [[NSMutableArray alloc] initWithCapacity:count];
        NSNull *null = [NSNull null];
        for (NSUInteger i = 0; i < count; i++)
            [_searchedEntries addObject:null];
    }
    return _searchedEntries;
}

- (void)invalCurrentEntries
{
    [_sortedCityEntries release];
    _sortedCityEntries = nil;
    [_searchResults release];
    _searchResults = nil;
    [_searchedEntries release];
    _searchedEntries = nil;
}

@end
