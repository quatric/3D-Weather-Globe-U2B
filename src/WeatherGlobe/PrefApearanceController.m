#import "PrefApearanceController.h"

@implementation PrefApearanceController

- (void)controlsAction:(id)aAction
{
    switch ([aAction tag]) {
    case 200:
        [Preferences setOpenFullScreenByDefault:[aAction selectedRow] != 0];
        break;
    case 400:
        [Preferences setRetainLastView:[aAction intValue] != 0];
        break;
    }
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
    [_retainLocationMarkers setIntValue:[Preferences retainLastView]];
    [_fullScreenAsDefault selectCellAtRow:[Preferences openFullScreenByDefault] ? 1 : 0 column:0];
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_appearance"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"ApearancePrefTitle" value:@"" table:nil];
}

- (id)_nibName
{
    return @"PrefApearance";
}

@end
