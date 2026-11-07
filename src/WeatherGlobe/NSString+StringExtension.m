#import "NSString+StringExtension.h"

static NSString *_shortS, *_shortN, *_latitudeFormat;
static NSString *_shortW, *_shortE, *_longitudeFormat;
static NSArray *_monthesAbbreviations;
static NSArray *_weekdaysAbbreviations;

@implementation NSString (StringExtension)

// "<latitude>/<longitude>", the point being (longitude, latitude)
+ (id)shortGeoCoordinatesDescription:(NSPoint)aDescription
{
	NSString *longitude = [self longitudeDesription:aDescription.x];
	NSString *latitude = [self latitudeDesription:aDescription.y];
	return [NSString stringWithFormat:@"%@ / %@", latitude, longitude];
}

+ (id)latitudeDesription:(CGFloat)aDesription
{
	WGDegrees degrees = _degreesFromFloat(aDesription);
	NSBundle *bundle = [NSBundle mainBundle];
	if (_shortS == nil) {
		_shortS = [bundle localizedStringForKey:@"Short name for 'South'" value:@"" table:nil];
	}
	if (_shortN == nil) {
		_shortN = [[NSBundle mainBundle] localizedStringForKey:@"Short name for 'North'" value:@"" table:nil];
	}
	if (_latitudeFormat == nil) {
		_latitudeFormat = [[NSBundle mainBundle] localizedStringForKey:@"GeoCoordinate description format" value:@"" table:nil];
	}
	return [NSString stringWithFormat:_latitudeFormat, (double)degrees.degrees, (double)degrees.minutes,
	                                  (double)degrees.seconds, degrees.negative ? _shortS : _shortN];
}

+ (id)longitudeDesription:(CGFloat)aDesription
{
	WGDegrees degrees = _degreesFromFloat(aDesription);
	if (_shortW == nil) {
		_shortW = [[NSBundle mainBundle] localizedStringForKey:@"Short name for 'West'" value:@"" table:nil];
	}
	if (_shortE == nil) {
		_shortE = [[NSBundle mainBundle] localizedStringForKey:@"Short name for 'East'" value:@"" table:nil];
	}
	if (_longitudeFormat == nil) {
		_longitudeFormat = [[NSBundle mainBundle] localizedStringForKey:@"GeoCoordinate description format" value:@"" table:nil];
	}
	return [NSString stringWithFormat:_longitudeFormat, (double)degrees.degrees, (double)degrees.minutes,
	                                  (double)degrees.seconds, degrees.negative ? _shortW : _shortE];
}

// the abbreviated name of a month, 1 to 12
+ (id)monthAbbreviation:(NSInteger)aAbbreviation
{
	if (_monthesAbbreviations == nil) {
		NSCalendarDate *date = [NSCalendarDate calendarDate];
		NSMutableArray *names = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", nil];
		for (int i = 0; i < 12; i++) {
			[names replaceObjectAtIndex:[date monthOfYear] - 1 withObject:[date descriptionWithCalendarFormat:@"%b"]];
			date = [date dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
		}
		_monthesAbbreviations = [[NSArray alloc] initWithArray:names];
	}
	return [_monthesAbbreviations objectAtIndex:((int)aAbbreviation - 1) % 12];
}

// the abbreviated name of a weekday, 0 (Sunday) to 6
+ (id)weekdayAbbreviation:(NSInteger)aAbbreviation
{
	if (_weekdaysAbbreviations == nil) {
		NSCalendarDate *date = [NSCalendarDate calendarDate];
		NSMutableArray *names = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", nil];
		for (int i = 0; i < 7; i++) {
			[names replaceObjectAtIndex:[date dayOfWeek] withObject:[date descriptionWithCalendarFormat:@"%a"]];
			date = [date dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
		}
		_weekdaysAbbreviations = [[NSArray alloc] initWithArray:names];
	}
	return [_weekdaysAbbreviations objectAtIndex:(int)aAbbreviation % 7];
}

@end
