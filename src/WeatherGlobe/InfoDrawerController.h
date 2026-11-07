#import "WeatherGlobePrefix.h"


// one record per city with weather, packed into -drawInfo (108 bytes, as on i386);
// strings are UTF-8
typedef struct InfoDrawerRecord {
    float x;
    float y;
    int imageIndex;
    char temperature[32];
    char name[64];
} InfoDrawerRecord;

@interface InfoDrawerController : NSObject
{
    NSMutableData *_drawInfo;
    NSArray *_entries;
    BOOL _entriesScheduled;
}
- (id)drawInfo;
- (void)_entriesWereChanged:(id)aChanged;
- (void)_weatherReportsWereChanged:(id)aChanged;
- (void)_unitsOfMeasureWereChanged:(id)aChanged;
- (void)_showWeatherOnMapStateWasChanged:(id)aChanged;
- (void)dealloc;
- (id)init;
- (void)_disableWeather;
- (void)_enableWeather;
- (id)_getEntries;
- (void)_unscheduleWeather;
- (void)_scheduleWeather;
- (void)_reconstructData;
@end

