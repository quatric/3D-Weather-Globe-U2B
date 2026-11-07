#import "WeatherGlobePrefix.h"
#import "CityPropertyAccessibilityObject.h"


@interface CPWeatherGenericView : CityPropertyGenericView
{
    NSDictionary *_report;
    NSProgressIndicator *_progressIndicator;
    BOOL _isAnimating;
    BOOL _scheduled;
    NSArray *_accessibilityObjects;
}
+ (id)expiredString;
+ (BOOL)usesMetricSystem;
+ (void)_internetStateWasChanged:(id)aChanged;
+ (void)_unitsOfMeasureWereChanged:(id)aChanged;
+ (void)initialize;
+ (NSSize)sizeForBestFit;
- (NSUInteger)_reportType;
- (NSUInteger)_reportMask;
- (BOOL)enabled;
- (id)reportDictionary;
- (void)alignProgressIndicator;
- (void)adjustEnableState;
- (void)drawRect:(NSRect)aRect;
- (void)viewDidMoveToWindow;
- (void)setMenu:(id)aMenu;
- (void)_acceptWindowWillClose:(id)aClose;
- (void)_acceptWindowDidShow:(id)aShow;
- (void)_acceptNeedStopAnimations:(id)aAnimations;
- (void)_acceptNeedStartAnimations:(id)aAnimations;
- (void)_adjustEnableState:(id)aState;
- (void)_unitsOfMeasureWereChanged:(id)aChanged;
- (void)_reportsWereChanged:(id)aChanged;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
- (void)_unschedule;
- (void)_schedule;
@end

