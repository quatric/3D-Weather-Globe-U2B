#import "WeatherGlobePrefix.h"


@interface WeatherPrintingView : NSView
{
    WeatherPrintController *_delegate;
}
- (NSRect)rectForPage:(NSInteger)aPage;
- (BOOL)knowsPageRange:(NSRange *)aRange;
- (id)printJobTitle;
- (BOOL)isOpaque;
@end

