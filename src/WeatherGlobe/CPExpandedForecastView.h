#import "WeatherGlobePrefix.h"
#import "CPWeatherGenericView.h"


@interface CPExpandedForecastView : CPWeatherGenericView
{
}
+ (void)_acceptAdjustFontSize:(id)aSize;
+ (void)_enabledStateMenu:(id)aMenu;
+ (BOOL)validateMenuItem:(id)aItem;
+ (id)_menuItemsDescriptors;
+ (id)_submenu;
+ (id)_menuItemWithTitle:(id)aTitle selector:(SEL)aSelector tag:(NSInteger)aTag;
+ (void)initialize;
+ (void)_calculateSizeForBestFit;
- (id)accessibilityObjects;
- (NSUInteger)_reportType;
- (NSUInteger)_reportMask;
- (BOOL)enabled;
- (NSSize)sizeForBestFit;
- (id)view:(id)aView stringForToolTip:(NSInteger)aTip point:(NSPoint)aPoint userData:(void *)aData;
- (void)drawRect:(NSRect)aRect;
- (void)_viewSizeWasChanged:(id)aChanged;
- (void)_acceptMenuChanges:(id)aChanges;
- (void)_acceptAdjustSize:(id)aSize;
- (id)_temperatureFromOneDayReport:(id)aReport high:(BOOL)aHigh;
- (id)_summaryIconFromOneDayReport:(id)aReport;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
- (void)_checkToolTipRects;
@end

