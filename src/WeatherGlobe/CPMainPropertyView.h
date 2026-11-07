#import "WeatherGlobePrefix.h"
#import "CityPropertyAccessibilityObject.h"


@interface CPMainPropertyView : CityPropertyGenericView
{
    NSString *_title;
    NSString *_formatedTime;
    NSSize _sizeForBestFit;
    NSArray *_accessibilityObjects;
    NSRect _lastTitleRect;
    NSRect _lastDateRect;
}
+ (void)initialize;
+ (void)_acceptAdjustFontSize:(id)aSize;
+ (void)_clocksMeasureWereChanged:(id)aChanged;
+ (void)_detailViewMenu:(id)aMenu;
+ (BOOL)validateMenuItem:(id)aItem;
+ (id)_menuItemsDescriptors;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
- (id)accessibilityObjects;
- (BOOL)enabled;
- (NSSize)sizeForBestFit;
- (void)drawRect:(NSRect)aRect;
- (void)_acceptAdjustTime:(id)aTime;
- (void)_acceptMenuChanges:(id)aChanges;
- (void)_acceptAdjustSizeForBestFit:(id)aFit;
- (void)_calculateSizeForBestFit;
- (void)_adjustTime;
@end

