#import "WeatherGlobePrefix.h"


@interface StartStopTrackNotifySlider : NSSlider
{
    id _delegate;
}
- (id)delegate;
- (void)setDelegate:(id)aDelegate;
- (void)mouseUp:(id)aUp;
- (void)mouseDown:(id)aDown;
@end

