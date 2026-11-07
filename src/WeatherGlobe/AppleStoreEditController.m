#import "AppleStoreEditController.h"

static AppleStoreEditController *__staticController;
static NSString *const kAppleStoreEditSourceFile =
    @"/Users/3dwgbuilder/Projects/3DWGBuildFolder/WBAll/WBAtlas/Sources/AppleStoreEditingPanel/AppleStoreEditController.m";

@implementation AppleStoreEditController

+ (BOOL)isAppleStoreEditPanelVisible
{
    return __staticController != nil && [[__staticController window] isVisible];
}

+ (void)hideAppleStoreEditPanel
{
    if (__staticController != nil && [[__staticController window] isVisible])
        [[__staticController window] performClose:self];
}

+ (void)showAppleStoreEditPanelWithEntry:(id)aEntry mainController:(id)aController
{
    if (__staticController == nil)
        __staticController = [[AppleStoreEditController alloc] initWithWindowNibName:@"AppleStorePanel"];
    else if ([[__staticController window] isVisible] && ![__staticController saveValues])
        return;
    __staticController->_mainController = aController;
    NSWindow *window = [__staticController window];
    if (aEntry != nil) {
        __staticController->_entry = aEntry;
        if ([aEntry isKindOfClass:[AppleStoreEntry class]] && [aEntry address] != nil) {
            [__staticController replaceEntryWithAppleStoreIfNeeded];
            [__staticController showPanel];
            [window makeKeyAndOrderFront:nil];
            return;
        }
    }
    [AppleStoreEditController hideAppleStoreEditPanel];
}

- (void)deleteButtonAction:(id)aAction
{
    [AppleStoreEditController hideAppleStoreEditPanel];
    [_mainController deleteSelectedEntryFromDistCalcList];
}

- (NSDictionary *)_newStoreRepWithName:(NSString *)aName coordinates:(NSPoint)aPoint
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
        aName, kCityEntryName,
        @"Alternative Name", kAppleStoreListEntryAlternativeName,
        [NSNumber numberWithFloat:aPoint.x], kCityEntryLong,
        [NSNumber numberWithFloat:aPoint.y], kCityEntryLat,
        @"Address", kAppleStoreListEntryAddress,
        @"http://", kAppleStoreListEntryURL,
        @"Open", kAppleStoreListEntryAdditionalInfo,
        [NSNumber numberWithInt:0], kAppleStoreListEntryMarkerSize,
        @"Apple Store", kAppleStoreListEntryInfoPaletteTitle,
        nil];
}

- (void)newButtonAction:(id)aAction
{
    NSMutableDictionary *rep = [NSMutableDictionary dictionaryWithDictionary:
        [self _newStoreRepWithName:@"City Name" coordinates:NSZeroPoint]];
    [rep setObject:[[NSBundle mainBundle] localizedStringForKey:@"AppleIconCharacter" value:@"" table:nil]
            forKey:kAppleStoreListEntryMarkerString];
    [rep setObject:[NSNumber numberWithFloat:0.4f] forKey:kAppleStoreListEntryMarkerColorR];
    [rep setObject:[NSNumber numberWithFloat:0.7f] forKey:kAppleStoreListEntryMarkerColorG];
    [rep setObject:[NSNumber numberWithFloat:1.0f] forKey:kAppleStoreListEntryMarkerColorB];
    [rep setObject:[NSNumber numberWithFloat:1.0f] forKey:kAppleStoreListEntryMarkerColorA];
    [_mainController appendCityToDistCalcList:[AppleStoreEntry entryWithDictionaryRep:rep]];
}

- (void)nexButtonAction:(id)aAction
{
    if (![self saveValues])
        return;
    NSArray *entries = [_mainController entriesOnMap];
    NSUInteger index = [entries indexOfObject:_entry];
    if (index == NSNotFound || index == [entries count] - 1)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:kAppleStoreEditSourceFile
            lineNumber:0xb1 description:@"NSNotFound==currentIndex or currentIndex==[entiesOnMap count]-1"];
    _entry = [entries objectAtIndex:index + 1];
    [self replaceEntryWithAppleStoreIfNeeded];
    [_mainController selectRouteEntryAt:index + 1];
    [self showPanel];
}

