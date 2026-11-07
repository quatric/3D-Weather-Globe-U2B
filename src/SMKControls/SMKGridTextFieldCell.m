// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Cells/SMKGridTextFieldCell.m
#import "SMKGridTextFieldCell.h"

static SMKStringRenderer *_sStringRenderer;

// a grid cell drawing its string, truncated to fit, in the grid's font
@implementation SMKGridTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView
{
	NSString *string = [self stringValue];
	[_sStringRenderer setFont:[[aView dataSource] textFont]];
	[_sStringRenderer setContainerWidth:aFrame.size.width];
	NSString *fitted = [_sStringRenderer stringByFittingString:string toSize:aFrame.size boundingRect:NULL];
	[_sStringRenderer drawString:fitted atPoint:aFrame.origin withColor:[self isHighlighted] ? [NSColor whiteColor] : nil];
}

- (id)init
{
	if (_sStringRenderer == nil) {
		_sStringRenderer = [SMKStringRenderer new];
		[_sStringRenderer setAlignment:NSTextAlignmentLeft];
	}
	return [super init];
}

@end
