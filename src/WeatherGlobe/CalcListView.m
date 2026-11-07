#import "CalcListView.h"

static NSString *_entryCaption(id aEntry)
{
    if ([aEntry isKindOfClass:[GeoLocCityEntry class]])
        return [aEntry shortCaption];
    NSPoint coordinates = [aEntry coordinates];
    return [NSString stringWithFormat:@"%@(%@, %@)", [aEntry shortCaption], [NSString latitudeDesription:coordinates.y], [NSString longitudeDesription:coordinates.x]];
}

@implementation CalcListView

- (void)drawRect:(NSRect)aRect
{
    NSInteger count = [_captions count];
    const NSRect *frames = [_cellFrames bytes];
    NSTextFieldCell *cell = [self textCell];
    [cell setFont:[self textFont]];
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSBezierPath *grid = [NSBezierPath bezierPath];
    CGFloat left = _layoutRect.origin.x;
    CGFloat right = left + _layoutRect.size.width;
    CGFloat y = _layoutRect.origin.y - _space.height;
    [path moveToPoint:NSMakePoint(left, y)];
    [path lineToPoint:NSMakePoint(right, y)];
    NSInteger i = _curIndex;
    do {
        do {
            if (i >= count)
                goto finish;
            if (i == count - 2) {
                [cell setFont:[self totalFont]];
                y = frames[_curIndex].origin.y;
                [path moveToPoint:NSMakePoint(left, y)];
                [path lineToPoint:NSMakePoint(right, y)];
                i = _curIndex;
            }
            [cell setStringValue:[_captions objectAtIndex:i]];
            [cell drawWithFrame:frames[_curIndex] inView:self];
            i = ++_curIndex;
        } while (i & 1);
        if (i < count - 2) {
            y = MAX(NSMaxY(frames[i - 2]), NSMaxY(frames[i - 1]));
            [grid moveToPoint:NSMakePoint(left, y)];
            [grid lineToPoint:NSMakePoint(right, y)];
            i = _curIndex;
        }
    } while (i < count && frames[i].origin.y != _layoutRect.origin.y);
finish:
    if (i > 0) {
        CGFloat x = frames[i - 1].origin.x - _space.width;
        [grid moveToPoint:NSMakePoint(x, 0)];
        [grid lineToPoint:NSMakePoint(x, NSMaxY(frames[i - 1]))];
    }
    [grid setLineWidth:0.5];
    [[NSColor lightGrayColor] set];
    [grid stroke];
    [path setLineWidth:1.0];
    [[NSColor darkGrayColor] set];
    [path stroke];
}

- (void)preparePage:(NSInteger)aPage
{
    const int *starts = [_pageStarts bytes];
    _curIndex = starts[aPage - 1];
}

- (NSInteger)pageCount
{
    [self _precalcLayout];
    [self _prepareCaptions];
    return [self _layoutPages];
}

- (NSInteger)_layoutPages
{
    if (_entries == nil || [_entries count] == 0)
        return 0;
    NSInteger count = [_captions count];
    NSTextFieldCell *cell = [self textCell];
    [cell setFont:[self textFont]];
    if (_cellFrames == nil)
        _cellFrames = [[NSMutableData alloc] initWithCapacity:1024];
    [_cellFrames setLength:count * sizeof(NSRect)];
    if (_pageStarts == nil)
        _pageStarts = [[NSMutableData alloc] initWithCapacity:32];
    [_pageStarts setLength:0];
    int start = 0;
    [_pageStarts appendBytes:&start length:sizeof(start)];
    NSRect columns[2];
    columns[0] = NSMakeRect(_layoutRect.origin.x, _layoutRect.origin.y, _columnWidth[0], _layoutRect.size.height);
    columns[1] = NSMakeRect(_columnWidth[0] + _space.width, _layoutRect.origin.y, _columnWidth[1], _layoutRect.size.height);
    NSRect *frames = [_cellFrames mutableBytes];
    NSInteger pages = 1;
    for (int i = 0; i < count; i++) {
        int column = i & 1;
        if (i == count - 2)
            [cell setFont:[self totalFont]];
        [cell setStringValue:[_captions objectAtIndex:i]];
        frames[i].origin.x = columns[column].origin.x;
        if (i < 1)
            frames[i].origin.y = columns[column].origin.y;
        else if (column == 0)
            frames[i].origin.y = MAX(NSMaxY(frames[i - 2]), NSMaxY(frames[i - 1])) + _space.height;
        else
            frames[i].origin.y = frames[i - 1].origin.y;
        frames[i].size = [cell cellSizeForBounds:columns[column]];
        if (_layoutRect.origin.y + _layoutRect.size.height < NSMaxY(frames[i])) {
            frames[i].origin.y = columns[column].origin.y;
            [_pageStarts appendBytes:&i length:sizeof(i)];
            pages++;
        }
    }
    return pages;
}

