#import "PrefCloudsController.h"

@implementation PrefCloudsController

- (void)controlsAction:(id)aAction
{
    switch ([aAction tag]) {
    case 200:
        [Preferences setInternetState:[aAction intValue]];
        [self _checkControlsState];
        break;
    case 300:
        [Preferences setPaletteTransparencyLevel:[aAction floatValue]];
        break;
    case 400:
        [Preferences setShowWeatherOnMap:[aAction intValue] != 0];
        break;
    case 100: {
        NSInteger current = [Preferences cloudsDetalizationLevel];
        NSInteger selected = [aAction indexOfSelectedItem];
        if (2 - current == selected)
            break;
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *cancel = [bundle localizedStringForKey:@"Cancel" value:@"" table:nil];
        NSString *remove = [bundle localizedStringForKey:@"Remove Clouds butt" value:@"" table:nil];
        NSString *message = [bundle localizedStringForKey:@"Remove downloaded clouds message" value:@"" table:nil];
        NSString *title = [bundle localizedStringForKey:@"Remove downloaded clouds title" value:@"" table:nil];
        if (NSRunAlertPanel(title, @"%@", remove, nil, cancel, message) == NSAlertDefaultReturn)
            [Preferences setCloudsDetalizationLevel:2 - selected];
        else
            [_cloudsDetalizationLevel selectItemAtIndex:2 - current];
        break;
    }
    }
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
    [_useInternet setIntValue:(int)[Preferences internetState]];
    [self _checkControlsState];
    [_cloudsDetalizationLevel selectItemAtIndex:2 - [Preferences cloudsDetalizationLevel]];
    [_showWeatherOnMap setIntValue:[Preferences doShowWeatherOnMap]];
    [_weatherPaletteOpacity setMinValue:kMinCITransparencyLevel];
    [_weatherPaletteOpacity setMaxValue:kMaxCITransparencyLevel];
    [_weatherPaletteOpacity setFloatValue:[Preferences paletteTransparencyLevel]];
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_clouds"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"WeatherPrefTitle" value:@"" table:nil];
}

- (void)_checkControlsState
{
    BOOL enabled = [Preferences internetState] != 0;
    [_cloudsDetalizationLevel setEnabled:enabled];
    [_showWeatherOnMap setEnabled:enabled];
}

- (id)_nibName
{
    return @"PrefClouds";
}

@end
