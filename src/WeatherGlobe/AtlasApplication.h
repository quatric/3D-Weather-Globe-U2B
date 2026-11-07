#import "WeatherGlobePrefix.h"


@interface AtlasApplication : NSApplication
{
    NSMenuItem *_zoomInMenuItem;
}
+ (void)initialize;
- (BOOL)validateMenuItem:(id)aItem;
- (void)showHelp:(id)aHelp;
- (void)sendEvent:(id)aEvent;
@end

