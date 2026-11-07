#import "WeatherGlobePrefix.h"
#import "Preferences.h"


@interface Preferences (CIPreferences)
+ (void)setExpandedForecastDaysCount:(NSInteger)aCount;
+ (NSInteger)expandedForecastDaysCount;
+ (void)setCurrentConditionsEnabled:(BOOL)aEnabled;
+ (BOOL)currentConditionsEnabled;
+ (void)setAstronomyForecastEnabled:(BOOL)aEnabled;
+ (BOOL)astronomyForecastEnabled;
+ (void)setMainPropertiesDetailViewFlags:(NSInteger)aFlags;
+ (NSInteger)mainPropertiesDetailViewFlags;
+ (CGFloat)separatorColorWhiteComponent;
+ (void)setPaletteFontSize:(CGFloat)aSize;
+ (CGFloat)paletteFontSize;
+ (void)setPaletteTransparencyLevel:(CGFloat)aLevel;
+ (CGFloat)paletteTransparencyLevel;
+ (NSInteger)citiesCountLimit;
+ (void)setCitiesList:(id)aList;
+ (id)citiesList;
+ (void)setVerticalStateEnabled:(BOOL)aEnabled;
+ (BOOL)verticalStateEnabled;
@end

