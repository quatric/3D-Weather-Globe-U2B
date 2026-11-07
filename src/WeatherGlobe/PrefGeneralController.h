#import "WeatherGlobePrefix.h"
#import "PrefGenericController.h"


@interface PrefGeneralController : PrefGenericController
{
    NSMatrix *_clockFormat;
    NSButton *_useMetric;
    NSButton *_playAirplaneSound;
}
- (void)controlsAction:(id)aAction;
- (void)viewWillBeUninstalled;
- (void)viewWillBeInstalled;
- (id)toolbarImage;
- (id)toolbarLabel;
- (id)_nibName;
@end

