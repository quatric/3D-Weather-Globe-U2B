#import "WeatherGlobePrefix.h"


@interface WeatherPrintingData : NSObject
{
    NSView *_generalInfoView;
    NSView *_astronomyForecastView;
    NSView *_currentConditionsView;
    NSView *_extendedForecastView;
    NSTextField *_cityName;
    NSTextField *_region;
    NSTextField *_dateTime;
    NSTextField *_coordinates;
    NSTextField *_sunrise;
    NSTextField *_moonrise;
    NSTextField *_sunset;
    NSTextField *_moonset;
    NSTextField *_temperature;
    NSTextField *_visibility;
    NSTextField *_comfortLevel;
    NSTextField *_windSpeed;
    NSTextField *_humidity;
    NSImageView *_summary;
    NSImageView *_windDirection;
    NSTextField *_dewPoint;
    NSTextField *_pressure;
    NSArray *_efOneDayControllers;
    NSMutableArray *_pages;
    NSSize _currentPageSize;
    int _currentPagesCount;
}
- (id)pageAtIndex:(NSInteger)aIndex;
- (NSInteger)pagesCountForPageSize:(NSSize)aSize;
- (CGFloat)additionalScaleForPageSize:(NSSize)aSize;
- (void)setValuesFrom:(id)aFrom;
- (void)_addExtendedForecastToRect:(NSRect)aRect;
- (void)_addWeekdaysViewsFromIndex:(NSInteger)aIndex toRect:(NSRect)aRect;
- (NSRect)_restRectAfterAddingSubview:(id)aSubview toRect:(NSRect)aRect;
- (void)_setAstronomyForecast:(id)aForecast;
- (void)_setCurrentConditions:(id)aConditions;
- (void)dealloc;
- (void)awakeFromNib;
@end

