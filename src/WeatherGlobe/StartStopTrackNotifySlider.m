#import "StartStopTrackNotifySlider.h"

@implementation StartStopTrackNotifySlider

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)aDelegate
{
    _delegate = aDelegate;
}

- (void)mouseUp:(id)aUp
{
    [super mouseUp:aUp];
    NSNotification *notification = [NSNotification notificationWithName:StartStopTrackNotifySliderDidStopTrackingNotification
                                                                  object:self];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    if ([_delegate respondsToSelector:@selector(sliderDidStopTracking:)])
        [_delegate sliderDidStopTracking:notification];
}

- (void)mouseDown:(id)aDown
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSNotification *notification = [NSNotification notificationWithName:StartStopTrackNotifySliderWillStartTrackingNotification
                                                                  object:self];
    [center postNotification:notification];
    if ([_delegate respondsToSelector:@selector(sliderWillStartTracking:)])
        [_delegate sliderWillStartTracking:notification];
    // NSSlider tracks the mouse inside -mouseDown:, so tracking has ended when it returns.
    [super mouseDown:aDown];
    notification = [NSNotification notificationWithName:StartStopTrackNotifySliderDidStopTrackingNotification object:self];
    [center postNotification:notification];
    if ([_delegate respondsToSelector:@selector(sliderDidStopTracking:)])
        [_delegate sliderDidStopTracking:notification];
}

@end
