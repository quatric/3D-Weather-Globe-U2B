// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridDrawView.m
#import "SMKControlsPrefix.h"


@interface SMKGridDrawView : NSView
{
}
+ (void)initialize;
- (void)mouseDown:(id)aDown;
- (void)mouseDragged:(id)aDragged;
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal;
- (void)drawRect:(NSRect)aRect;
- (void)resizeWithOldSuperviewSize:(NSSize)aSize;
- (NSRect)graphicsContentRectInBounds:(NSRect)aBounds cell:(id)aCell;
- (id)dataCells;
- (id)enclosingGridControl;
- (BOOL)isFlipped;
- (BOOL)acceptsFirstMouse:(id)aMouse;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame;
@end

