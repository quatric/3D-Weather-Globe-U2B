#import "CompassButton.h"

// The compass: a round control with a stop button in the middle and four
// arrow segments around it that spin the map. Its value is the segment
// pressed last (0 none, 1 stop, 2 left, 3 right, 4 up, 5 down).

// where each segment image is drawn (zones 1 to 5), then the whole compass;
// the view is flipped, so these are the images' bottom left corners
static const NSPoint _kImageOrigins[6] = {
    {16.0, 40.0}, {1.0, 48.0}, {36.0, 48.0}, {8.0, 20.0}, {8.0, 55.0}, {0.0, 57.0}
};

static void _drawImageAt(NSImage *aImage, NSPoint aPoint)
{
    NSSize size = [aImage size];
    [aImage drawInRect:NSMakeRect(aPoint.x, aPoint.y - size.height, size.width, size.height)
              fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
        respectFlipped:YES hints:nil];
}

@implementation CompassButton

+ (Class)cellClass
{
    return [CompassCell class];
}

+ (void)initialize
{
    if (self == [CompassButton class])
        [self setCellClass:[CompassCell class]];
}

- (void)performClick:(id)aClick
{
    [[self cell] performClick:aClick];
}

- (void)moveDown:(id)aDown
{
    [[self cell] moveDown:aDown];
}

- (void)moveUp:(id)aUp
{
    [[self cell] moveUp:aUp];
}

- (void)moveLeft:(id)aLeft
{
    [[self cell] moveLeft:aLeft];
}

- (void)moveRight:(id)aRight
{
    [[self cell] moveRight:aRight];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self resetToolTipRects];
}

- (void)viewWillMoveToWindow:(id)aWindow
{
    if ([self window] != nil)
        [self removeAllToolTips];
    [super viewWillMoveToWindow:aWindow];
}

- (void)resetToolTipRects
{
    if ([self window] == nil)
        return;
    id cell = [self cell];
    if ([cell respondsToSelector:@selector(resetToolTipRectsInView:)]) {
        [self removeAllToolTips];
        [cell resetToolTipRectsInView:self];
    }
}

// the nib has a plain button cell; swap in a compass cell
- (id)initWithCoder:(id)aCoder
{
    self = [super initWithCoder:aCoder];
    if (self != nil) {
        NSCell *oldCell = [[self cell] retain];
        CompassCell *cell = [[CompassCell allocWithZone:[self zone]] init];
        [self setCell:cell];
        [cell setTarget:[oldCell target]];
        [cell setAction:[oldCell action]];
        [oldCell release];
        [cell release];
    }
    return self;
}

@end

@implementation CompassCell

- (id)accessibilityFocusedUIElement
{
    NSView *view = [self controlView];
    if (view != nil && view == [[view window] firstResponder])
        return self;
    return [super accessibilityFocusedUIElement];
}

- (id)accessibilityHitTest:(NSPoint)aTest
{
    NSView *view = [self controlView];
    NSPoint point = [[view window] convertPointFromScreen:aTest];
    point = [view convertPoint:point fromView:nil];
    NSInteger zone = [self __hitZoneForPoint:point];
    if (zone != 0)
        return [[[self accessibilityObjects] objectAtIndex:zone - 1] accessibilityHitTest:aTest];
    return NSAccessibilityUnignoredAncestor(self);
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    if ([aSettable isEqualToString:NSAccessibilityChildrenAttribute] || [aSettable isEqualToString:NSAccessibilityRoleAttribute])
        return NO;
    return [super accessibilityIsAttributeSettable:aSettable];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityChildrenAttribute])
        return [self accessibilityObjects];
    if ([aValue isEqualToString:NSAccessibilityRoleDescriptionAttribute])
        return [[NSBundle mainBundle] localizedStringForKey:@"Buttons" value:@"" table:nil];
    if ([aValue isEqualToString:NSAccessibilityTitleAttribute] || [aValue isEqualToString:NSAccessibilityHelpAttribute])
        return [[NSBundle mainBundle] localizedStringForKey:@"Compass" value:@"" table:nil];
    return [super accessibilityAttributeValue:aValue];
}

- (id)accessibilityAttributeNames
{
    return [[super accessibilityAttributeNames] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:NSAccessibilityChildrenAttribute, nil]];
}

// the keyboard and accessibility press the segments too
- (void)_pressZone:(int)aZone
{
    _prevHotZone = aZone;
    [[self target] performSelector:[self action] withObject:self];
    NSView *view = [self controlView];
    [view setKeyboardFocusRingNeedsDisplayInRect:[view bounds]];
}

- (void)performClick:(id)aClick
{
    [self _pressZone:0];
}

- (void)moveDown:(id)aDown
{
    [self _pressZone:5];
}

- (void)moveUp:(id)aUp
{
    [self _pressZone:4];
}

