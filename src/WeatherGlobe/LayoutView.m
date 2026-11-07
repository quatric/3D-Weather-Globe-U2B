#import "LayoutView.h"

// Subviews are grouped by tag / 100 and moved as the window widens:
// 3 centered, 5 stretched from the left, 6 stretched to the right,
// 9 and 11 spread from the left, 10 and 12 spread to the right.

static NSInteger _sortSubviews(id a, id b, void *context)
{
    CGFloat xa = NSMinX([a frame]), xb = NSMinX([b frame]);
    return xa < xb ? -1 : xb < xa;
}

static NSInteger _sortFrames(id a, id b, void *context)
{
    CGFloat xa = NSMinX([a rectValue]), xb = NSMinX([b rectValue]);
    return xa < xb ? -1 : xb < xa;
}

@implementation LayoutView

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_subviewsDict release];
    [_initFramesDict release];
    [super dealloc];
}

- (void)awakeFromNib
{
    _subviewsDict = [NSMutableDictionary new];
    _initFramesDict = [NSMutableDictionary new];
    _wnd = [self window];
    _initSize = [_wnd minSize];
    [self _initSubviews];
    [self setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:)
                                                 name:NSViewFrameDidChangeNotification object:self];
    [self frameDidChange:nil];
    [self setNeedsDisplay:YES];
}

- (void)frameDidChange:(id)aChange
{
    _dWidth = (int)((NSWidth([_wnd frame]) - _initSize.width) * 0.5f);
    [self _xCenterPosition];
    [self _leftFill];
    [self _rightFill];
    [self _xLeftProportional:9];
    [self _xLeftProportional:11];
    [self _xRightProportional:10];
    [self _xRightProportional:12];
}

- (void)_rightFill
{
    NSString *key = [NSString stringWithFormat:@"%d", 6];
    NSArray *views = [_subviewsDict objectForKey:key];
    if (views == nil)
        return;
    NSArray *frames = [_initFramesDict objectForKey:key];
    NSUInteger count = [views count], i;
    for (i = 0; i < count; i++) {
        NSRect frame = [[frames objectAtIndex:i] rectValue];
        frame.origin.x += _dWidth;
        frame.size.width += _dWidth + 1;
        [[views objectAtIndex:i] setFrame:frame];
    }
}

- (void)_leftFill
{
    NSString *key = [NSString stringWithFormat:@"%d", 5];
    NSArray *views = [_subviewsDict objectForKey:key];
    if (views == nil)
        return;
    NSArray *frames = [_initFramesDict objectForKey:key];
    NSUInteger count = [views count], i;
    for (i = 0; i < count; i++) {
        NSRect frame = [[frames objectAtIndex:i] rectValue];
        [[views objectAtIndex:i] setFrameSize:NSMakeSize(NSWidth(frame) + _dWidth, NSHeight(frame))];
    }
}

- (void)_xCenterPosition
{
    NSString *key = [NSString stringWithFormat:@"%d", 3];
    NSArray *views = [_subviewsDict objectForKey:key];
    if (views == nil)
        return;
    NSArray *frames = [_initFramesDict objectForKey:key];
    NSUInteger count = [views count], i;
    for (i = 0; i < count; i++) {
        NSRect frame = [[frames objectAtIndex:i] rectValue];
        [[views objectAtIndex:i] setFrameOrigin:NSMakePoint(NSMinX(frame) + _dWidth, NSMinY(frame))];
    }
}

- (void)_xRightProportional:(NSInteger)aProportional
{
    NSString *key = [NSString stringWithFormat:@"%d", (int)aProportional];
    NSArray *views = [_subviewsDict objectForKey:key];
    if (views == nil)
        return;
    NSArray *frames = [_initFramesDict objectForKey:key];
    int count = (int)[views count], i, step = _dWidth / (count + 1), offset = 0;
    for (i = 0; i < count; i++) {
        NSRect frame = [[frames objectAtIndex:i] rectValue];
        offset += step;
        [[views objectAtIndex:i] setFrameOrigin:NSMakePoint(NSMinX(frame) + (offset + _dWidth), NSMinY(frame))];
    }
}

- (void)_xLeftProportional:(NSInteger)aProportional
{
    NSString *key = [NSString stringWithFormat:@"%d", (int)aProportional];
    NSArray *views = [_subviewsDict objectForKey:key];
    if (views == nil)
        return;
    NSArray *frames = [_initFramesDict objectForKey:key];
    int count = (int)[views count], i, step = _dWidth / (count + 1), offset = 0;
    for (i = 0; i < count; i++) {
        NSRect frame = [[frames objectAtIndex:i] rectValue];
        offset += step;
        [[views objectAtIndex:i] setFrameOrigin:NSMakePoint(NSMinX(frame) + offset, NSMinY(frame))];
    }
}

- (void)_initSubviews
{
    NSArray *subviews = [[self contentView] subviews];
    NSUInteger count = [subviews count], i;
    for (i = 0; i < count; i++) {
        NSView *view = [subviews objectAtIndex:i];
        NSInteger group = [view tag] / 100;
        if (group < 1 || group > 12)
            continue;
        NSString *key = [NSString stringWithFormat:@"%d", (int)group];
        NSMutableArray *views = [_subviewsDict objectForKey:key];
        if (views == nil) {
            views = [NSMutableArray array];
            [_subviewsDict setObject:views forKey:key];
        }
        [views addObject:view];
        NSMutableArray *frames = [_initFramesDict objectForKey:key];
        if (frames == nil) {
            frames = [NSMutableArray array];
            [_initFramesDict setObject:frames forKey:key];
        }
        // The original kept the frames as raw 16-byte NSData; NSRect is wider on 64-bit.
        [frames addObject:[NSValue valueWithRect:[view frame]]];
    }
    [self _sortArraysForTag:9];
    [self _sortArraysForTag:10];
    [self _sortArraysForTag:11];
    [self _sortArraysForTag:12];
}

- (void)_sortArraysForTag:(NSInteger)aTag
{
    NSString *key = [NSString stringWithFormat:@"%d", (int)aTag];
    [[_subviewsDict objectForKey:key] sortUsingFunction:_sortSubviews context:NULL];
    [[_initFramesDict objectForKey:key] sortUsingFunction:_sortFrames context:NULL];
}

@end
