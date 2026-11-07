#import "PrefOnlineController.h"

@implementation PrefOnlineController

- (void)controlsAction:(id)aAction
{
    if ([aAction tag] == 200)
        [Preferences useSoftwareUpdating:[aAction intValue] != 0];
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
    [_softwareUpdating setIntValue:[Preferences usesSoftwareUpdating]];
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_online"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"Online" value:@"" table:nil];
}

- (id)_nibName
{
    return @"PrefOnline";
}

@end
