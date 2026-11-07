// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_View.m
#import "SMK_GL_View.h"

// An NSOpenGLView that draws an SMK_GL_Scene and passes it the events.
@implementation SMK_GL_View

- (void)drawRect:(NSRect)aRect
{
	if (_context == nil) {
		[self createSMKGLContextForNSOpenGLContext:[self openGLContext]];
	}
	_framesCount++;
	SMK_GL_Color c = [_context clearColor];
	glClearColor(c.r, c.g, c.b, c.a);
	[self clearBuffer];
	[_scene drawSceneInContext:_context withFrameSize:[self bounds].size];
	[self flushBuffer];
}

- (BOOL)isDoubleBuffered
{
	return NO;
}

- (void)flushBuffer
{
	[_context _resetAllBondBuffers];
	if ([self isDoubleBuffered]) {
		[[self openGLContext] flushBuffer];
	}
	else {
		glFlush();
	}
}

- (void)clearBuffer
{
	[_context setMaterial:nil];
	[_context resetAllTextures];
	[_context resetAllLights];
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	if ([self window] == nil) {
		[self stopAutoRefresh];
	}
	if (_cocoaDrawingIsEnabled) {
		// the GL surface goes behind the window, which must let it show through
		[[self window] setOpaque:NO];
		[[self window] setAlphaValue:0.999f];
	}
	else {
		[[self window] setOpaque:YES];
	}
}

- (void)setMaxFPSLimit:(CGFloat)aLimit
{
	_maxFPSLimit = aLimit;
	if (_autoTimer != nil) {
		[self stopAutoRefresh];
		[self startAutoRefresh];
	}
}

- (void)decreaseAutoUpdateCounter
{
	if (--_autoUpdateCounter == 0) {
		[self stopAutoRefresh];
	}
}

- (void)increaseAutoUpdateCounter
{
	if (_autoUpdateCounter++ == 0) {
		[self startAutoRefresh];
	}
}

- (void)setTracesFPS:(BOOL)aFPS
{
	_traceFPS = aFPS;
}

- (void)stopAutoRefresh
{
	[_autoTimer invalidate];
	[_autoTimer release];
	_autoTimer = nil;
}

- (void)startAutoRefresh
{
	[self stopAutoRefresh];
	NSTimeInterval interval = _maxFPSLimit > 0.0f ? 1.0 / _maxFPSLimit : 0.001;
	_autoTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self
		selector:@selector(onAutoRefreshTimer:) userInfo:nil repeats:YES] retain];
}

- (void)onAutoRefreshTimer:(id)aTimer
{
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval elapsed = now - _prevTime;
	if (elapsed > 1.0) {
		if (_traceFPS) {
			NSLog(@"(%@) reached fps:%f;", self, (double)((float)_framesCount / (float)elapsed));
		}
		_prevTime = now;
		_framesCount = 0;
	}
	[self animate:now];
}

- (void)animate:(double)aAnimate
{
	[[self scene] animate:aAnimate];
}

- (void)setUsesVerticalSync:(BOOL)aSync
{
	_useVerticalSync = aSync;
}

- (void)keyUp:(id)aUp
{
	[_scene keyUp:aUp inView:self];
}

- (void)keyDown:(id)aDown
{
	[_scene keyDown:aDown inView:self];
}

- (void)mouseExited:(id)aExited
{
	[_scene mouseExited:aExited inView:self];
}

- (void)mouseEntered:(id)aEntered
{
	[_scene mouseEntered:aEntered inView:self];
}

- (BOOL)acceptsFirstResponder
{
	return [_scene acceptsFirstResponderInView:self];
}

- (void)mouseMoved:(id)aMoved
{
	[_scene mouseMoved:aMoved inView:self];
}

- (void)mouseUp:(id)aUp
{
	[_scene mouseUp:aUp inView:self];
}

- (void)mouseDragged:(id)aDragged
{
	[_scene mouseDragged:aDragged inView:self];
}

