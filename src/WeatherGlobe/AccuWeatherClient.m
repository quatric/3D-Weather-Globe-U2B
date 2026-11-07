#import "AccuWeatherClient.h"

static NSString *const _kAPIKeyDefault = @"AccuWeatherAPIKey";
static NSString *const _kLocationsDefault = @"AccuWeatherLocations";
static NSString *const _kHost = @"https://api.accuweather.com";

// answers are kept on disk briefly so clicking between cities doesn't refetch
static const NSTimeInterval _kCurrentLifetime = 10.0 * 60.0;
static const NSTimeInterval _kForecastLifetime = 60.0 * 60.0;

// AccuWeather icon numbers (1-44) to the app's 35 weather icons
static const int _kIconMap[45] = {
	35,
	1, 2, 4, 4, 3, 6, 7, 7, 35, 35,     // 1-10: sunny .. (9, 10 unused)
	9, 19, 18, 33, 22, 22, 21, 20, 29, 29, // 11-20: fog, showers, storms, rain, flurries
	29, 30, 30, 27, 27, 27, 35, 35, 28, 1, // 21-30: snow, ice, sleet, freezing rain, rain and snow, hot
	1, 11, 13, 14, 15, 15, 14, 17, 34, 34, // 31-40: cold, windy, night clear .. night showers
	34, 22, 29, 30,                     // 41-44: night storms, flurries, snow
};

enum { _kCurrent, _kForecast };

static NSMutableDictionary *_sPending;   // request URL -> completion blocks
static NSMutableSet *_sCancelled;        // "report:lat,lon" waiting to be dropped

static NSString *_apiKey(void)
{
	NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:_kAPIKeyDefault];
	return [key length] != 0 ? key : nil;
}

static NSString *_pointKey(NSPoint aPoint)
{
	return [NSString stringWithFormat:@"%.2f,%.2f", aPoint.y, aPoint.x];
}

static NSString *_escaped(id aValue)
{
	NSMutableString *string = [NSMutableString stringWithFormat:@"%@", aValue != nil ? aValue : @""];
	[string replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [string length])];
	return string;
}

// appends name="value" for each pair whose value is not nil or NSNull
static void _appendAttributes(NSMutableString *aXML, NSArray *aPairs)
{
	NSUInteger i;
	for (i = 0; i + 1 < [aPairs count]; i += 2) {
		id value = [aPairs objectAtIndex:i + 1];
		if (value != nil && value != [NSNull null])
			[aXML appendFormat:@" %@=\"%@\"", [aPairs objectAtIndex:i], _escaped(value)];
	}
}

static id _path(id aObject, NSString *aPath)
{
	id value = aObject;
	for (NSString *part in [aPath componentsSeparatedByString:@"."]) {
		if (![value isKindOfClass:[NSDictionary class]])
			return nil;
		value = [value objectForKey:part];
	}
	return value == [NSNull null] ? nil : value;
}

static NSString *_icon(id aNumber)
{
	int icon = [aNumber intValue];
	return [NSString stringWithFormat:@"%d", (icon >= 1 && icon <= 44) ? _kIconMap[icon] : 35];
}

// "2026-10-22T07:58:00-05:00" -> "07:58AM", the local time CPAstronomyForecastView reads
static NSString *_clockTime(NSString *aISODate)
{
	int hour, minute;
	if (![aISODate isKindOfClass:[NSString class]] || [aISODate length] < 16)
		return nil;
	hour = [[aISODate substringWithRange:NSMakeRange(11, 2)] intValue];
	minute = [[aISODate substringWithRange:NSMakeRange(14, 2)] intValue];
	return [NSString stringWithFormat:@"%02d:%02d%@", hour % 12 == 0 ? 12 : hour % 12, minute, hour < 12 ? @"AM" : @"PM"];
}

