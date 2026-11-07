#import "WeatherGlobePrefix.h"
#import "CitiesListController.h"


@interface MainListController : CitiesListController
{
    MainWindowController *_mainController;
}
- (void)tableView:(id)aView requestedToMarkRows:(id)aRows;
- (BOOL)validateMenuItem:(id)aItem;
- (void)lookupInWorldBookMaps:(id)aMaps;
- (void)lookupInWorldBookArticles:(id)aArticles;
- (void)_performURLServiceWithString:(id)aString;
- (id)_escapeSequenceString:(id)aString;
- (void)deleteFromMapAction:(id)aAction;
- (void)putOnMapAction:(id)aAction;
@end