- (void)mouseDown:(id)aDown
{
	[_scene mouseDown:aDown inView:self];
}

// Cocoa drawing puts the GL surface below the window and a transparent
// subview on top, where the scene's controls draw with AppKit.
- (void)setCocoaDrawingEnabled:(BOOL)aEnabled
{
	if (_cocoaDrawingIsEnabled == aEnabled) {
		return;
	}
	GLint order = aEnabled ? -1 : 0;
	[[self openGLContext] setValues:&order forParameter:NSOpenGLContextParameterSurfaceOrder];
	_cocoaDrawingIsEnabled = aEnabled;
	[_cocoaLayerSubview removeFromSuperview];
	_cocoaLayerSubview = nil;
	if (_cocoaDrawingIsEnabled) {
		NSRect frame = [self frame];
		frame.origin = NSZeroPoint;
		_cocoaLayerSubview = [[[_CocoaLayerView alloc] initWithFrame:frame] autorelease];
		[_cocoaLayerSubview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self addSubview:_cocoaLayerSubview];
	}
}

- (id)camera
{
	return [_scene camera];
}

- (void)setScene:(id)aScene
{
	if (_scene != aScene) {
		[[self openGLContext] makeCurrentContext];
		[_scene release];
		_scene = [aScene retain];
	}
}

- (id)scene
{
	return _scene;
}

- (id)context
{
	return _context;
}

- (id)objectsContainer
{
	return _container;
}

- (void)setOpenGLContext:(id)aContext
{
	if (_contextWasReinstalledForLeakFix && aContext != [self openGLContext]) {
		[self createSMKGLContextForNSOpenGLContext:aContext];
	}
	[super setOpenGLContext:aContext];
}

- (void)createSMKGLContextForNSOpenGLContext:(id)aContext
{
	if (_context != nil) {
		[_container contextWillBeDetached];
		[_context release];
		_context = nil;
	}
	if (aContext == nil) {
		return;
	}
	_context = [[SMK_GL_Context alloc] initWithContainer:_container systemContext:aContext view:self];
	[self setViewport:[self bounds]];
	[_container contextWasAttached:_context];
	if ([aContext respondsToSelector:@selector(CGLContextObj)]) {
		GLint swapInterval = _useVerticalSync ? 1 : 0;
		if (CGLSetParameter([aContext CGLContextObj], kCGLCPSwapInterval, &swapInterval) != kCGLNoError) {
			NSLog(@"Unable to set vertical sync option.");
		}
	}
}

- (void)reshape
{
	[super reshape];
	[self setViewport:[self bounds]];
}

- (void)update
{
	[super update];
	[self setViewport:[self bounds]];
}

- (void)setViewport:(NSRect)aViewport
{
	[_context makeCurrent];
	glViewport((GLint)aViewport.origin.x, (GLint)aViewport.origin.y, (GLsizei)aViewport.size.width,
		(GLsizei)aViewport.size.height);
}

- (void)dealloc
{
	[[self openGLContext] makeCurrentContext];
	[self createSMKGLContextForNSOpenGLContext:nil];
	[_scene release];
	[_container release];
	[_autoTimer invalidate];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame pixelFormat:(id)aFormat
{
	self = [super initWithFrame:aFrame pixelFormat:aFormat];
	if (self != nil) {
		_container = [SMK_GL_ObjectsContainer new];
		_useVerticalSync = YES;
	}
	return self;
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self != nil) {
		_container = [SMK_GL_ObjectsContainer new];
		_useVerticalSync = YES;
	}
	return self;
}

@end

// the transparent layer over a GL view where its scene's controls draw
@implementation _CocoaLayerView

- (void)drawRect:(NSRect)aRect
{
	id superview = [self superview];
	if ([superview isKindOfClass:[SMK_GL_View class]]) {
		id scene = [superview scene];
		[[NSColor clearColor] set];
		NSRectFill(aRect);
		[scene drawInFocusedView:self inRect:aRect];
	}
}

@end
