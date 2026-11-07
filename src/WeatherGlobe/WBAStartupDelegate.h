#import "WeatherGlobePrefix.h"


@interface WBAStartupDelegate : NSObject
{
    AtlasController *_owner;
}
- (BOOL)application:(id)aApplication printFile:(id)aFile;
- (BOOL)application:(id)aApplication openFile:(id)aFile;
@end

