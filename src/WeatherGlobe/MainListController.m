#import "MainListController.h"

@implementation MainListController

// Marks the selection on the map, or unmarks it when most of it is already marked.
- (void)tableView:(id)aView requestedToMarkRows:(id)aRows
{
    if ([_citiesTableView numberOfSelectedRows] <= 0 || ![_delegate respondsToSelector:@selector(cityIsMarked:)])
        return;
    NSArray *cities = [self selectedItemsWithLimit:400 createIfNeeded:YES];
    NSUInteger count = [cities count], i;
    NSMutableArray *marked = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *unmarked = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
        id city = [cities objectAtIndex:i];
        [[_delegate cityIsMarked:city] ? marked : unmarked addObject:city];
    }
    if ([marked count] > [unmarked count])
        [_mainController deleteCitiesFromDistCalcList:marked];
    else
        [_mainController appendCitiesToDistCalcList:unmarked];
}

- (BOOL)_selectionHasCityMarked:(BOOL)aMarked
{
    if (![_delegate respondsToSelector:@selector(cityIsMarked:)])
        return NO;
    NSIndexSet *rows = [_citiesTableView selectedRowIndexes];
    NSUInteger row;
    for (row = [rows firstIndex]; row != NSNotFound; row = [rows indexGreaterThanIndex:row]) {
        id city = [self searchedEntryAtIndex:row createIfNeeded:NO];
        if (city != nil && (BOOL)[_delegate cityIsMarked:city] == aMarked)
            return YES;
    }
    return NO;
}

- (BOOL)validateMenuItem:(id)aItem
{
    NSInteger selected = [_citiesTableView numberOfSelectedRows];
    switch ([aItem tag]) {
    case 0:
        return selected > 0 && [self _selectionHasCityMarked:NO];
    case 1:
        return selected > 0 && [self _selectionHasCityMarked:YES];
    case 2:
        return selected > 0;
    case 3:
    case 4:
        return [self singleItemIsSelected];
    }
    return YES;
}

- (void)lookupInWorldBookMaps:(id)aMaps
{
    [self _performURLServiceWithString:@"worldbook:action@search/maps/"];
}

- (void)lookupInWorldBookArticles:(id)aArticles
{
    [self _performURLServiceWithString:@"worldbook:action@search/topic/"];
}

- (void)_performURLServiceWithString:(id)aString
{
    NSString *name = [self _escapeSequenceString:[[self selectedItem] ownName]];
    NSURL *url = [NSURL URLWithString:[aString stringByAppendingString:name]];
    if (![[NSWorkspace sharedWorkspace] openURL:url]) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSRunAlertPanel([bundle localizedStringForKey:@"Cannot launch World Book title" value:@"" table:nil],
                        @"%@", [bundle localizedStringForKey:@"Ok" value:@"" table:nil], nil, nil,
                        [bundle localizedStringForKey:@"Cannot launch World Book message" value:@"" table:nil]);
    }
}

- (id)_escapeSequenceString:(id)aString
{
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)aString, NULL, NULL,
                                                                kCFStringEncodingUTF8) autorelease];
}

- (void)deleteFromMapAction:(id)aAction
{
    if ([_citiesTableView numberOfSelectedRows] > 0)
        [_mainController deleteCitiesFromDistCalcList:[self selectedItemsWithLimit:0 createIfNeeded:NO]];
}

- (void)putOnMapAction:(id)aAction
{
    if ([_citiesTableView numberOfSelectedRows] > 0)
        [_mainController appendCitiesToDistCalcList:[self selectedItemsWithLimit:202 createIfNeeded:YES]];
}

@end
