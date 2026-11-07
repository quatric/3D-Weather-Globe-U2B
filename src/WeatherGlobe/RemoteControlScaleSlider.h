#import "WeatherGlobePrefix.h"
#import "StartStopTrackNotifySlider.h"


@interface RemoteControlScaleSlider : StartStopTrackNotifySlider
{
}
+ (Class)cellClass;
- (id)initWithCoder:(id)aCoder;
@end

@interface RemoteControlScaleSliderCell : NSSliderCell
{
}
- (void)drawKnob:(NSRect)aKnob;
@end

