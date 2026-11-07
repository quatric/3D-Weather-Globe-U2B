#import "PrintingView.h"

@implementation PrintingView

// Atlas pages printed above 100% are tiled: an n x n grid over the map, page 1 at the top left.
- (NSRect)rectForPage:(NSInteger)aPage
{
    [_controller preparePage:aPage];
    float scale = [_controller printScale];
    NSRect bounds = [self bounds];
    if ([_controller isPrintAtlas] && aPage <= [_controller mapPageCount] && scale > 1.0f) {
        int perRow = (int)sqrt((double)[_controller mapPageCount]);
        CGFloat w = NSWidth(bounds) / scale, h = NSHeight(bounds) / scale;
        return NSMakeRect((float)((aPage - 1) % perRow) * w + NSMinX(bounds),
                          ((1.0f - 1.0f / scale) * NSHeight(bounds) + NSMinY(bounds)) - (float)((aPage - 1) / perRow) * h,
                          w, h);
    }
    return bounds;
}

- (BOOL)knowsPageRange:(NSRange *)aRange
{
    aRange->location = 1;
    aRange->length = [_controller pageCount];
    return YES;
}

- (id)printJobTitle
{
    NSString *title = [_controller printJobTitle];
    if (title != nil && ![title isEqualToString:@""])
        return title;
    return [super printJobTitle];
}

- (void)drawRect:(NSRect)aRect
{
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)dealloc
{
    _controller = nil;
    [super dealloc];
}

- (void)setPrintController:(id)aController
{
    _controller = aController;
}

- (id)initWithFrame:(NSRect)aFrame
{
    return [super initWithFrame:aFrame];
}

@end
