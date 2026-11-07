// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/Utility/_SMKControlBackgroundRendererSmall.m
#import "_SMKControlBackgroundRendererSmall.h"

// the segment images of small controls
@implementation _SMKControlBackgroundRendererSmall

- (struct _SMKInset)defaultContentInset
{
	struct _SMKInset inset = [super defaultContentInset];
	inset.bottom = inset.top + inset.bottom;
	inset.top = 0.0f;
	return inset;
}

- (id)loadImageForTag:(NSInteger)aTag
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *name = [NSString stringWithFormat:@"segsmall%i", (int)aTag];
	return [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:name ofType:@"tiff"]];
}

@end
