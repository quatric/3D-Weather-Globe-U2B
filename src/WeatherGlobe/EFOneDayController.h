#import "WeatherGlobePrefix.h"


@interface EFOneDayController : NSObject
{
    NSView *_dataView;
    NSView *_helpTextView;
    NSTextField *_weekday;
    NSTextField *_temperatureHigh;
    NSTextField *_temperatureLow;
    NSTextField *_precipitation;
    NSTextField *_comfortLevel;
    NSTextField *_windSpeed;
    NSTextField *_humidity;
    NSTextField *_dewPoint;
    NSTextField *_uvIndex;
    NSImageView *_summary;
    NSImageView *_windDirection;
}
- (void)setValues:(id)aValues;
- (void)setScaleCoef:(CGFloat)aCoef;
- (id)helpTextView;
- (id)dataView;
- (id)init;
- (void)awakeFromNib;
@end

