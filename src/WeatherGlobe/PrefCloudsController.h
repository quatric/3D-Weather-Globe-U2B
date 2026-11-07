#import "WeatherGlobePrefix.h"
#import "PrefGenericController.h"


@interface PrefCloudsController : PrefGenericController
{
    NSButton *_useInternet;
    NSButton *_showWeatherOnMap;
    NSPopUpButton *_cloudsDetalizationLevel;
    NSSlider *_weatherPaletteOpacity;
}
- (void)controlsAction:(id)aAction;
- (void)viewWillBeUninstalled;
- (void)viewWillBeInstalled;
- (id)toolbarImage;
- (id)toolbarLabel;
- (void)_checkControlsState;
- (id)_nibName;
@end

