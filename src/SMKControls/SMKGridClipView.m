// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridClipView.m
#import "SMKGridClipView.h"

// The grid control's clip view: shows the placeholder string while the grid
// is empty and scrolls a matrix by whole cells.
@implementation SMKGridClipView

+ (id)contentViewWithFrame:(NSRect)aFrame
{
	return [[[self alloc] initWithFrame:aFrame] autorelease];
}

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	id grid = [[self superview] superview];
	if ([grid dataSource] != nil && [[grid dataSource] numberOfItemsInGridControl:grid] != 0) {
		return;
	}
	[grid drawPlaceholderStringInRect:[self bounds]];
}

- (NSPoint)constrainScrollPoint:(NSPoint)aPoint
{
	NSPoint p = [super constrainScrollPoint:aPoint];
	if ([[self documentView] isKindOfClass:[NSMatrix class]]) {
		NSMatrix *matrix = [self documentView];
		NSSize cell = [matrix cellSize];
		p.x = (float)cell.width * ceilf((float)p.x / (float)cell.width);
		p.y = (float)cell.height * ceilf((float)p.y / (float)cell.height);
	}
	return p;
}

- (BOOL)copiesOnScroll
{
	return NO;
}

@end
