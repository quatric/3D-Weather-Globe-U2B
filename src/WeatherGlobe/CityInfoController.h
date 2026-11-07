#import "WeatherGlobePrefix.h"


@interface CityInfoController : NSObject
{
    YACityEntry *_entry;
    NSSize _sizeForBestFit;
    CityInfoView *_mainView;
    NSView *_contentView;
    NSArray *_cityPropertyViews;
    NSArray *_lineViewsContainers;
    NSArray *_accessibilityObjects;
}
+ (id)optionsMenuItems;
- (void)_manualUpdateWeather:(id)aWeather;
- (void)_acceptNeedCreateImage:(id)aImage;
- (void)_acceptMainViewSizeChanged:(id)aChanged;
- (id)accessibilityObjects;
- (void)reconstructMainView;
- (void)setMenu:(id)aMenu;
- (id)cityEntry;
- (NSSize)sizeForBestFit;
- (id)mainView;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
@end

@interface NSView (Extension)
- (BOOL)acceptsFirstMouse:(id)aMouse;
@end

@interface CityInfoController (Private)
+ (id)_allPropertyViewClasses;
- (void)_allignViews;
- (void)_createAllViews;
- (id)_allPropertyViews;
@end

