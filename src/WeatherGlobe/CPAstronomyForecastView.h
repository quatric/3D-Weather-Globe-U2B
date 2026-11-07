#import "WeatherGlobePrefix.h"
#import "CPWeatherGenericView.h"


@interface CPAstronomyForecastView : CPWeatherGenericView
{
}
+ (void)_clocksMeasureWereChanged:(id)aChanged;
+ (void)_acceptAdjustFontSize:(id)aSize;
+ (void)_enabledStateMenu:(id)aMenu;
+ (BOOL)validateMenuItem:(id)aItem;
+ (id)_menuItemsDescriptors;
+ (void)initialize;
+ (void)_calculateSizeForBestFit;
- (NSUInteger)_reportType;
- (NSUInteger)_reportMask;
- (BOOL)enabled;
- (NSSize)sizeForBestFit;
- (void)drawRect:(NSRect)aRect;
- (void)_acceptMenuChanges:(id)aChanges;
- (void)_acceptRefresh:(id)aRefresh;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
@end