- (void)previousButtonAction:(id)aAction
{
    if (![self saveValues])
        return;
    NSArray *entries = [_mainController entriesOnMap];
    NSUInteger index = [entries indexOfObject:_entry];
    if (index == NSNotFound || index == 0)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:kAppleStoreEditSourceFile
            lineNumber:0xa5 description:@"NSNotFound==currentIndex or currentIndex==0"];
    _entry = [entries objectAtIndex:index - 1];
    [self replaceEntryWithAppleStoreIfNeeded];
    [_mainController selectRouteEntryAt:index - 1];
    [self showPanel];
}

// Turns an ordinary city on the map into an editable Apple Store at the same place.
- (void)replaceEntryWithAppleStoreIfNeeded
{
    if ([_entry isKindOfClass:[AppleStoreEntry class]])
        return;
    NSMutableArray *entries = [_mainController entriesOnMap];
    if (![entries isKindOfClass:[NSMutableArray class]])
        return;
    NSUInteger index = [entries indexOfObject:_entry];
    if (index == NSNotFound)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:kAppleStoreEditSourceFile
            lineNumber:0x54 description:@"NSNotFound==currentIndex or currentIndex<0"];
    AppleStoreEntry *store = [AppleStoreEntry entryWithDictionaryRep:
        [self _newStoreRepWithName:[_entry shortCaption] coordinates:[_entry coordinates]]];
    [entries replaceObjectAtIndex:index withObject:store];
    _entry = store;
}

@end

@implementation AppleStoreEditController (WindowDelegate)

- (BOOL)windowShouldClose:(id)aClose
{
    return [self saveValues];
}

@end

@implementation AppleStoreEditController (Private)

- (BOOL)saveValues
{
    if (_entry == nil)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:kAppleStoreEditSourceFile
            lineNumber:0x32 description:@"_entry==nil"];
    [_entry setAlternativeName:[NSString stringWithString:[_name stringValue]]];
    [_entry setCoordinates:NSMakePoint([_longitude floatValue], [_latitude floatValue])];
    [_entry setURL:[NSString stringWithString:[_url stringValue]]];
    [_entry setShortCaption:[NSString stringWithString:[_cityName stringValue]]];
    [_entry setAddress:[NSString stringWithString:[_address string]]];
    [_entry setAdditionalInfo:[NSString stringWithString:[_additionalInfo string]]];
    NSColor *color = [_markerColor color];
    struct WeatherGlobe_anon7 marker = { [color redComponent], [color greenComponent], [color blueComponent],
                                         [color alphaComponent] };
    [_entry setMarkerColor:marker];
    [_entry setMarkerSize:[_markerSize indexOfSelectedItem]];
    [_entry setMarkerString:[NSString stringWithString:[_markerString stringValue]]];
    [_entry setInfoPaletteTitle:[NSString stringWithString:[_infoPaletteTitle stringValue]]];
    return YES;
}

- (void)showPanel
{
    if (_entry == nil)
        [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:kAppleStoreEditSourceFile
            lineNumber:0x15 description:@"_entry==nil"];
    NSPoint coordinates = [_entry coordinates];
    [_name setStringValue:[NSString stringWithString:[_entry alternativeName]]];
    [_longitude setFloatValue:coordinates.x];
    [_latitude setFloatValue:coordinates.y];
    [_url setStringValue:[NSString stringWithString:[_entry url]]];
    [_cityName setStringValue:[NSString stringWithString:[_entry shortCaption]]];
    [_address setString:[NSString stringWithString:[_entry address]]];
    [_additionalInfo setString:[NSString stringWithString:[_entry additionalInfo]]];
    struct WeatherGlobe_anon7 marker = [_entry markerColor];
    [_markerColor setColor:[NSColor colorWithDeviceRed:marker.f0 green:marker.f1 blue:marker.f2 alpha:marker.f3]];
    [_markerSize setIntValue:(int)[_entry markerSize]];
    NSString *markerString = [_entry markerString];
    if (markerString == nil)
        markerString = [[NSBundle mainBundle] localizedStringForKey:@"AppleIconCharacter" value:@"" table:nil];
    [_markerString setStringValue:[NSString stringWithString:markerString]];
    [_infoPaletteTitle setStringValue:[NSString stringWithString:[_entry infoPaletteTitle]]];
    NSArray *entries = [_mainController entriesOnMap];
    [_previousButton setEnabled:_entry != [entries objectAtIndex:0]];
    [_nextButton setEnabled:_entry != [entries lastObject]];
}

@end