// 1 is Sunday, from the date part of an ISO date
static NSString *_dayOfWeek(NSString *aISODate)
{
	NSDateComponents *components;
	NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
	if (![aISODate isKindOfClass:[NSString class]] || [aISODate length] < 10)
		return nil;
	[calendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	components = [[[NSDateComponents alloc] init] autorelease];
	[components setYear:[[aISODate substringWithRange:NSMakeRange(0, 4)] intValue]];
	[components setMonth:[[aISODate substringWithRange:NSMakeRange(5, 2)] intValue]];
	[components setDay:[[aISODate substringWithRange:NSMakeRange(8, 2)] intValue]];
	return [NSString stringWithFormat:@"%ld", (long)[calendar component:NSCalendarUnitWeekday
		fromDate:[calendar dateFromComponents:components]]];
}

static NSString *_cacheFolder(void)
{
	NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
	NSString *folder = [caches stringByAppendingPathComponent:@"com.mackiev.3dweatherglobe/AccuWeather"];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
	return folder;
}

@implementation AccuWeatherClient

+ (BOOL)isEnabled
{
	return _apiKey() != nil;
}

// Calls aCompletion on the main thread with the parsed JSON, or nil.
+ (void)_fetchJSON:(NSString *)aPath cacheName:(NSString *)aName lifetime:(NSTimeInterval)aLifetime
	completion:(void (^)(id aJSON))aCompletion
{
	NSString *cachePath = aName != nil ? [_cacheFolder() stringByAppendingPathComponent:aName] : nil;
	NSDate *modified = cachePath != nil ? [[[NSFileManager defaultManager] attributesOfItemAtPath:cachePath error:NULL] fileModificationDate] : nil;
	NSString *url;
	NSMutableArray *waiting;

	if (modified != nil && -[modified timeIntervalSinceNow] < aLifetime) {
		id json = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:cachePath] options:0 error:NULL];
		if (json != nil) {
			aCompletion(json);
			return;
		}
	}
	url = [NSString stringWithFormat:@"%@/%@%@apikey=%@", _kHost, aPath,
		[aPath rangeOfString:@"?"].location == NSNotFound ? @"?" : @"&", _apiKey()];
	if (_sPending == nil)
		_sPending = [NSMutableDictionary new];
	waiting = [_sPending objectForKey:url];
	if (waiting != nil) {
		[waiting addObject:[[aCompletion copy] autorelease]];
		return;
	}
	waiting = [NSMutableArray arrayWithObject:[[aCompletion copy] autorelease]];
	[_sPending setObject:waiting forKey:url];

	[[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url]
		completionHandler:^(NSData *aData, NSURLResponse *aResponse, NSError *aError) {
		NSInteger status = [aResponse isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)aResponse statusCode] : 0;
		id json = (status == 200 && aData != nil) ? [NSJSONSerialization JSONObjectWithData:aData options:0 error:NULL] : nil;
		if (json == nil)
			NSLog(@"AccuWeather request %@ failed: HTTP %ld %@", aPath, (long)status, aError ? [aError localizedDescription] : @"");
		else if (cachePath != nil)
			[aData writeToFile:cachePath atomically:YES];
		dispatch_async(dispatch_get_main_queue(), ^{
			NSArray *blocks = [[[_sPending objectForKey:url] retain] autorelease];
			[_sPending removeObjectForKey:url];
			for (void (^block)(id) in blocks)
				block(json);
		});
	}] resume];
}

// the AccuWeather location for a point, kept in the defaults since it never changes
+ (void)_locationForPoint:(NSPoint)aPoint completion:(void (^)(NSDictionary *aLocation))aCompletion
{
	NSString *pointKey = _pointKey(aPoint);
	NSDictionary *known = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:_kLocationsDefault] objectForKey:pointKey];

	if (known != nil) {
		aCompletion(known);
		return;
	}
	[self _fetchJSON:[NSString stringWithFormat:@"locations/v1/cities/geoposition/search.json?q=%@", pointKey]
		cacheName:nil lifetime:0.0 completion:^(id aJSON) {
		NSMutableDictionary *all;
		NSDictionary *location;
		NSString *key = _path(aJSON, @"Key");
		if (key == nil) {
			aCompletion(nil);
			return;
		}
		location = [NSDictionary dictionaryWithObjectsAndKeys:key, @"Key",
			_path(aJSON, @"LocalizedName") ? _path(aJSON, @"LocalizedName") : @"", @"City",
			_path(aJSON, @"AdministrativeArea.LocalizedName") ? _path(aJSON, @"AdministrativeArea.LocalizedName") : @"", @"State",
			_path(aJSON, @"Country.LocalizedName") ? _path(aJSON, @"Country.LocalizedName") : @"", @"Country", nil];
		all = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:_kLocationsDefault]];
		[all setObject:location forKey:pointKey];
		[[NSUserDefaults standardUserDefaults] setObject:all forKey:_kLocationsDefault];
		aCompletion(location);
	}];
}

+ (NSMutableString *)_reportElementForLocation:(NSDictionary *)aLocation name:(NSString *)aName date:(id)aEpoch
{
	NSMutableString *xml = [NSMutableString stringWithString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<report"];
	_appendAttributes(xml, [NSArray arrayWithObjects:
		@"unix_date", aEpoch ? aEpoch : [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]],
		@"city_name", [aLocation objectForKey:@"City"], @"state_name", [aLocation objectForKey:@"State"],
		@"country_name", [aLocation objectForKey:@"Country"], @"metric", @"true", @"name", aName, nil]);
	[xml appendString:@">\n"];
	return xml;
}

