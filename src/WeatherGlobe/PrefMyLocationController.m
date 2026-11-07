#import "PrefMyLocationController.h"

@implementation PrefMyLocationController

- (void)selectCitySheetDidEnd
{
    [self _setLocationName:[[Preferences homeCity] shortCaption]];
}

- (void)controlsAction:(id)aAction
{
    switch ([aAction tag]) {
    case 100: {
        id city = [_citiesListController selectedItem];
        if (city == nil) {
            NSBeep();
            return;
        }
        [Preferences setHomeCityUID:[city uid]];
        [self _setLocationName:[city shortCaption]];
        break;
    }
    case 200:
        [Preferences setShowWeatherInDock:[aAction state] != NSControlStateValueOff];
        break;
    }
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
    [self _setLocationName:[[Preferences homeCity] shortCaption]];
    [_showInDock setState:[Preferences doShowWeatherInDock] ? NSControlStateValueOn : NSControlStateValueOff];
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_home"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"My Location" value:@"" table:nil];
}

// Shortens the name with a trailing "..." when it does not fit the field.
- (void)_setLocationName:(id)aName
{
    [_location setStringValue:aName];
    NSCell *cell = [_location cell];
    float fullWidth = [cell cellSize].width;
    float available = floorf(NSWidth([_location bounds]));
    if (available < fullWidth) {
        [_location setStringValue:@"..."];
        float left = floorf(available - [cell cellSize].width);
        NSString *head = [aName substringToIndex:(NSUInteger)((left / fullWidth) * [aName length])];
        [_location setStringValue:[head stringByAppendingString:[_location stringValue]]];
    }
}

- (id)_nibName
{
    return @"PrefMyLocation";
}

- (void)dealloc
{
    [_citiesListController release];
    [super dealloc];
}

@end
