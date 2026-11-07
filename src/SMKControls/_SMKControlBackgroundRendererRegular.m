// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/Utility/_SMKControlBackgroundRendererRegular.m
#import "_SMKControlBackgroundRendererRegular.h"

// the segment images of regular controls
@implementation _SMKControlBackgroundRendererRegular

- (struct _SMKInset)defaultContentInset
{
	struct _SMKInset inset = [super defaultContentInset];
	inset.top -= 1.0f;
	inset.bottom += 1.0f;
	return inset;
}

- (id)loadImageForTag:(NSInteger)aTag
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *name = [NSString stringWithFormat:@"seg%i", (int)aTag];
	return [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:name ofType:@"tiff"]];
}

@end
