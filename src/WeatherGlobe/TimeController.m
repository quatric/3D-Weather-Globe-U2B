#import "TimeController.h"

@implementation TimeController

- (void)setDayMonthYearFromDate:(id)aDate
{
    _customYear = (float)[aDate yearOfCommonEra];
    _customDayNumber = (float)[aDate dayOfYear];
    if (_usesCustomTime)
        [self _evalCurrentDate];
}

- (void)setDayNumber:(NSInteger)aNumber
{
    _customDayNumber = (float)aNumber;
    if (_usesCustomTime)
        [self _evalCurrentDate];
}

- (void)setNormalizedDayTime:(CGFloat)aTime
{
    _customDayTime = (float)aTime;
    if (aTime >= 1.0)
        _customDayTime = 0.9999f;
    if (_usesCustomTime)
        [self _evalCurrentDate];
}

- (void)setYear:(NSInteger)aYear
{
    _customYear = (float)aYear;
    if (_usesCustomTime)
        [self _evalCurrentDate];
}

- (void)setUseCustomTime:(BOOL)aTime
{
    _usesCustomTime = aTime;
    [self _evalCurrentDate];
}

- (BOOL)usesCustomTime
{
    return _usesCustomTime;
}

- (void)timeWasChanged:(id)aChanged
{
    switch ([aChanged tag]) {
    case 1: {
        BOOL custom = [aChanged selectedRow] != 0;
        [_yearField setEnabled:custom];
        [_dayField setEnabled:custom];
        [_timeSlider setEnabled:custom];
        _usesCustomTime = custom;
        break;
    }
    case 2:
        _customYear = (float)[aChanged intValue];
        break;
    case 3:
        _customDayNumber = (float)[aChanged intValue];
        break;
    case 4:
        _customDayTime = [aChanged floatValue];
        break;
    }
    [self _evalCurrentDate];
}

- (void)showPalette
{
    if (!_nibWasLoaded) {
        [NSBundle loadNibNamed:@"TimeInfo" owner:self];
        _nibWasLoaded = YES;
        [self _evalCurrentDate];
    }
    [_palette makeKeyAndOrderFront:self];
}

- (id)currentDate
{
    return _date;
}

- (void)_updateCurrentDate:(id)aDate
{
    if (!_usesCustomTime)
        [self _evalCurrentDate];
}

- (void)dealloc
{
    [_dateTimer invalidate];
    [_palette release];
    [super dealloc];
}

- (void)invalidateTimer
{
    [_dateTimer invalidate];
    _dateTimer = nil;
}

- (id)initWithAtlasController:(id)aController
{
    self = [super init];
    if (self != nil) {
        _atlasController = aController;
        _date = [[NSCalendarDate calendarDate] retain];
        _dateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(_updateCurrentDate:) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)_evalCurrentDate
{
    [_date release];
    _date = nil;
    if (!_usesCustomTime) {
        _date = [[NSCalendarDate calendarDate] retain];
        _customYear = (float)[_date yearOfCommonEra];
        [_yearField setIntValue:(int)_customYear];
        _customDayNumber = (float)[_date dayOfYear];
        [_dayField setIntValue:(int)_customDayNumber];
        NSInteger seconds = [_date hourOfDay] * 3600 + [_date minuteOfHour] * 60 + [_date secondOfMinute];
        _customDayTime = (float)seconds / 86400.0f;
        [_timeSlider setFloatValue:_customDayTime];
    } else {
        NSCalendarDate *start = [NSCalendarDate dateWithYear:(NSInteger)_customYear month:0 day:0 hour:0 minute:0 second:0 timeZone:[NSTimeZone defaultTimeZone]];
        _date = [[start dateByAddingYears:0 months:0 days:(NSInteger)_customDayNumber hours:0 minutes:(NSInteger)(_customDayTime * 1440.0f) seconds:0] retain];
    }
    [_timeField setStringValue:[_date descriptionWithCalendarFormat:@"%H:%M:%S"]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kWorldTimeWasChanged object:self];
}

@end
