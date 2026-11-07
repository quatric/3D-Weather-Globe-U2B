// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKAngleSliderCell.m
#import "SMKControlsPrefix.h"


@interface SMKAngleSliderCell : NSActionCell
{
    NSImage *_backgroundImage;
    NSImage *_indicatorImage;
    float _angleValue;
    float _radiusMultiplier;
    BOOL _isRadiusDrawn;
    BOOL _isHighlighted;
    NSRect _cellFrame;
}
+ (void)setupImages;
+ (void)controlTintDidChangeNotification:(id)aNotification;
+ (BOOL)prefersTrackingUntilMouseUp;
+ (void)initialize;
- (NSPoint)pointFromAngleValue:(CGFloat)aValue;
- (CGFloat)angleValueAtPoint:(NSPoint)aPoint increment:(NSInteger)aIncrement;
- (NSPoint)calcIndicatorPoint:(NSPoint)aPoint mouseFlags:(NSInteger)aFlags;
- (NSUInteger)mouseFlags;
- (CGFloat)radius;
- (id)_indicatorImage;
- (id)_backgroundImage;
- (void)moveInDirection:(NSInteger)aDirection withFlags:(NSInteger)aFlags;
- (void)setFloatValue:(float)aValue;
- (float)floatValue;
- (void)setAngleValue:(CGFloat)aValue;
- (CGFloat)angleValue;
- (void)setRadiusMultiplierToSmallestBackgroundSize:(CGFloat)aSize;
- (CGFloat)radiusMultiplierToSmallestBackgroundSize;
- (void)setRadiusDrawingEnabled:(BOOL)aEnabled;
- (BOOL)isRadiusDrawingEnabled;
- (void)setIndicatorImage:(id)aImage;
- (void)setBackgroundImage:(id)aImage;
- (id)indicatorImage;
- (id)backgroundImage;
- (NSSize)contentSize;
- (BOOL)continueTracking:(NSPoint)aTracking at:(NSPoint)aAt inView:(id)aView;
- (BOOL)startTrackingAt:(NSPoint)aAt inView:(id)aView;
- (BOOL)trackMouse:(id)aMouse inRect:(NSRect)aRect ofView:(id)aView untilMouseUp:(BOOL)aUp;
- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView;
- (void)update;
- (void)controlTintDidChangeNotification:(id)aNotification;
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (void)dealloc;
- (id)init;
@end

