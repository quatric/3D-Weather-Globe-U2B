// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/Utility/_SMKControlBackgroundRendererMini.m
#import "_SMKControlBackgroundRendererMini.h"

// the segment images of mini controls
@implementation _SMKControlBackgroundRendererMini

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
	NSString *name = [NSString stringWithFormat:@"segmini%i", (int)aTag];
	return [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:name ofType:@"tiff"]];
}

@end
