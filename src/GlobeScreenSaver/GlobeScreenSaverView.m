#import "GlobeScreenSaverView.h"

// The ScreenSaverView. The GL view is made on the first frame, with the size
// the saver was created with, and anchored to the top of the bounds.
@implementation GlobeScreenSaverView

/* i386 ivar offsets: _configDictionary=0x6c, _configureSheetController=0x70, _glView=0x74, _newSize=0x78, _textureLoadingDone=0x80 */

- (id)configDictionary
{
	if (_configDictionary == nil) {
		_configDictionary = [[GlobeScreenSaverDefaults configDictionary] retain];
	}
	return _configDictionary;
}

- (id)configureSheet
{
	if (_configureSheetController == nil) {
		_configureSheetController = [[GlobeConfigureSheetController alloc] init];
	}
	return [_configureSheetController window];
}

- (BOOL)hasConfigureSheet
{
	return YES;
}

- (void)animateOneFrame
{
	if (_glView != nil) {
		[_glView prepareToAnimateNextFrameForFPS:[[self configDictionary] animationFPS]];
		[_glView display];
		return;
	}
	NSRect bounds = [self bounds];
	NSRect frame = NSMakeRect(0.0, NSMaxY(bounds) - _newSize.height, _newSize.width, _newSize.height);
	GlobeGLView *view = [[GlobeGLView alloc] initWithFrame:frame isPreview:[self isPreview]];
	_glView = view;
	[view setScene:[[GlobeGLScene alloc] initWithContainer:[_glView objectsContainer]]];
	[[_glView scene] release];
	[self addSubview:_glView];
	[_glView setNeedsDisplay:NO];
	// the superview keeps it
	[_glView release];
}

- (void)drawRect:(NSRect)aRect
{
	[self _fillBackGround];
}

- (void)stopAnimation
{
	[super stopAnimation];
}

- (void)startAnimation
{
	[super startAnimation];
}

- (void)dealloc
{
	[_glView removeFromSuperviewWithoutNeedingDisplay];
	_glView = nil;
	[_configDictionary release];
	_configDictionary = nil;
	[_configureSheetController release];
	_configureSheetController = nil;
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame isPreview:(BOOL)aPreview
{
	self = [super initWithFrame:aFrame isPreview:aPreview];
	if (self != nil) {
		_newSize = aFrame.size;
		_glView = nil;
		_textureLoadingDone = 0;
		[self setAnimationTimeInterval:1.0 / (float)[[self configDictionary] animationFPS]];
	}
	return self;
}

@end

@implementation GlobeScreenSaverView (Private)

- (void)_fillBackGround
{
	[[NSColor blackColor] set];
	NSRect bounds = [self bounds];
	[NSBezierPath fillRect:NSMakeRect(0.0, NSMaxY(bounds) - _newSize.height, _newSize.width, _newSize.height)];
}

@end
