#import "GlobeUtils.h"

// The sun and moon directions in the Earth's frame for the current time.
// They're cached and recomputed once a minute.
@implementation GlobeUtils

/* i386 ivar offsets: _lightDirIsValid=0x4, _lightDirection=0x8, _moonDirIsValid=0x14, _moonDirection=0x18, _autoUpdateTimer=0x24 */

- (void)_worldTimeWasChanged:(id)aChanged
{
	_lightDirIsValid = NO;
	_moonDirIsValid = NO;
}

- (SMK_GL_Vec3)moonDirection
{
	if (!_moonDirIsValid) {
		[self _calculateMoonDirection];
	}
	return _moonDirection;
}

- (SMK_GL_Vec3)lightDirection
{
	if (!_lightDirIsValid) {
		[self _calculateLightDirection];
	}
	return _lightDirection;
}

// fraction of the synodic month (29.53 days) since a new moon
- (CGFloat)moonPhase
{
	double t = [[NSCalendarDate calendarDate] timeIntervalSince1970] / 2360591.4996 + 0.36000001430511475;
	return (float)(t - floor(t));
}

- (CGFloat)normalizedYearPhase
{
	double t = [[NSCalendarDate calendarDate] timeIntervalSince1970] / 31556927.8 - 0.211;
	return (float)(t - floor(t));
}

- (CGFloat)yearPhase
{
	NSCalendarDate *date = [NSCalendarDate calendarDate];
	NSInteger day = [date dayOfYear];
	NSInteger year = [date yearOfCommonEra];
	float dayPhase = (float)[self GMTDayPhase];
	if ((year & 3) == 0) {
		return ((float)day + dayPhase) / 366.0f;
	}
	return ((float)day + dayPhase) / 365.0f;
}

- (CGFloat)GMTDayPhase
{
	NSCalendarDate *date = [NSCalendarDate calendarDate];
	float local = (float)[self localDayPhase];
	float phase = (float)(int)[[date timeZone] secondsFromGMTForDate:date] / -86400.0f + local;
	return phase - floorf(phase);
}

- (CGFloat)localDayPhase
{
	NSCalendarDate *date = [NSCalendarDate calendarDate];
	return (float)[date hourOfDay] / 24.0f + (float)[date minuteOfHour] / 1440.0f +
	       (float)[date secondOfMinute] / 86400.0f;
}

- (void)_calculateMoonDirection
{
	_moonDirIsValid = YES;
	float phase = (float)[self moonPhase];
	float day = (float)[self GMTDayPhase];
	float year = (float)[self normalizedYearPhase];
	_moonDirection = _moonDirection_EarthSystem(year, day, phase);
}

- (void)_calculateLightDirection
{
	_lightDirIsValid = YES;
	float day = (float)[self GMTDayPhase];
	float year = (float)[self normalizedYearPhase];
	_lightDirection = _lightDirection_EarthSystem(year, day);
}

- (void)dealloc
{
	[_autoUpdateTimer invalidate];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_lightDirIsValid = NO;
		_moonDirIsValid = NO;
		_autoUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:60.0 target:self
		                                                  selector:@selector(_worldTimeWasChanged:)
		                                                  userInfo:nil repeats:YES];
	}
	return self;
}

@end
