#import "CICitiesListController.h"

@implementation CICitiesListController

- (void)_doubleAction:(id)aAction
{
    [FullCityInfoController showWithCityEntry:[self selectedItem]];
}

- (void)acceptAction:(id)aAction
{
    NSMutableArray *entries = [NSMutableArray array];
    NSArray *cities = [self selectedItemsWithLimit:[Preferences citiesCountLimit] * 2 createIfNeeded:YES];
    NSUInteger count = [cities count], i;
    for (i = 0; i < count; i++)
        [entries addObject:[[cities objectAtIndex:i] entryDictionary]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AddCitiesNotification" object:entries userInfo:nil];
}

- (void)showCityDetails:(id)aDetails
{
    [FullCityInfoController showWithCityEntry:[self selectedItem]];
}

- (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(showCityDetails:))
        return [_window isKeyWindow] && [self selectedItem] != nil;
    return YES;
}

- (void)hideWindow
{
    [_window performClose:self];
}

- (void)showWindow
{
    [self loadNibIfNeeded];
    [NSApp activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:self];
}

- (id)nibName
{
    return @"CitiesListWindow";
}

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [_citiesTableView setDoubleAction:@selector(_doubleAction:)];
    [_window center];
    [_window setLevel:CGWindowLevelForKey(kCGFloatingWindowLevelKey)];
    [_window setExcludedFromWindowsMenu:YES];
    [_window setHidesOnDeactivate:YES];
}

@end