- (void)_prepareCaptions
{
    NSInteger count = [_entries count];
    if (_captions == nil)
        _captions = [[NSMutableArray alloc] initWithCapacity:count * 2];
    [_captions removeAllObjects];
    BOOL metric = [Preferences usesMetricSystem];
    NSString *formatKey = metric ? @"TotalDistanceKmFormat" : @"TotalDistanceMiFormat";
    NSBundle *bundle = [NSBundle mainBundle];
    id previous = [_entries objectAtIndex:0];
    float total = 0.0f;
    if (count < 2) {
        if ([previous isKindOfClass:[GeoLocCityEntry class]])
            [_captions addObject:[NSString stringWithString:[previous shortCaption]]];
        else
            [_captions addObject:_entryCaption(previous)];
        [_captions addObject:[NSString stringWithFormat:[bundle localizedStringForKey:formatKey value:@"" table:nil], 0.0]];
    } else {
        for (NSInteger i = 1; i < count; i++) {
            id entry = [_entries objectAtIndex:i];
            [_captions addObject:[NSString stringWithFormat:@"%@ - %@", _entryCaption(previous), _entryCaption(entry)]];
            float distance = [entry distanceToEntry:previous];
            total += distance;
            if (!metric)
                distance = _milesFromKilometers(distance);
            [_captions addObject:[NSString stringWithFormat:[bundle localizedStringForKey:formatKey value:@"" table:nil], (double)distance]];
            previous = entry;
        }
    }
    [_captions addObject:[bundle localizedStringForKey:@"TotalDistance" value:@"" table:nil]];
    if (!metric)
        total = _milesFromKilometers(total);
    [_captions addObject:[NSString stringWithFormat:[bundle localizedStringForKey:formatKey value:@"" table:nil], (double)total]];
}

- (void)_precalcLayout
{
    [_locField setFont:[self totalFont]];
    [_distField setFont:[_locField font]];
    NSRect frame = [self frame];
    NSRect fieldFrame = [_locField frame];
    CGFloat fieldHeight = [[_locField cell] cellSize].height;
    _layoutRect.origin.x = 0.0;
    _layoutRect.origin.y = fieldHeight + _space.height;
    _layoutRect.size.width = frame.size.width;
    _layoutRect.size.height = frame.size.height - _layoutRect.origin.y;
    float width = frame.size.width - _space.width;
    _columnWidth[1] = ceilf(width / (_aspect + 1.0f));
    _columnWidth[0] = width - _columnWidth[1];
    [_locField setFrame:NSMakeRect(0, fieldFrame.origin.y, _columnWidth[0], fieldHeight)];
    [_distField setFrame:NSMakeRect(_columnWidth[0] + _space.width, fieldFrame.origin.y, _columnWidth[1], fieldHeight)];
    _curIndex = 0;
}

- (id)textCell
{
    if (_textCell == nil) {
        _textCell = [[NSTextFieldCell alloc] init];
        [_textCell setWraps:YES];
        [_textCell setFont:[self textFont]];
    }
    return _textCell;
}

- (id)totalFont
{
    return [NSFont boldSystemFontOfSize:_scaleCoef * 12.0f];
}

- (id)textFont
{
    return [NSFont systemFontOfSize:_scaleCoef * 10.0f];
}

- (void)dealloc
{
    [_entries release];
    [_textCell release];
    [_captions release];
    [_cellFrames release];
    [_pageStarts release];
    [super dealloc];
}

- (void)setScaleCoef:(CGFloat)aCoef
{
    _scaleCoef = (float)aCoef;
}

- (void)setEntries:(id)aEntries
{
    [_entries autorelease];
    _entries = [aEntries retain];
}

- (BOOL)isOpaque
{
    return YES;
}

- (BOOL)isFlipped
{
    return YES;
}

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self != nil) {
        _scaleCoef = 1.0f;
        _aspect = 2.0f;
        _space = NSMakeSize(4.0, 2.0);
    }
    return self;
}

@end
