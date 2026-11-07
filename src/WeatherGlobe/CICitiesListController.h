#import "WeatherGlobePrefix.h"
#import "CitiesListController.h"


@interface CICitiesListController : CitiesListController
{
    NSWindow *_window;
}
- (void)_doubleAction:(id)aAction;
- (void)acceptAction:(id)aAction;
- (void)showCityDetails:(id)aDetails;
- (BOOL)validateMenuItem:(id)aItem;
- (void)hideWindow;
- (void)showWindow;
- (id)nibName;
- (void)dealloc;
- (void)awakeFromNib;
@end

