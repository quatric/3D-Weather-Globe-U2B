// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKSplitView.m
#import "SMKControlsPrefix.h"


// optional split view delegate methods for double clicks
@interface NSObject (SMKSplitViewDelegate)
- (void)splitView:(NSSplitView *)aSplitView didDoubleClickInDividerAtIndex:(NSInteger)aIndex;
- (void)splitView:(NSSplitView *)aSplitView didDoubleClickInSplitter:(id)aSplitter;
@end

@interface SMKSplitView : NSSplitView <NSCoding>
{
    float _smkcDividerThickness;
    NSImage *_smkcDividerImage;
}
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (void)mouseDown:(id)aDown;
- (void)drawDividerInRect:(NSRect)aRect;
- (void)setDividerImage:(id)aImage;
- (id)dividerImage;
- (void)setDividerThickness:(CGFloat)aThickness;
- (CGFloat)dividerThickness;
- (void)dealloc;
@end

@interface NSSplitView (SMKSplitterEnclosingSplitView)
- (void)trackSMKSplitterView:(id)aView withEvent:(id)aEvent;
- (BOOL)smkcHandleDoubleClickInSplitterView:(id)aView withEvent:(id)aEvent;
- (NSInteger)smkcHitTestDividerIndexAtPoint:(NSPoint)aPoint isExactlyInDivider:(BOOL *)aDivider;
@end

