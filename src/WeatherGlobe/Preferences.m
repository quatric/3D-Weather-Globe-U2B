#import "Preferences.h"

static const float kMaxCloudsAnimationDeltaTime = 1.6f;
static const float kMinCloudsAnimationDeltaTime = 0.2f;

// All values are stored as strings; a missing key is seeded with its default on first read.
static id _storedValue(NSString *aKey, id aDefault)
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id value = [defaults objectForKey:aKey];
	if (value == nil) {
		value = aDefault;
		[defaults setObject:value forKey:aKey];
	}
	return value;
}

static BOOL _boolValue(NSString *aKey, BOOL aDefault)
{
	return (BOOL)[_storedValue(aKey, aDefault ? @"1" : @"0") intValue];
}

static NSInteger _intValue(NSString *aKey, NSInteger aDefault)
{
	return [_storedValue(aKey, [NSString stringWithFormat:@"%d", (int)aDefault]) intValue];
}

static CGFloat _floatValue(NSString *aKey, NSString *aDefault)
{
	return [_storedValue(aKey, aDefault) floatValue];
}

static void _setFormatted(NSString *aKey, NSString *aFormat, ...)
{
	va_list args;
	NSString *value;
	va_start(args, aFormat);
	value = [[[NSString alloc] initWithFormat:aFormat arguments:args] autorelease];
	va_end(args);
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:aKey];
}

static void _setFlag(NSString *aKey, BOOL aValue)
{
	[[NSUserDefaults standardUserDefaults] setObject:aValue ? @"1" : @"0" forKey:aKey];
}

// YES when a stored value exists and differs from the new one
static BOOL _storedIntDiffers(NSString *aKey, NSInteger aValue)
{
	id value = [[NSUserDefaults standardUserDefaults] objectForKey:aKey];
	return value != nil && [value intValue] != aValue;
}

static void _post(NSString *aName, id anObject)
{
	[[NSNotificationCenter defaultCenter] postNotificationName:aName object:anObject];
}

@implementation Preferences

+ (void)setHomeCityUID:(id)aUID
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id previous = [defaults objectForKey:@"HomeCityUID_1_1"];
	BOOL changed = previous != nil && ![previous isEqualToString:aUID];
	id entry;
	NSString *name, *state, *country;

	[defaults setObject:aUID forKey:@"HomeCityUID_1_1"];
	entry = [[AtlasDatabase database] dbEntryWithUID:aUID];
	name = [entry ownName];
	state = [entry stateName];
	country = [entry countryName];
	if (name == nil || country == nil) {
		[defaults removeObjectForKey:@"HomeCityName"];
	} else {
		BOOL useState = [country compare:@"united states" options:NSCaseInsensitiveSearch] == NSOrderedSame
			|| [country compare:@"united kingdom" options:NSCaseInsensitiveSearch] == NSOrderedSame;
		[defaults setObject:[NSString stringWithFormat:@"%@, %@", name, useState ? state : country]
					 forKey:@"HomeCityName"];
	}
	if (changed)
		_post(kHomeCityWasChanged, self);
	[defaults synchronize];
}

+ (id)homeCityUID
{
	return _storedValue(@"HomeCityUID_1_1", @"-1");
}

+ (id)homeCity
{
	if ([self _homeCity] == nil)
		[SelectCityDialogController runModalDialog];
	return [self _homeCity];
}

+ (id)_homeCity
{
	return [[AtlasDatabase database] dbEntryWithUID:[self homeCityUID]];
}

+ (void)setSerialNumber:(id)aNumber
{
	[aNumber writeToFile:[[NSFileManager defaultManager] serialNumberPath] atomically:YES
				encoding:NSUTF8StringEncoding error:NULL];
}

+ (id)serialNumber
{
	NSString *serial = [NSString stringWithContentsOfFile:[[NSFileManager defaultManager] serialNumberPath]
												 encoding:NSUTF8StringEncoding error:NULL];
	return serial ? serial : @"";
}

+ (void)setMapMode:(NSInteger)aMode
{
	_setFormatted(@"MapMode", @"%d", (int)aMode);
}

+ (NSInteger)mapMode
{
	return [_storedValue(@"MapMode", @"0") intValue];
}

