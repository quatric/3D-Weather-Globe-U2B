#import "WeatherPrintingView.h"

@implementation WeatherPrintingView

- (NSRect)rectForPage:(NSInteger)aPage
{
    [_delegate preparePage:aPage];
    return [self bounds];
}

- (BOOL)knowsPageRange:(NSRange *)aRange
{
    aRange->location = 1;
    aRange->length = [_delegate pageCount];
    return YES;
}

- (id)printJobTitle
{
    return [_delegate printJobTitle];
}

- (BOOL)isOpaque
{
    return YES;
}

@end