- (void)moveLeft:(id)aLeft
{
    [self _pressZone:2];
}

- (void)moveRight:(id)aRight
{
    [self _pressZone:3];
}

- (void)resetToolTipRectsInView:(id)aView
{
    static NSString *const tips[5] = {@"Stop spinning button", @"Spin Left button", @"Spin Right button", @"Spin Up button", @"Spin Down button"};
    NSBundle *bundle = [NSBundle mainBundle];
    for (int zone = 1; zone <= 5; zone++) {
        NSSize size = [[self _segmentImageForZone:zone] size];
        NSRect rect = {_kImageOrigins[zone - 1], size};
        float dx = zone == 3 ? 5.0f : 1.0f;
        float dy = 1.0f - (float)size.height + (zone == 5 ? 4.0f : 0.0f);
        rect = NSOffsetRect(rect, dx, dy);
        NSString *tip = [bundle localizedStringForKey:tips[zone - 1] value:@"" table:nil];
        // the arrows' rects are trimmed at their outer end
        if (zone == 1) {
            rect = NSInsetRect(rect, 2.0, 2.0);
        } else if (zone == 2 || zone == 3) {
            rect.size.width -= 4.0;
            rect = NSInsetRect(rect, 0.0, 6.0);
        } else {
            rect.size.height -= 4.0;
            rect = NSInsetRect(rect, 6.0, 0.0);
        }
        [aView addToolTipRect:rect owner:tip userData:NULL];
    }
}

- (void)setIntValue:(int)aValue
{
    _prevHotZone = aValue;
    [[self controlView] setNeedsDisplay:YES];
}

- (int)intValue
{
    return _prevHotZone;
}

// releasing on the stop button clears the value
- (void)stopTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView mouseIsUp:(BOOL)aUp
{
    if (aUp) {
        NSInteger zone = [self _hitZoneForPoint:aAt];
        _prevHotZone = zone == 1 ? 0 : (int)zone;
        [aView setNeedsDisplay:YES];
    }
}

- (BOOL)continueTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView
{
    NSInteger zone = [self _hitZoneForPoint:aAt];
    if (zone != _prevHotZone) {
        _prevHotZone = (int)zone;
        [aView setNeedsDisplay:YES];
        if (_isContinious)
            [[self target] performSelector:[self action] withObject:self];
    }
    return YES;
}

- (BOOL)startTrackingAt:(NSPoint)aAt inView:(id)aView
{
    NSInteger zone = [self _hitZoneForPoint:aAt];
    _prevHotZone = (int)zone;
    if (zone == 0)
        return NO;
    [aView setNeedsDisplay:YES];
    if (_isContinious)
        [[self target] performSelector:[self action] withObject:self];
    return YES;
}

// outside every segment, the last one stays
- (NSInteger)_hitZoneForPoint:(NSPoint)aPoint
{
    NSInteger zone = [self __hitZoneForPoint:aPoint];
    return zone != 0 ? zone : _prevHotZone;
}

// the compass is a circle of radius 27 around (28, 29): the stop button
// within 11.5 of the centre, the arrows in the quarters between the
// diagonals (with a 2 point gap along them)
- (NSInteger)__hitZoneForPoint:(NSPoint)aPoint
{
    float dx = (float)aPoint.x - 28.0f;
    float dy = (float)aPoint.y - 29.0f;
    float distance = sqrtf(dx * dx + dy * dy);
    if (distance > 27.0f)
        return 0;
    if (distance <= 11.5f)
        return 1;
    int ax = abs((int)dx);
    int ay = abs((int)dy);
    if (abs(ax - ay) < 2)
        return 0;
    if (dx < 0.0f && ay < ax)
        return 2;
    if (dx >= 0.0f && ay < ax)
        return 3;
    if (dy < 0.0f && ax < ay)
        return 4;
    if (dy >= 0.0f && ax < ay)
        return 5;
    return 0;
}

- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView
{
    _drawImageAt([self _compassImage], _kImageOrigins[5]);
    _drawImageAt([self _segmentImageForZone:_prevHotZone], [self _segmentOriginForZone:_prevHotZone]);
    if ([self showsFirstResponder]) {
        [NSGraphicsContext saveGraphicsState];
        NSSetFocusRingStyle(NSFocusRingOnly);
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(aFrame.origin.x, aFrame.origin.y, aFrame.size.width, aFrame.size.height - 2.0)] fill];
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (BOOL)isOpaque
{
    return NO;
}

- (void)dealloc
{
    [_accessibilityObjects release];
    [super dealloc];
}

