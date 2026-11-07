#import "WeatherGlobePrefix.h"
#import "PrefGenericController.h"


@interface PrefApearanceController : PrefGenericController
{
    NSButton *_retainLocationMarkers;
    NSMatrix *_fullScreenAsDefault;
}
- (void)controlsAction:(id)aAction;
- (void)viewWillBeUninstalled;
- (void)viewWillBeInstalled;
- (id)toolbarImage;
- (id)toolbarLabel;
- (id)_nibName;
@end

