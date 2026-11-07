#import "EFOneDayController.h"

@implementation EFOneDayController

- (void)setValues:(id)aValues
{
    int weekday = [[aValues objectForKey:@"DAY_OF_WEEK"] intValue];
    [_weekday setStringValue:weekday < 1 ? @"" : [NSString weekdayAbbreviation:weekday - 1]];
    NSString *value = [aValues temperatureForKey:@"COMFORT_LEVEL"];
    [_comfortLevel setStringValue:value ? value : @""];
    value = [aValues speedForKey:@"WIND_SPEED"];
    [_windSpeed setStringValue:value ? value : @""];
    value = [aValues percentsForKey:@"HUMIDITY"];
    [_humidity setStringValue:value ? value : @""];
    [_summary setImage:[aValues weatherImageForKey:@"SUMMARY_CODE"]];
    [_windDirection setImage:[aValues windImageForKey:@"WIND_DIR"]];
    value = [aValues temperatureForKey:@"TEMPERATURE_HIGH"];
    [_temperatureHigh setStringValue:value ? value : @""];
    value = [aValues temperatureForKey:@"TEMPERATURE_LOW"];
    [_temperatureLow setStringValue:value ? value : @""];
    value = [aValues percentsForKey:@"PRECIPTATIONS_PROBABILITY"];
    [_precipitation setStringValue:value ? value : @""];
    value = [aValues temperatureForKey:@"DEW_POINT"];
    [_dewPoint setStringValue:value ? value : @""];
    // The original passed nil through; modern NSTextField raises on that.
    value = [aValues objectForKey:@"UV_TEXT"];
    [_uvIndex setStringValue:value ? value : @""];
}

- (void)setScaleCoef:(CGFloat)aCoef
{
    [_summary scaleUnitSquareToSize:NSMakeSize(aCoef, aCoef)];
    [_windDirection scaleUnitSquareToSize:NSMakeSize(aCoef, aCoef)];
}

- (id)helpTextView
{
    return _helpTextView;
}

- (id)dataView
{
    return _dataView;
}

- (id)init
{
    self = [super init];
    if (self != nil)
        [NSBundle loadNibNamed:@"EFOneDayView" owner:self];
    return self;
}

- (void)awakeFromNib
{
    [self setValues:nil];
}

@end