+ (NSData *)_currentXMLFromJSON:(id)aJSON alerts:(id)aAlerts location:(NSDictionary *)aLocation
{
	id now = [aJSON isKindOfClass:[NSArray class]] && [aJSON count] != 0 ? [aJSON objectAtIndex:0] : nil;
	NSMutableString *xml;
	NSString *text;

	if (now == nil)
		return nil;
	text = _path(now, @"WeatherText");
	xml = [self _reportElementForLocation:aLocation name:@"current_conditions" date:_path(now, @"EpochTime")];
	[xml appendString:@"<observation"];
	_appendAttributes(xml, [NSArray arrayWithObjects:
		@"city", [aLocation objectForKey:@"Key"], @"city_name", [aLocation objectForKey:@"City"],
		@"daylight", [_path(now, @"IsDayTime") boolValue] ? @"D" : @"N",
		@"sky", text, @"description", text ? [text stringByAppendingString:@"."] : nil,
		@"temperature", _path(now, @"Temperature.Metric.Value"),
		@"wind_speed", _path(now, @"Wind.Speed.Metric.Value"), @"wind_dir", _path(now, @"Wind.Direction.Degrees"),
		@"humidity", _path(now, @"RelativeHumidity"), @"dew_point", _path(now, @"DewPoint.Metric.Value"),
		@"comfort", _path(now, @"RealFeelTemperature.Metric.Value"),
		@"baro_pressure", _path(now, @"Pressure.Metric.Value"), @"visibility", _path(now, @"Visibility.Metric.Value"),
		@"icon", _icon(_path(now, @"WeatherIcon")), nil]);
	[xml appendString:@" />\n"];
	// active watches and warnings; the old feed had these as a separate
	// severe_warning report that no view ever showed
	if ([aAlerts isKindOfClass:[NSArray class]]) {
		for (id alert in aAlerts) {
			id area = [_path(alert, @"Area") isKindOfClass:[NSArray class]] && [_path(alert, @"Area") count] != 0 ?
				[_path(alert, @"Area") objectAtIndex:0] : nil;
			if (_path(alert, @"Description.Localized") == nil)
				continue;
			[xml appendString:@"<warning"];
			_appendAttributes(xml, [NSArray arrayWithObjects:
				@"description", _path(alert, @"Description.Localized"), @"category", _path(alert, @"Category"),
				@"priority", _path(alert, @"Priority"), @"color", _path(alert, @"Color.Hex"),
				@"source", _path(alert, @"Source"), @"area", _path(area, @"Name"),
				@"start", _path(area, @"EpochStartTime"), @"end", _path(area, @"EpochEndTime"),
				@"summary", _path(area, @"Summary"), nil]);
			[xml appendString:@" />\n"];
		}
	}
	[xml appendString:@"</report>\n"];
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)_uvForDay:(id)aDay key:(NSString *)aKey
{
	for (id item in _path(aDay, @"AirAndPollen"))
		if ([_path(item, @"Name") isEqual:@"UVIndex"])
			return _path(item, aKey);
	return nil;
}

