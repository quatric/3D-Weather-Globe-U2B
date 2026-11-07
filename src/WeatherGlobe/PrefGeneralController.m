#import "PrefGeneralController.h"

@implementation PrefGeneralController

- (void)controlsAction:(id)aAction
{
    switch ([aAction tag]) {
    case 100:
        [Preferences useMetricSystem:[aAction intValue] != 0];
        break;
    case 200:
        [Preferences setPlaySoundOnRouteFly:[aAction intValue] != 0];
        break;
    case 24:
        [Preferences use24HourClock:[aAction selectedRow] != 0];
        break;
    }
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
    [_useMetric setIntValue:[Preferences usesMetricSystem]];
    [_clockFormat selectCellAtRow:[Preferences uses24HourClock] ? 1 : 0 column:0];
    [_playAirplaneSound setIntValue:[Preferences playSoundOnRouteFly]];
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_general"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"General" value:@"" table:nil];
}

- (id)_nibName
{
    return @"PrefGeneral";
}

@end
