// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridClipView.m
#import "SMKControlsPrefix.h"


@interface SMKGridClipView : NSClipView
{
}
+ (id)contentViewWithFrame:(NSRect)aFrame;
- (void)drawRect:(NSRect)aRect;
- (NSPoint)constrainScrollPoint:(NSPoint)aPoint;
- (BOOL)copiesOnScroll;
@end