+ (void)setLastRoute:(id)aRoute
{
	if (aRoute != nil)
		[[NSUserDefaults standardUserDefaults] setObject:aRoute forKey:@"LastRoute"];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"LastRoute"];
}

+ (id)lastRoute
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"LastRoute"];
}

+ (void)setRetainLastView:(BOOL)aView
{
	_setFormatted(@"RetainLastView", @"%d", (int)aView);
}

+ (BOOL)retainLastView
{
	return _boolValue(@"RetainLastView", NO);
}

+ (void)setPlaySoundOnRouteFly:(BOOL)aFly
{
	_setFormatted(@"PlaySoundOnRouteFly", @"%d", (int)aFly);
}

+ (BOOL)playSoundOnRouteFly
{
	return _boolValue(@"PlaySoundOnRouteFly", YES);
}

+ (void)useSoftwareUpdating:(BOOL)aUpdating
{
	_setFormatted(@"UsesSoftwareUpdating", @"%d", (int)aUpdating);
}

+ (BOOL)usesSoftwareUpdating
{
	return _boolValue(@"UsesSoftwareUpdating", YES);
}

+ (void)setInternetState:(NSInteger)aState
{
	BOOL changed = _storedIntDiffers(@"InternetState", aState);
	_setFormatted(@"InternetState", @"%d", (int)aState);
	if (changed)
		[self _postInternetStateNotification];
}

+ (NSInteger)internetState
{
	return _intValue(@"InternetState", 1);
}

+ (BOOL)usesInternet
{
	return [self internetState] == 1;
}

+ (void)_postInternetStateNotification
{
	static BOOL entered = NO;
	if (!entered) {
		entered = YES;
		_post(kInternetStateWasChanged, self);
		entered = NO;
	}
}

+ (void)use24HourClock:(BOOL)aClock
{
	BOOL changed = _storedIntDiffers(@"Uses24HourClock", aClock);
	_setFormatted(@"Uses24HourClock", @"%d", (int)aClock);
	if (changed)
		_post(kClockFormatWasChanged, self);
}

+ (BOOL)uses24HourClock
{
	return _boolValue(@"Uses24HourClock", NO);
}

+ (void)useMetricSystem:(BOOL)aSystem
{
	BOOL changed = _storedIntDiffers(@"UsesMetricSystem", aSystem);
	_setFormatted(@"UsesMetricSystem", @"%d", (int)aSystem);
	if (changed)
		_post(kUnitsOfMeasureWereChanged, self);
}

+ (BOOL)usesMetricSystem
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id value = [defaults objectForKey:@"UsesMetricSystem"];
	if (value == nil) {
		Class specific = [PantherSpecificClass principalClass];
		value = (specific != Nil && [(id)specific usesMetricSystem]) ? @"1" : @"0";
		[defaults setObject:value forKey:@"UsesMetricSystem"];
	}
	return (BOOL)[value intValue];
}

+ (void)setShowUnsupportedColorAlert:(BOOL)aAlert
{
	_setFormatted(@"DoShowUnsupportedColorAlert", @"%d", (int)aAlert);
}

+ (BOOL)doShowUnsupportedColorAlert
{
	return _boolValue(@"DoShowUnsupportedColorAlert", YES);
}

+ (void)setShowUnsupportedOSAlert:(BOOL)aAlert
{
	_setFormatted(@"DoShowUnsupportedOSAlert", @"%d", (int)aAlert);
}

+ (BOOL)doShowUnsupportedOSAlert
{
	return _boolValue(@"DoShowUnsupportedOSAlert", YES);
}

+ (void)setShowCloudsDownloadFailedAlert:(BOOL)aAlert
{
	_setFormatted(@"DoShowCloudsDwnldFailedAlert", @"%d", (int)aAlert);
}

+ (BOOL)doShowCloudsDownloadFailedAlert
{
	return _boolValue(@"DoShowCloudsDwnldFailedAlert", YES);
}

+ (void)setShowBadVideoAlert:(BOOL)aAlert
{
	_setFormatted(@"DoShowBadVideoAlert", @"%d", (int)aAlert);
}

+ (BOOL)doShowBadVideoAlert
{
	return _boolValue(@"DoShowBadVideoAlert", YES);
}

+ (void)setShowWeatherOnMap:(BOOL)aMap
{
	BOOL changed = _storedIntDiffers(@"DoShowWeatherOnMap", aMap);
	_setFormatted(@"DoShowWeatherOnMap", @"%d", (int)aMap);
	if (changed)
		_post(kShowWeatherOnMapStateWasChanged, self);
}

