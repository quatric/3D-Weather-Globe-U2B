#import "NSCalendarDate+DescriptionsExtension.h"

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil];
}

@implementation NSCalendarDate (DescriptionsExtension)

// the month (1 to 12) whose abbreviation is widest, for sizing columns
+ (NSInteger)monthWithMaxAbbrDescriptionWidth
{
	float widest = 0.0f;
	NSInteger month = 0;
	for (int i = 0; i < 12; i++) {
		NSCalendarDate *date = [NSCalendarDate dateWithYear:0 month:i day:0 hour:0 minute:0 second:0 timeZone:nil];
		float width = [[date descriptionWithCalendarFormat:@"%b"] sizeWithAttributes:nil].width;
		if (widest < width) {
			month = [date monthOfYear];
			widest = width;
		}
	}
	return (int)month;
}

// the weekday (0 to 6) whose abbreviation is widest
+ (NSInteger)weekdayWithMaxAbbrDescriptionWidth
{
	float widest = 0.0f;
	NSInteger weekday = 0;
	for (int i = 0; i < 7; i++) {
		NSCalendarDate *date = [NSCalendarDate dateWithYear:0 month:0 day:i hour:0 minute:0 second:0 timeZone:nil];
		float width = [[date descriptionWithCalendarFormat:@"%a"] sizeWithAttributes:nil].width;
		if (widest < width) {
			weekday = [date dayOfWeek];
			widest = width;
		}
	}
	return (int)weekday;
}

// "10:30 PM Mon 2005-09-30 +03:00"
- (id)descriptionDateTime
{
	NSString *format = [Preferences uses24HourClock] ? @"%H:%M %a" : @"%I:%M %p %a";
	return [[[[[self descriptionWithCalendarFormat:format] stringByAppendingString:@" "]
	           stringByAppendingString:[self descriptionDate]] stringByAppendingString:@" "]
	           stringByAppendingString:[self descriptionGMTOffset]];
}

// The date in the user's short format where the Panther bundle provides one
// (in the system time zone, so shifted to keep this date's wall clock).
- (id)descriptionDate
{
	Class panther = [PantherSpecificClass principalClass];
	if (panther == nil) {
		return [self descriptionWithCalendarFormat:@"%Y-%m-%d"];
	}
	NSTimeInterval shift = (double)((int)[[self timeZone] secondsFromGMT] - (int)[[NSTimeZone systemTimeZone] secondsFromGMT]);
	return [panther stringWithLocaleShortDateFormatForAbsoluteTime:shift + [self timeIntervalSinceReferenceDate]];
}

- (id)descriptionTimeZone
{
	return [NSString stringWithFormat:@"%@ %@", [self descriptionGMTOffset], [self descriptionWithCalendarFormat:@"%Z"]];
}

// the offset from GMT as +hh:mm
- (id)descriptionGMTOffset
{
	NSMutableString *offset = [NSMutableString stringWithString:[self descriptionWithCalendarFormat:@"%z"]];
	[offset insertString:@":" atIndex:3];
	return offset;
}

@end

// Formats the values of a weather report (in metric units) in the units the
// user chose.
@implementation NSDictionary (CWExtension)

- (id)pressureForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	float pressure;
	NSString *format;
	if (metric == 0) {
		pressure = _inchesFromMiliBars([value floatValue]);
		format = _localized(@"PressureInches");
	} else if (metric == 1) {
		pressure = [value floatValue];
		format = _localized(@"PressureMiliBars");
	} else {
		return @"";
	}
	return [NSString stringWithFormat:format, (double)pressure];
}

// "<precipitation> <sky> <temperature>", each localized and ending in "."
- (id)weatherDescription
{
	NSMutableArray *parts = [NSMutableArray array];
	id text = [self objectForKey:@"PRECIPTATIONS_TEXT"];
	if (text != nil) {
		[parts addObject:[self _localizedDesc:text]];
	}
	text = [self objectForKey:@"SKY_TEXT"];
	if (text != nil) {
		[parts addObject:[self _localizedDesc:text]];
	}
	text = [self objectForKey:@"TEMPERATURE_TEXT"];
	if (text != nil) {
		[parts addObject:[self _localizedDesc:text]];
	}
	NSString *description = [parts componentsJoinedByString:@" "];
	NSString *warnings = [self warningsDescription];
	if (warnings != nil)
		description = [description length] != 0 ? [NSString stringWithFormat:@"%@\n%@", description, warnings] : warnings;
	return description;
}

