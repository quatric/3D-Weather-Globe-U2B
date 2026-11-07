#import "GlobeGLView.h"

@implementation GlobeGLView

- (void)createSMKGLContextForNSOpenGLContext:(id)aContext
{
	[super createSMKGLContextForNSOpenGLContext:aContext];
	[(SMK_GL_Context *)[self context] setClearColor:(SMK_GL_Color){ 0.0f, 0.0f, 0.0f, 0.0f }];
}

- (BOOL)isDoubleBuffered
{
	return NO;
}

- (void)prepareToAnimateNextFrameForFPS:(CGFloat)aFPS
{
	[(GlobeGLScene *)[self scene] prepareToAnimateNextFrameForFPS:aFPS];
}

- (void)dealloc
{
	[(GlobeGLScene *)[self scene] waitForStopLoadingThread];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame isPreview:(BOOL)aPreview
{
	NSOpenGLPixelFormatAttribute attributes[] = {
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAWindow,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 15,
		NSOpenGLPFAAlphaSize, 1,
		NSOpenGLPFADepthSize, 0,
		NSOpenGLPFAAccumSize, 0,
		0
	};
	NSOpenGLPixelFormat *format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
	if (format == nil) {
		NSLog(@"No OpenGL pixel format");
	}
	return [super initWithFrame:aFrame pixelFormat:[format autorelease]];
}

@end