+ (BOOL)doShowWeatherOnMap
{
	return _boolValue(@"DoShowWeatherOnMap", YES);
}

+ (void)setShowWeatherInDock:(BOOL)aDock
{
	BOOL changed = _storedIntDiffers(@"DoShowWeatherInDock", aDock);
	_setFormatted(@"DoShowWeatherInDock", @"%d", (int)aDock);
	if (changed)
		_post(kShowWeatherInDockStateWasChanged, self);
}

+ (BOOL)doShowWeatherInDock
{
	return _boolValue(@"DoShowWeatherInDock", YES);
}

+ (void)setShowWeatherOnStartup:(BOOL)aStartup
{
	_setFormatted(@"DoShowWeather", @"%d", (int)aStartup);
}

+ (BOOL)doShowWeatherOnStartup
{
	return _boolValue(@"DoShowWeather", NO);
}

+ (void)setZoomMainWindow:(BOOL)aWindow
{
	_setFormatted(@"ZoomMainWindow", @"%d", (int)aWindow);
}

+ (BOOL)shouldZoomMainWindow
{
	return _boolValue(@"ZoomMainWindow", YES);
}

+ (void)setOpenFullScreenByDefault:(BOOL)aDefault
{
	_setFormatted(@"FullScreenAsDefault", @"%d", (int)aDefault);
}

+ (BOOL)openFullScreenByDefault
{
	return _boolValue(@"FullScreenAsDefault", NO);
}

+ (void)setShowMainWindow:(BOOL)aWindow
{
	_setFormatted(@"DoShowMainWindow", @"%d", (int)aWindow);
}

+ (BOOL)doShowMainWindowOnStartup
{
	BOOL show = _boolValue(@"DoShowMainWindow", YES);
	// never start with no window at all
	if (!show && ![self doShowWeatherOnStartup]) {
		[self setShowMainWindow:YES];
		show = YES;
	}
	return show;
}

+ (void)setAutomoveSpeedSliderValue:(CGFloat)aValue
{
	_setFormatted(@"AutomoveSpeed", @"%f", (double)aValue);
}

+ (CGFloat)automoveSpeedSliderValue
{
	return _floatValue(@"AutomoveSpeed", @"0.3");
}

+ (CGFloat)automoveSpeedUIValue
{
	float value = (float)[self automoveSpeedSliderValue];
	return (float)(pow(4.0, (double)value + (double)value) * 0.25);
}

+ (void)setMarkersScale:(CGFloat)aScale
{
	_setFormatted(@"MarkersScale", @"%f", (double)aScale);
}

+ (CGFloat)markersScale
{
	return _floatValue(@"MarkersScale", @"2.5");
}

+ (void)setDrawAllCities:(BOOL)aCities
{
	_setFormatted(@"DrawAllCities", @"%d", (int)aCities);
}

+ (BOOL)doDrawAllCities
{
	return _boolValue(@"DrawAllCities", NO);
}

+ (void)setGridDetalization:(NSInteger)aDetalization
{
	_setFormatted(@"GridDetalization", @"%d", (int)aDetalization);
}

+ (NSInteger)gridDetalization
{
	return _intValue(@"GridDetalization", 0);
}

+ (void)setGridEnabled:(BOOL)aEnabled
{
	_setFlag(@"GridEnabled", aEnabled);
}

+ (BOOL)gridEnabled
{
	return _boolValue(@"GridEnabled", NO);
}

+ (void)setCloudsAnimationSliderValue:(CGFloat)aValue
{
	_setFormatted(@"CloudsAnimationTime", @"%f", (double)aValue);
}

+ (CGFloat)cloudsAnimationSliderValue
{
	return _floatValue(@"CloudsAnimationTime", @"0.5");
}

+ (CGFloat)cloudsAnimationDeltaTime
{
	static float _cloudsDeltaTimeFactor = 0.0f;
	if (_cloudsDeltaTimeFactor == 0.0f) {
		_cloudsDeltaTimeFactor = (float)((double)(kMaxCloudsAnimationDeltaTime - kMinCloudsAnimationDeltaTime)
			/ (pow(2.0, kMaxCloudsAnimationSliderValue) - pow(2.0, kMinCloudsAnimationSliderValue)));
	}
	return kMinCloudsAnimationDeltaTime
		+ _cloudsDeltaTimeFactor * (float)pow(2.0, kMaxCloudsAnimationSliderValue - (float)[self cloudsAnimationSliderValue]);
}

