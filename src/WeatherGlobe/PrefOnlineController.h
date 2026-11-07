#import "WeatherGlobePrefix.h"
#import "PrefGenericController.h"


@interface PrefOnlineController : PrefGenericController
{
    NSButton *_softwareUpdating;
}
- (void)controlsAction:(id)aAction;
- (void)viewWillBeUninstalled;
- (void)viewWillBeInstalled;
- (id)toolbarImage;
- (id)toolbarLabel;
- (id)_nibName;
@end

