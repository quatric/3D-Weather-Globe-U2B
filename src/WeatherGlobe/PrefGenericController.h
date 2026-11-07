#import "WeatherGlobePrefix.h"


@interface PrefGenericController : NSObject
{
    NSView *_mainView;
}
- (id)toolbarImage;
- (id)toolbarLabel;
- (void)primaryAction;
- (void)viewWillBeUninstalled;
- (void)viewWillBeInstalled;
- (id)mainView;
- (void)_loadNibIfNeeded;
- (id)_nibName;
- (void)dealloc;
@end