+ (NSInteger)cloudsTextureWidth
{
	switch ([self cloudsDetalizationLevel]) {
	case 1:
		return 512;
	case 2:
		return 1024;
	default:
		return 256;
	}
}

+ (void)setCloudsAnimationQuality:(NSInteger)aQuality
{
	_setFormatted(@"CloudsAnimation", @"%d", (int)aQuality);
}

+ (NSInteger)cloudsAnimationQuality
{
	return _intValue(@"CloudsAnimation", 2);
}

+ (void)setCloudsDetalizationLevel:(NSInteger)aLevel
{
	BOOL changed = _storedIntDiffers(@"CloudsDetalization", aLevel);
	_setFormatted(@"CloudsDetalization", @"%d", (int)aLevel);
	if (changed) {
		[CWManager scheduleCloudsReloadTask];
		_post(kCloudsTextureSizeWasChanged, self);
	}
}

+ (NSInteger)cloudsDetalizationLevel
{
	return _intValue(@"CloudsDetalization", 2);
}

+ (void)setCloudsEnabled:(BOOL)aEnabled
{
	BOOL changed = _storedIntDiffers(@"CloudsEnabled", aEnabled);
	_setFlag(@"CloudsEnabled", aEnabled);
	if (changed) {
		if (aEnabled)
			[CWManager scheduleCloudsUpdateTask];
		else
			[CWManager unscheduleCloudsUpdateTask];
		_post(kCloudsEnableStateWasChanged, self);
	}
}

+ (BOOL)cloudsEnabled
{
	return _boolValue(@"CloudsEnabled", NO);
}

+ (void)setEarthTiltedMode:(BOOL)aMode
{
	_setFormatted(@"EarthTiltedMode", @"%d", (int)aMode);
}

+ (BOOL)earthTiltedMode
{
	return _boolValue(@"EarthTiltedMode", NO);
}

+ (void)setGlobeTransparencyLevel:(CGFloat)aLevel
{
	_setFormatted(@"GlobeTransparencyLevel", @"%f", (double)aLevel);
	_post(kGlobeTransparencyWasChanged, self);
}

+ (CGFloat)globeTransparencyLevel
{
	return _floatValue(@"GlobeTransparencyLevel", @"0.1");
}

+ (void)setMouseBehaviourOnMap:(NSInteger)aMap
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:(int)aMap] forKey:@"MouseBehaviourOnMap"];
}

+ (NSInteger)mouseBehaviourOnMap
{
	return [_storedValue(@"MouseBehaviourOnMap", [NSNumber numberWithInt:1]) intValue];
}

+ (void)setShowRouteLines:(BOOL)aLines
{
	_setFlag(@"ShowRouteLines", aLines);
}

+ (BOOL)showRouteLines
{
	return _boolValue(@"ShowRouteLines", YES);
}

+ (void)setShowAppleStores:(BOOL)aStores
{
	_setFlag(@"ShowAppleStores", aStores);
}

+ (BOOL)showAppleStores
{
	return _boolValue(@"ShowAppleStores", NO);
}

+ (void)setShowAllCountryBorders:(BOOL)aBorders
{
	_setFlag(@"ShowAllCountryBorders", aBorders);
}

+ (BOOL)showAllCountryBorders
{
	return _boolValue(@"ShowAllCountryBorders", NO);
}

+ (void)setShowTimeZoneEnabled:(BOOL)aEnabled
{
	_setFlag(@"ShowTimeZoneEnabled", aEnabled);
}

+ (BOOL)showTimeZoneEnabled
{
	return _boolValue(@"ShowTimeZoneEnabled", NO);
}

+ (void)setShowLocationNamesEnabled:(BOOL)aEnabled
{
	_setFlag(@"ShowLocationNamesEnabled", aEnabled);
}

+ (BOOL)showLocationNamesEnabled
{
	return _boolValue(@"ShowLocationNamesEnabled", YES);
}

+ (void)setShowLocationEnabled:(BOOL)aEnabled
{
	_setFlag(@"ShowLocationEnabled", aEnabled);
}

