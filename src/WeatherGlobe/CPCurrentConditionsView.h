#import "WeatherGlobePrefix.h"
#import "CPWeatherGenericView.h"


@interface CPCurrentConditionsView : CPWeatherGenericView
{
}
+ (void)_acceptAdjustFontSize:(id)aSize;
+ (void)_enabledStateMenu:(id)aMenu;
+ (BOOL)validateMenuItem:(id)aItem;
+ (id)_menuItemsDescriptors;
+ (void)initialize;
+ (void)_calculateSizeForBestFit;
- (id)accessibilityObjects;
- (NSUInteger)_reportType;
- (NSUInteger)_reportMask;
- (BOOL)enabled;
- (NSSize)sizeForBestFit;
- (id)view:(id)aView stringForToolTip:(NSInteger)aTip point:(NSPoint)aPoint userData:(void *)aData;
- (void)drawRect:(NSRect)aRect;
- (void)_acceptMenuChanges:(id)aChanges;
- (void)_acceptAdjustSize:(id)aSize;
- (id)_temperatureFromReport:(id)aReport;
- (id)_summaryIconFromReport:(id)aReport;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
- (void)_checkToolTipRect;
@end