// one line per active warning: "⚠ Coastal Flood Advisory until Sat 8:00 PM"
- (id)warningsDescription
{
	NSArray *warnings = [self objectForKey:@"WARNINGS"];
	NSMutableArray *lines = [NSMutableArray array];
	NSDateFormatter *formatter;
	if ([warnings count] == 0)
		return nil;
	formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocalizedDateFormatFromTemplate:@"EEEjmm"];
	for (NSDictionary *warning in warnings) {
		NSString *line = [NSString stringWithFormat:@"\u26A0 %@", [warning objectForKey:@"description"]];
		double end = [[warning objectForKey:@"end"] doubleValue];
		if (end > 0.0)
			line = [line stringByAppendingFormat:@" until %@", [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:end]]];
		[lines addObject:line];
	}
	return [lines componentsJoinedByString:@"\n"];
}

// the most severe warning's color, or nil without warnings
- (id)warningColor
{
	NSArray *warnings = [self objectForKey:@"WARNINGS"];
	unsigned int rgb;
	NSString *hex;
	if ([warnings count] == 0)
		return nil;
	hex = [[warnings objectAtIndex:0] objectForKey:@"color"];
	if ([hex length] != 7 || ![[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&rgb])
		return [NSColor redColor];
	return [NSColor colorWithCalibratedRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:1.0];
}

- (id)_localizedDesc:(id)aDesc
{
	return [_localized(aDesc) stringByAppendingString:@"."];
}

// the arrow for a wind direction in degrees, from the 31 wind icons
- (id)windImageForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return nil;
	}
	int index = (((([value intValue] + 180) % 360) / 10) * 31) / 35 + 1;
	return [[CWManager windImagesForIconAtIndex:index] objectAtIndex:0];
}

- (id)weatherImageForKey:(id)aKey
{
	NSInteger index = [self weatherImageIndexForKey:aKey];
	if (index == 0) {
		return nil;
	}
	return [[CWManager weatherImagesForIconAtIndex:index] objectAtIndex:0];
}

- (NSInteger)weatherImageIndexForKey:(id)aKey
{
	return [[self objectForKey:aKey] intValue];
}

- (id)percentsForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	return [NSString stringWithFormat:_localized(@"PercentsFormat"), [value intValue]];
}

- (id)distanceForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	if (metric == 0) {
		return [NSString stringWithFormat:_localized(@"TotalDistanceMiFormat"), (double)_milesFromKilometers([value floatValue])];
	}
	if (metric == 1) {
		return [NSString stringWithFormat:_localized(@"TotalDistanceKmFormat"), (double)[value floatValue]];
	}
	return @"";
}

- (id)speedValueForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	if (metric == 0) {
		return [NSString stringWithFormat:@"%.1f", (double)_milesFromKilometers([value floatValue])];
	}
	if (metric == 1) {
		return [NSString stringWithFormat:@"%.1f", (double)[value floatValue]];
	}
	return @"";
}

- (id)speedForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	if (metric == 0) {
		return [NSString stringWithFormat:_localized(@"SpeedMiFormat"), (double)_milesFromKilometers([value floatValue])];
	}
	if (metric == 1) {
		return [NSString stringWithFormat:_localized(@"SpeedKmFormat"), (double)[value floatValue]];
	}
	return @"";
}

- (id)temperatureForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	if (metric == 0) {
		return [NSString stringWithFormat:_localized(@"TemperatureFahrenheit"),
		                                  (int)lroundf(_fahrenheitFromCelsius([value floatValue]))];
	}
	if (metric == 1) {
		return [NSString stringWithFormat:_localized(@"TemperatureCelcius"), (int)lroundf([value floatValue])];
	}
	return @"";
}

- (id)shortTempratureForKey:(id)aKey
{
	id value = [self objectForKey:aKey];
	if (value == nil) {
		return @"";
	}
	char metric = [Preferences usesMetricSystem];
	if (metric == 0) {
		return [NSString stringWithFormat:_localized(@"ShortTemperatureFormat"),
		                                  (int)lroundf(_fahrenheitFromCelsius([value floatValue]))];
	}
	if (metric == 1) {
		return [NSString stringWithFormat:_localized(@"ShortTemperatureFormat"), (int)lroundf([value floatValue])];
	}
	return @"";
}

@end