- (id)accessibilityObjects
{
    if (_accessibilityObjects == nil) {
        NSMutableArray *objects = [NSMutableArray new];
        for (int zone = 1; zone != 6; zone++) {
            NSImage *image = [self _segmentImageForZone:zone];
            NSRect frame = {[self _segmentOriginForZone:zone], [image size]};
            [objects addObject:[[[CompassAccessibilityObject alloc] initWithCell:self frameRect:frame hotZone:zone] autorelease]];
        }
        _accessibilityObjects = objects;
    }
    return _accessibilityObjects;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        [self setBordered:NO];
        [self setBezeled:NO];
        _isContinious = YES;
    }
    return self;
}

// graphite or blue to match the system's control tint
- (id)_segmentImageForZone:(NSInteger)aZone
{
    BOOL graphite = [NSColor smkCurrentControlTint] == NSGraphiteControlTint;
    NSString *name;
    switch (aZone) {
    case 1: name = graphite ? @"sc_stop_grpht" : @"sc_stop_blue"; break;
    case 2: name = graphite ? @"sc_lft_grpht" : @"sc_lft_blue"; break;
    case 3: name = graphite ? @"sc_rght_grpht" : @"sc_rght_blue"; break;
    case 4: name = graphite ? @"sc_up_grpht" : @"sc_up_blue"; break;
    case 5: name = graphite ? @"sc_dwn_grpht" : @"sc_dwn_blue"; break;
    default: return nil;
    }
    return [NSImage imageNamed:name];
}

- (id)_compassImage
{
    return [NSImage imageNamed:@"sc_grey"];
}

- (NSPoint)_segmentOriginForZone:(NSInteger)aZone
{
    if (aZone >= 1 && aZone <= 5)
        return _kImageOrigins[aZone - 1];
    return NSZeroPoint;
}

@end

@implementation CompassAccessibilityObject

- (id)accessibilityFocusedUIElement
{
    return NSAccessibilityUnignoredAncestor(self);
}

- (void)accessibilityPerformAction:(id)aAction
{
    if ([aAction isEqualToString:NSAccessibilityPressAction]
        && [[_cell controlView] isKindOfClass:[NSControl class]]) {
        id control = [_cell controlView];
        if (control != nil)
            [self _performActionWithControl:control];
    }
}

- (id)accessibilityActionDescription:(id)aDescription
{
    if ([aDescription isEqualToString:NSAccessibilityPressAction])
        return [self _helpString];
    return nil;
}

- (id)accessibilityActionNames
{
    return [NSArray arrayWithObjects:NSAccessibilityPressAction, nil];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (id)accessibilityHitTest:(NSPoint)aTest
{
    return self;
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityRoleAttribute])
        return NSAccessibilityButtonRole;
    if ([aValue isEqualToString:NSAccessibilityRoleDescriptionAttribute])
        return [[NSBundle mainBundle] localizedStringForKey:@"Button" value:@"" table:nil];
    if ([aValue isEqualToString:NSAccessibilityParentAttribute])
        return _cell;
    if ([aValue isEqualToString:NSAccessibilityTitleAttribute] || [aValue isEqualToString:NSAccessibilityHelpAttribute])
        return [self _helpString];
    if ([aValue isEqualToString:NSAccessibilityPositionAttribute]) {
        NSView *view = [_cell controlView];
        NSPoint point = [view convertPoint:_frameRect.origin toView:nil];
        return [NSValue valueWithPoint:[[view window] convertPointToScreen:point]];
    }
    if ([aValue isEqualToString:NSAccessibilitySizeAttribute])
        return [NSValue valueWithSize:_frameRect.size];
    return nil;
}

- (id)accessibilityAttributeNames
{
    return [NSArray arrayWithObjects:NSAccessibilityRoleAttribute, NSAccessibilityHelpAttribute, NSAccessibilityTitleAttribute,
            NSAccessibilityPositionAttribute, NSAccessibilitySizeAttribute, NSAccessibilityParentAttribute,
            NSAccessibilityRoleDescriptionAttribute, nil];
}

- (void)_performActionWithControl:(id)aControl
{
    switch (_hotZone) {
    case 1: [aControl performClick:nil]; break;
    case 2: [aControl moveLeft:nil]; break;
    case 3: [aControl moveRight:nil]; break;
    case 4: [aControl moveUp:nil]; break;
    case 5: [aControl moveDown:nil]; break;
    }
}

- (id)_helpString
{
    NSString *key;
    switch (_hotZone) {
    case 1: key = @"Stop spinning button"; break;
    case 2: key = @"Spin Left button"; break;
    case 3: key = @"Spin Right button"; break;
    case 4: key = @"Spin Up button"; break;
    case 5: key = @"Spin Down button"; break;
    default: return nil;
    }
    return [[NSBundle mainBundle] localizedStringForKey:key value:@"" table:nil];
}

- (id)initWithCell:(id)aCell frameRect:(NSRect)aRect hotZone:(NSInteger)aZone
{
    self = [super init];
    if (self != nil) {
        _frameRect = aRect;
        _cell = aCell;
        _hotZone = (int)aZone;
    }
    return self;
}

@end