+ (NSData *)_forecastXMLFromJSON:(id)aJSON location:(NSDictionary *)aLocation report:(NSInteger)aReport
{
	NSArray *days = _path(aJSON, @"DailyForecasts");
	NSMutableString *xml;
	NSUInteger i;

	if ([days count] == 0)
		return nil;
	if (aReport == 2) {
		xml = [self _reportElementForLocation:aLocation name:@"expanded_forecast" date:nil];
		[xml appendString:@"<location"];
		_appendAttributes(xml, [NSArray arrayWithObjects:@"city", [aLocation objectForKey:@"Key"],
			@"city_name", [aLocation objectForKey:@"City"], nil]);
		[xml appendString:@">\n"];
		for (i = 0; i < [days count] && i < 7; i++) {
			id day = [days objectAtIndex:i];
			NSString *text = _path(day, @"Day.IconPhrase");
			[xml appendString:@"<forecast"];
			_appendAttributes(xml, [NSArray arrayWithObjects:
				@"day_of_week", _dayOfWeek(_path(day, @"Date")),
				@"low_temp", _path(day, @"Temperature.Minimum.Value"), @"high_temp", _path(day, @"Temperature.Maximum.Value"),
				@"precip_prob", _path(day, @"Day.PrecipitationProbability"),
				@"rainfall", _path(day, @"Day.Rain.Value"), @"snowfall", _path(day, @"Day.Snow.Value"),
				@"uv_index", [self _uvForDay:day key:@"Value"], @"uv", [self _uvForDay:day key:@"Category"],
				@"icon", _icon(_path(day, @"Day.Icon")),
				@"wind_speed", _path(day, @"Day.Wind.Speed.Value"), @"wind_dir", _path(day, @"Day.Wind.Direction.Degrees"),
				@"humidity", _path(day, @"Day.RelativeHumidity.Average"),
				@"sky", text, @"description", text ? [text stringByAppendingString:@"."] : nil,
				@"comfort", _path(day, @"RealFeelTemperature.Maximum.Value"), nil]);
			[xml appendString:@" />\n"];
		}
		[xml appendString:@"</location>\n</report>\n"];
	} else if (aReport == 3) {
		id today = [days objectAtIndex:0];
		id tomorrow = [days count] > 1 ? [days objectAtIndex:1] : nil;
		// the moon can rise or set after midnight; then the next day has it
		NSString *moonrise = _clockTime(_path(today, @"Moon.Rise")) ?: _clockTime(_path(tomorrow, @"Moon.Rise"));
		NSString *moonset = _clockTime(_path(today, @"Moon.Set")) ?: _clockTime(_path(tomorrow, @"Moon.Set"));
		xml = [self _reportElementForLocation:aLocation name:@"astronomy_forecast" date:nil];
		[xml appendString:@"<forecast"];
		_appendAttributes(xml, [NSArray arrayWithObjects:
			@"city", [aLocation objectForKey:@"Key"], @"city_name", [aLocation objectForKey:@"City"],
			@"sunrise", _clockTime(_path(today, @"Sun.Rise")) ?: @"", @"sunset", _clockTime(_path(today, @"Sun.Set")) ?: @"",
			@"moonrise", moonrise ?: @"", @"moonset", moonset ?: @"",
			@"moon_phase", [NSString stringWithFormat:@"%.2f", [_path(today, @"Moon.Age") doubleValue] / 29.53], nil]);
		[xml appendString:@" />\n</report>\n"];
	} else {
		// the extended forecast has no parser; warnings come with report 0
		xml = [self _reportElementForLocation:aLocation name:@"extended_forecast" date:nil];
		[xml appendString:@"</report>\n"];
	}
	return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

// reports: 0 current conditions (with warnings), 1 extended, 2 expanded (7 days), 3 astronomy
+ (void)loadReport:(NSInteger)aReport forEntry:(id)aEntry completion:(void (^)(NSData *aXML))aCompletion
{
	NSPoint point = [aEntry coordinates];
	NSString *token = [NSString stringWithFormat:@"%ld:%@", (long)aReport, _pointKey(point)];
	void (^finish)(NSData *) = [[^(NSData *aXML) {
		if ([_sCancelled containsObject:token]) {
			[_sCancelled removeObject:token];
			return;
		}
		aCompletion(aXML);
	} copy] autorelease];

	[_sCancelled removeObject:token];
	[self _locationForPoint:point completion:^(NSDictionary *aLocation) {
		NSString *key = [aLocation objectForKey:@"Key"];
		if (key == nil) {
			finish(nil);
			return;
		}
		if (aReport == 0) {
			[self _fetchJSON:[NSString stringWithFormat:@"currentconditions/v1/%@.json?details=true", key]
				cacheName:[key stringByAppendingString:@"-current.json"] lifetime:_kCurrentLifetime completion:^(id aJSON) {
				if (aJSON == nil) {
					finish(nil);
					return;
				}
				[self _fetchJSON:[NSString stringWithFormat:@"alerts/v1/%@.json?details=true", key]
					cacheName:[key stringByAppendingString:@"-alerts.json"] lifetime:_kCurrentLifetime completion:^(id aAlerts) {
					finish([self _currentXMLFromJSON:aJSON alerts:aAlerts location:aLocation]);
				}];
			}];
		} else {
			[self _fetchJSON:[NSString stringWithFormat:@"forecasts/v1/daily/10day/%@.json?details=true&metric=true", key]
				cacheName:[key stringByAppendingString:@"-daily.json"] lifetime:_kForecastLifetime completion:^(id aJSON) {
				finish([self _forecastXMLFromJSON:aJSON location:aLocation report:aReport]);
			}];
		}
	}];
}

+ (void)cancelReport:(NSInteger)aReport forEntry:(id)aEntry
{
	if (_sCancelled == nil)
		_sCancelled = [NSMutableSet new];
	[_sCancelled addObject:[NSString stringWithFormat:@"%ld:%@", (long)aReport, _pointKey([aEntry coordinates])]];
}

@end
