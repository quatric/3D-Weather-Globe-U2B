#import "WeatherGlobePrefix.h"


@interface PrintingView : NSView
{
    PrintController *_controller;
}
- (NSRect)rectForPage:(NSInteger)aPage;
- (BOOL)knowsPageRange:(NSRange *)aRange;
- (id)printJobTitle;
- (void)drawRect:(NSRect)aRect;
- (BOOL)isOpaque;
- (void)dealloc;
- (void)setPrintController:(id)aController;
- (id)initWithFrame:(NSRect)aFrame;
@end

