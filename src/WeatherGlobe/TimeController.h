#import "WeatherGlobePrefix.h"


@interface TimeController : NSObject
{
    AtlasController *_atlasController;
    BOOL _nibWasLoaded;
    NSPanel *_palette;
    NSTextField *_yearField;
    NSTextField *_dayField;
    NSTextField *_timeField;
    NSSlider *_timeSlider;
    NSTimer *_dateTimer;
    NSCalendarDate *_date;
    BOOL _usesCustomTime;
    float _customYear;
    float _customDayTime;
    float _customDayNumber;
}
- (void)setDayMonthYearFromDate:(id)aDate;
- (void)setDayNumber:(NSInteger)aNumber;
- (void)setNormalizedDayTime:(CGFloat)aTime;
- (void)setYear:(NSInteger)aYear;
- (void)setUseCustomTime:(BOOL)aTime;
- (BOOL)usesCustomTime;
- (void)timeWasChanged:(id)aChanged;
- (void)showPalette;
- (id)currentDate;
- (void)_updateCurrentDate:(id)aDate;
- (void)dealloc;
- (void)invalidateTimer;
- (id)initWithAtlasController:(id)aController;
- (void)_evalCurrentDate;
@end

