#import "Preferences+CIPreferences.h"

@implementation Preferences (CIPreferences)

static NSInteger _intDefault(NSString *key, NSString *fallback)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *value = [defaults objectForKey:key];
    if (value == nil) {
        value = fallback;
        [defaults setObject:value forKey:key];
    }
    return [value intValue];
}

static void _setIntDefault(NSString *key, NSInteger value)
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d", (int)value] forKey:key];
}

+ (void)setExpandedForecastDaysCount:(NSInteger)aCount
{
    _setIntDefault(@"ExpandedForecastDaysCount", aCount);
}

+ (NSInteger)expandedForecastDaysCount
{
    NSInteger count = _intDefault(@"ExpandedForecastDaysCount", @"7");
    if (count < 0) {
        [self setExpandedForecastDaysCount:0];
        count = 0;
    } else if (count > 7) {
        [self setExpandedForecastDaysCount:7];
        count = 7;
    }
    return count;
}

+ (void)setCurrentConditionsEnabled:(BOOL)aEnabled
{
    _setIntDefault(@"CurrentConditionsEnabled", aEnabled);
}

+ (BOOL)currentConditionsEnabled
{
    return (BOOL)_intDefault(@"CurrentConditionsEnabled", @"1");
}

+ (void)setAstronomyForecastEnabled:(BOOL)aEnabled
{
    _setIntDefault(@"AstronomyForecastEnabled", aEnabled);
}

+ (BOOL)astronomyForecastEnabled
{
    return (BOOL)_intDefault(@"AstronomyForecastEnabled", @"1");
}

+ (void)setMainPropertiesDetailViewFlags:(NSInteger)aFlags
{
    _setIntDefault(@"MainPropertiesDetailViewFlags", aFlags);
}

+ (NSInteger)mainPropertiesDetailViewFlags
{
    return _intDefault(@"MainPropertiesDetailViewFlags", @"32");
}

+ (CGFloat)separatorColorWhiteComponent
{
    return 0.6588f;
}

+ (void)setPaletteFontSize:(CGFloat)aSize
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%f", (double)aSize] forKey:@"CIPaletteFontSize"];
}

+ (CGFloat)paletteFontSize
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *value = [defaults objectForKey:@"CIPaletteFontSize"];
    if (value == nil) {
        value = @"11";
        [defaults setObject:value forKey:@"CIPaletteFontSize"];
    }
    return [value floatValue];
}

+ (void)setPaletteTransparencyLevel:(CGFloat)aLevel
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%f", (double)(float)aLevel] forKey:@"CITransparencyLevel"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCITransparencyLevelWasChanged object:self];
}

+ (CGFloat)paletteTransparencyLevel
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *value = [defaults objectForKey:@"CITransparencyLevel"];
    if (value == nil) {
        value = @"0.6";
        [defaults setObject:value forKey:@"CITransparencyLevel"];
    }
    float level = [value floatValue];
    if (level < kMinCITransparencyLevel) {
        [defaults setObject:[NSString stringWithFormat:@"%f", (double)kMinCITransparencyLevel] forKey:@"CITransparencyLevel"];
        level = kMinCITransparencyLevel;
    }
    if (level > kMaxCITransparencyLevel) {
        [defaults setObject:[NSString stringWithFormat:@"%f", (double)kMaxCITransparencyLevel] forKey:@"CITransparencyLevel"];
        level = kMaxCITransparencyLevel;
    }
    return level;
}

+ (NSInteger)citiesCountLimit
{
    return _intDefault(@"CitiesCountLimitInCIPalette", @"20");
}

+ (void)setCitiesList:(id)aList
{
    [[NSUserDefaults standardUserDefaults] setObject:aList forKey:@"CitiesInCIPalette_1_1"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCitiesListWasChanged object:self];
}

+ (id)citiesList
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id list = [defaults objectForKey:@"CitiesInCIPalette_1_1"];
    if (list == nil) {
        list = [NSArray array];
        [defaults setObject:list forKey:@"CitiesInCIPalette_1_1"];
    }
    return list;
}

+ (void)setVerticalStateEnabled:(BOOL)aEnabled
{
    _setIntDefault(@"VerticalStateEnabled", aEnabled);
}

+ (BOOL)verticalStateEnabled
{
    return (BOOL)_intDefault(@"VerticalStateEnabled", @"1");
}

@end