+ (BOOL)showLocationEnabled
{
	return _boolValue(@"ShowLocationEnabled", NO);
}

+ (void)setNearestCityEnabled:(BOOL)aEnabled
{
	_setFlag(@"NearestCityEnabled", aEnabled);
}

+ (BOOL)nearestCityEnabled
{
	return _boolValue(@"NearestCityEnabled", NO);
}

+ (void)setRegionHighLightMode:(NSInteger)aMode
{
	_setFormatted(@"kRegionHltMode", @"%d", (int)aMode);
}

+ (NSInteger)regionHighLightMode
{
	return [_storedValue(@"kRegionHltMode", @"0") intValue];
}

+ (void)setRegionHighlightEnabled:(BOOL)aEnabled
{
	_setFlag(@"RegionHltEnabled", aEnabled);
}

+ (BOOL)regionHighlightIsEnabled
{
	return _boolValue(@"RegionHltEnabled", NO);
}

+ (void)setDayNightEnabled:(BOOL)aEnabled
{
	_setFlag(@"DayNightEnabled", aEnabled);
}

+ (BOOL)dayNightIsEnabled
{
	return _boolValue(@"DayNightEnabled", NO);
}

+ (void)setSpaceEnabled:(BOOL)aEnabled
{
	[self setSunEnabled:aEnabled];
	[self setMoonEnabled:aEnabled];
	[self setStarsEnabled:aEnabled];
}

+ (BOOL)spaceEnabled
{
	return [self moonEnabled] || [self sunEnabled] || [self starsEnabled];
}

+ (void)setPreviousMoonEnabled:(BOOL)aEnabled
{
	_setFlag(@"PreviousMoonEnabled", aEnabled);
}

+ (BOOL)previousMoonEnabled
{
	return _boolValue(@"PreviousMoonEnabled", NO);
}

+ (void)setPreviousSunEnabled:(BOOL)aEnabled
{
	_setFlag(@"PreviousSunEnabled", aEnabled);
}

+ (BOOL)previousSunEnabled
{
	return _boolValue(@"PreviousSunEnabled", NO);
}

+ (void)setPreviousStarsEnabled:(BOOL)aEnabled
{
	_setFlag(@"PreviousStarsEnabled", aEnabled);
}

+ (BOOL)previousStarsEnabled
{
	return _boolValue(@"PreviousStarsEnabled", NO);
}

+ (void)setMoonEnabled:(BOOL)aEnabled
{
	_setFlag(@"MoonEnabled", aEnabled);
}

+ (BOOL)moonEnabled
{
	return _boolValue(@"MoonEnabled", YES);
}

+ (void)setSunEnabled:(BOOL)aEnabled
{
	_setFlag(@"SunEnabled", aEnabled);
}

+ (BOOL)sunEnabled
{
	return _boolValue(@"SunEnabled", YES);
}

+ (void)setStarsEnabled:(BOOL)aEnabled
{
	_setFlag(@"StarsEnabled", aEnabled);
}

+ (BOOL)starsEnabled
{
	return _boolValue(@"StarsEnabled", YES);
}

+ (void)setupBeforeMainWindowLoad
{
	static NSString *const viewKeys[] = {
		@"StarsEnabled", @"SunEnabled", @"MoonEnabled", @"DayNightEnabled", @"RegionHltEnabled",
		@"NearestCityEnabled", @"ShowLocationEnabled", @"ShowLocationNamesEnabled", @"ShowTimeZoneEnabled",
		@"ShowAllCountryBorders", @"ShowAppleStores", @"ShowRouteLines", @"GridEnabled", @"CloudsEnabled",
		@"MouseBehaviourOnMap", @"MarkersScale", @"AutomoveSpeed", @"DrawAllCities", @"MapMode",
		@"EarthTiltedMode", @"GlobeTransparencyLevel", @"CloudsAnimationTime",
		@"SphereMapController_scale", @"FlatMapController_scale"
	};
	NSUserDefaults *defaults;
	NSUInteger i;

	if ([self retainLastView])
		return;
	defaults = [NSUserDefaults standardUserDefaults];
	for (i = 0; i < sizeof(viewKeys) / sizeof(viewKeys[0]); i++)
		[defaults removeObjectForKey:viewKeys[i]];
}

@end
