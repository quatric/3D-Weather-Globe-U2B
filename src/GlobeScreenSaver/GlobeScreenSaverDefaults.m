#import "GlobeScreenSaverDefaults.h"

// The saver's settings live in its ScreenSaverDefaults domain as strings.
@implementation GlobeScreenSaverDefaults

+ (id)configDictionary
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Config" ofType:@"plist"];
	return [NSDictionary dictionaryWithContentsOfFile:path];
}

+ (void)setZoom:(CGFloat)aZoom
{
	[[self standardSaverDefaults] setObject:[NSString stringWithFormat:@"%f", (double)(float)aZoom] forKey:kZoom];
}

+ (CGFloat)zoom
{
	ScreenSaverDefaults *defaults = [self standardSaverDefaults];
	NSString *value = [defaults objectForKey:kZoom];
	if (value == nil) {
		value = @"1.0";
		[defaults setObject:value forKey:kZoom];
	}
	return [value floatValue];
}

+ (void)setSpinningSpeed:(CGFloat)aSpeed
{
	[[self standardSaverDefaults] setObject:[NSString stringWithFormat:@"%f", (double)(float)aSpeed]
	                                 forKey:kSpinningSpeed];
}

+ (CGFloat)spinningSpeed
{
	ScreenSaverDefaults *defaults = [self standardSaverDefaults];
	NSString *value = [defaults objectForKey:kSpinningSpeed];
	if (value == nil) {
		value = [NSString stringWithFormat:@"%f", (double)0.205f];
		[defaults setObject:value forKey:kSpinningSpeed];
	}
	return [value floatValue];
}

static void _setFlag(BOOL aEnabled, NSString *aKey)
{
	[[GlobeScreenSaverDefaults standardSaverDefaults] setObject:aEnabled ? @"1" : @"0" forKey:aKey];
}

// flags default to on
static BOOL _flag(NSString *aKey)
{
	ScreenSaverDefaults *defaults = [GlobeScreenSaverDefaults standardSaverDefaults];
	NSString *value = [defaults objectForKey:aKey];
	if (value == nil) {
		value = @"1";
		[defaults setObject:value forKey:aKey];
	}
	return [value intValue] != 0;
}

+ (void)setCloudsEnabled:(BOOL)aEnabled
{
	_setFlag(aEnabled, kCloudsEnabled);
}

+ (BOOL)cloudsEnabled
{
	return _flag(kCloudsEnabled);
}

+ (void)setMoonEnabled:(BOOL)aEnabled
{
	_setFlag(aEnabled, kMoonEnabled);
}

+ (BOOL)moonEnabled
{
	return _flag(kMoonEnabled);
}

+ (void)setSunEnabled:(BOOL)aEnabled
{
	_setFlag(aEnabled, kSunEnabled);
}

+ (BOOL)sunEnabled
{
	return _flag(kSunEnabled);
}

+ (void)setDayNightEnabled:(BOOL)aEnabled
{
	_setFlag(aEnabled, kDayNightEnabled);
}

+ (BOOL)dayNightEnabled
{
	return _flag(kDayNightEnabled);
}

+ (void)setStarsEnabled:(BOOL)aEnabled
{
	_setFlag(aEnabled, kStarsEnabled);
}

+ (BOOL)starsEnabled
{
	return _flag(kStarsEnabled);
}

+ (void)setSpinDirectionMode:(NSInteger)aMode
{
	[[self standardSaverDefaults] setObject:[NSString stringWithFormat:@"%d", (int)aMode] forKey:kSpinDirection];
}

+ (NSInteger)spinDirectionMode
{
	ScreenSaverDefaults *defaults = [self standardSaverDefaults];
	NSString *value = [defaults objectForKey:kSpinDirection];
	if (value == nil) {
		value = [NSString stringWithFormat:@"%d", 0];
		[defaults setObject:value forKey:kSpinDirection];
	}
	return [value intValue];
}

// mode 0 spins one way (-1), any other the other (1)
+ (NSInteger)globeSpinningDirection
{
	return [self spinDirectionMode] == 0 ? -1 : 1;
}

+ (void)setPointOfViewMode:(NSInteger)aMode
{
	[[self standardSaverDefaults] setObject:[NSString stringWithFormat:@"%d", (int)aMode] forKey:kPointOfView];
}

// 0 from a satellite, 1 the whole globe
+ (NSInteger)pointOfViewMode
{
	ScreenSaverDefaults *defaults = [self standardSaverDefaults];
	NSString *value = [defaults objectForKey:kPointOfView];
	if (value == nil) {
		value = [NSString stringWithFormat:@"%d", 0];
		[defaults setObject:value forKey:kPointOfView];
	}
	return [value intValue];
}

+ (id)standardSaverDefaults
{
	return [ScreenSaverDefaults defaultsForModuleWithName:@"com.mackiev.globescreensaver"];
}

@end

@implementation NSDictionary (ConfigDictionary)

- (CGFloat)animationFPS
{
	return [[self objectForKey:kAnimationFPSKey] floatValue];
}

@end
