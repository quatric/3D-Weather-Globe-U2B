#import "WeatherGlobePrefix.h"


@interface CompassButton : NSButton
{
}
+ (Class)cellClass;
+ (void)initialize;
- (void)performClick:(id)aClick;
- (void)moveDown:(id)aDown;
- (void)moveUp:(id)aUp;
- (void)moveLeft:(id)aLeft;
- (void)moveRight:(id)aRight;
- (void)viewDidMoveToWindow;
- (void)viewWillMoveToWindow:(id)aWindow;
- (void)resetToolTipRects;
- (id)initWithCoder:(id)aCoder;
@end

@interface CompassCell : NSButtonCell
{
    BOOL _isContinious;
    int _prevHotZone;
    NSArray *_accessibilityObjects;
}
- (id)accessibilityFocusedUIElement;
- (id)accessibilityHitTest:(NSPoint)aTest;
- (BOOL)accessibilityIsAttributeSettable:(id)aSettable;
- (BOOL)accessibilityIsIgnored;
- (id)accessibilityAttributeValue:(id)aValue;
- (id)accessibilityAttributeNames;
- (void)performClick:(id)aClick;
- (void)moveDown:(id)aDown;
- (void)moveUp:(id)aUp;
- (void)moveLeft:(id)aLeft;
- (void)moveRight:(id)aRight;
- (void)resetToolTipRectsInView:(id)aView;
- (void)setIntValue:(int)aValue;
- (int)intValue;
- (void)stopTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView mouseIsUp:(BOOL)aUp;
- (BOOL)continueTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView;
- (BOOL)startTrackingAt:(NSPoint)aAt inView:(id)aView;
- (NSInteger)_hitZoneForPoint:(NSPoint)aPoint;
- (NSInteger)__hitZoneForPoint:(NSPoint)aPoint;
- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView;
- (BOOL)isOpaque;
- (void)dealloc;
- (id)accessibilityObjects;
- (id)init;
- (id)_segmentImageForZone:(NSInteger)aZone;
- (id)_compassImage;
- (NSPoint)_segmentOriginForZone:(NSInteger)aZone;
@end

@interface CompassAccessibilityObject : NSObject
{
    int _hotZone;
    NSRect _frameRect;
    CompassCell *_cell;
}
- (id)accessibilityFocusedUIElement;
- (void)accessibilityPerformAction:(id)aAction;
- (id)accessibilityActionDescription:(id)aDescription;
- (id)accessibilityActionNames;
- (BOOL)accessibilityIsIgnored;
- (id)accessibilityHitTest:(NSPoint)aTest;
- (BOOL)accessibilityIsAttributeSettable:(id)aSettable;
- (id)accessibilityAttributeValue:(id)aValue;
- (id)accessibilityAttributeNames;
- (void)_performActionWithControl:(id)aControl;
- (id)_helpString;
- (id)initWithCell:(id)aCell frameRect:(NSRect)aRect hotZone:(NSInteger)aZone;
@end

