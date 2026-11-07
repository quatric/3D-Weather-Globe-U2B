// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/WindowTransformer.m
#import "WindowTransformer.h"
#import "TransformerScene.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Animates replacing a window's content view: snapshots of the old and new
// content are drawn by a transformer scene in a transparent GL window laid
// over the real one.
static WindowTransformer *_sWindowTransformer;
static void (*_disableScreenUpdates)(void);
static void (*_enableScreenUpdates)(void);

@implementation WindowTransformer

+ (void)transformWindow:(id)aWindow newContentView:(id)aView effect:(NSInteger)aEffect
{
	[[self sharedInstance] _transformWindow:aWindow newContentView:aView effect:aEffect];
}

+ (id)sharedInstance
{
	if (_sWindowTransformer == nil) {
		_sWindowTransformer = [WindowTransformer new];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
			name:NSApplicationWillTerminateNotification object:nil];
	}
	return _sWindowTransformer;
}

+ (void)applicationWillTerminate:(id)aTerminate
{
	[_sWindowTransformer release];
	_sWindowTransformer = nil;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized) {
		CFBundleRef appKit = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.AppKit"));
		_disableScreenUpdates = CFBundleGetFunctionPointerForName(appKit, CFSTR("NSDisableScreenUpdates"));
		_enableScreenUpdates = CFBundleGetFunctionPointerForName(appKit, CFSTR("NSEnableScreenUpdates"));
		initialized = YES;
	}
}

- (void)dealloc
{
	[_cachedScenes release];
	[_textureCurrent release];
	[_textureNext release];
	[_transformView release];
	[_window release];
	[super dealloc];
}

// Runs the whole transition modally, spinning the run loop until it is done.
- (void)_transformWindow:(id)aWindow newContentView:(id)aView effect:(NSInteger)aEffect
{
	id oldView = [[[aWindow contentView] retain] autorelease];
	if (![aWindow isVisible] || oldView == nil || aView == nil) {
		return;
	}
	_contentRect = [aWindow frame];
	NSRect windowRect = [_TransformerScene windowRectForContentRect:_contentRect transformerType:aEffect];
	_contentRect.origin.x -= windowRect.origin.x;
	_contentRect.origin.y -= windowRect.origin.y;
	[[self _window] setLevel:[aWindow level]];
	[_window setCanBecomeKeyWindow:[aWindow canBecomeKeyWindow]];
	[_window setCanBecomeMainWindow:[aWindow canBecomeMainWindow]];
	[_window setFrame:windowRect display:NO animate:NO];
	_transformScene = [self _transformerSceneForEffect:aEffect];
	[_transformView setScene:_transformScene];
	[_transformView setDrawEnabled:YES];
	[_transformScene animateWithProgress:0.0];
	BOOL oneShot = [aWindow isOneShot];
	[aWindow setOneShot:NO];
	[self _setBitmap:[self _bitmapFromWindow:aWindow] forTexture:&_textureCurrent];
	[_transformView setNeedsDisplay:YES];
	[self _exchangeWindow:aWindow withWindow:_window];
	[aWindow setContentView:aView];
	[aWindow display];
	[self _setBitmap:[self _bitmapFromWindow:aWindow] forTexture:&_textureNext];
	[aWindow setOneShot:oneShot];
	NSTimer *timer = [NSTimer timerWithTimeInterval:0.02 target:self selector:@selector(_transformTimer:)
		userInfo:nil repeats:YES];
	_startTransform = [NSDate timeIntervalSinceReferenceDate];
	NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
	[runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
	[runLoop addTimer:timer forMode:NSEventTrackingRunLoopMode];
	NSDate *until = [NSDate dateWithTimeIntervalSinceNow:[_transformScene transformDuration]];
	while ([NSApp nextEventMatchingMask:0 untilDate:until inMode:NSEventTrackingRunLoopMode dequeue:YES] != nil) {
	}
	[timer invalidate];
	[_transformScene animateWithProgress:1.0];
	[_transformView display];
	[_transformView setDrawEnabled:NO];
	[self _exchangeWindow:_window withWindow:aWindow];
}

- (void)_exchangeWindow:(id)aWindow withWindow:(id)aWindow2
{
	[self _disableScreenUpdates];
	if ([aWindow isKeyWindow]) {
		[aWindow2 makeKeyAndOrderFront:self];
	}
	else {
		[aWindow2 orderFront:self];
	}
	[aWindow orderOut:self];
	[self _enableScreenUpdates];
}

- (void)_enableScreenUpdates
{
	if (_enableScreenUpdates != NULL) {
		_enableScreenUpdates();
	}
}

- (void)_disableScreenUpdates
{
	if (_disableScreenUpdates != NULL) {
		_disableScreenUpdates();
	}
}

// a snapshot of the whole window, frame included
- (id)_bitmapFromWindow:(id)aWindow
{
	[aWindow displayIfNeeded];
	NSView *frameView = [[aWindow contentView] superview];
	if (![frameView lockFocusIfCanDraw]) {
		return nil;
	}
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[frameView bounds]] autorelease];
	[frameView unlockFocus];
	return bitmap;
}

// Copies a bitmap into *aTexture, replacing the texture when it is too small.
- (void)_setBitmap:(id)aBitmap forTexture:(id *)aTexture
{
	NSBitmapImageRep *bitmap = aBitmap;
	SMK_GL_2DTexture *texture = *aTexture;
	float bitmapHeight = (float)[bitmap pixelsHigh];
	float bitmapWidth = (float)[bitmap pixelsWide];
	float height = (float)[texture height];
	float width = (float)[texture width];
	if (width < bitmapWidth || height < bitmapHeight) {
		[*aTexture release];
		*aTexture = nil;
	}
	[[[self glView] openGLContext] makeCurrentContext];
	if (aBitmap == nil) {
		return;
	}
	if (*aTexture == nil) {
		id container = [_transformView objectsContainer];
		[container beginAccumulationBlock];
		*aTexture = [[SMK_GL_2DTexture alloc] initWithContainer:container flags:0 usage:0
			width:(int)MAX(width, bitmapWidth) height:(int)MAX(height, bitmapHeight) dataFormat:GL_RGBA8];
		[container endAccumulationBlock];
	}
	[self _moveBitmap:aBitmap toTexture:*aTexture];
}

- (void)_transformTimer:(id)aTimer
{
	double now = [NSDate timeIntervalSinceReferenceDate];
	float progress = (float)((now - _startTransform) / [_transformScene transformDuration]);
	if (progress > 1.0f) {
		progress = 1.0f;
	}
	if ([_transformScene animateWithProgress:progress]) {
		[_transformView setNeedsDisplay:YES];
	}
}

// Copies the pixels (adding alpha to RGB bitmaps) and sets a texture matrix
// that maps 0..1 to the used part of the texture, flipped vertically.
- (void)_moveBitmap:(id)aBitmap toTexture:(id)aTexture
{
	NSBitmapImageRep *bitmap = aBitmap;
	SMK_GL_2DTexture *texture = aTexture;
	NSInteger height = [bitmap pixelsHigh];
	NSInteger width = [bitmap pixelsWide];
	BOOL hasAlpha = [bitmap hasAlpha];
	const unsigned char *src = [bitmap bitmapData];
	unsigned char *dest = [texture lock];
	size_t srcRow = (hasAlpha ? 4 : 3) * width;
	NSUInteger destRow = [texture bytesPerRow];
	for (NSInteger y = 0; y < height; y++) {
		if (hasAlpha) {
			memcpy(dest, src, srcRow);
		}
		else {
			const unsigned char *s = src;
			for (NSInteger x = 0; x < width; x++, s += 3) {
				unsigned char *d = dest + x * 4;
				d[0] = s[0];
				d[1] = s[1];
				d[2] = s[2];
				d[3] = 0xff;
			}
		}
		src += srcRow;
		dest += destRow;
	}
	[texture unlock];
	SMK_GL_Matrix m;
	matrix_make_identity(&m);
	m._11 = (float)width / (float)[texture width];
	m._22 = -((float)height / (float)[texture height]);
	m._24 = (float)height / (float)[texture height];
	[texture setTransformMatrix:&m];
}

- (id)_transformerSceneForEffect:(NSInteger)aEffect
{
	if (_cachedScenes == nil) {
		_cachedScenes = [NSMutableDictionary new];
	}
	NSString *key = [NSString stringWithFormat:@"%d", (int)aEffect];
	id scene = [_cachedScenes objectForKey:key];
	if (scene == nil) {
		scene = [_TransformerScene transformerSceneWithType:aEffect viewTransformer:self];
		[_cachedScenes setObject:scene forKey:key];
	}
	return scene;
}

- (id)_window
{
	if (_window == nil) {
		_window = [[_TransformWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 1.0, 1.0)
			styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:YES];
		[_window setBackgroundColor:[NSColor clearColor]];
		[_window setContentView:[self glView]];
	}
	return _window;
}

- (id)glView
{
	if (_transformView == nil) {
		[self _createGLTransformerView];
	}
	return _transformView;
}

- (void)_createGLTransformerView
{
	NSOpenGLPixelFormatAttribute attributes[] = {
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 0,
		0
	};
	NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	if (format == nil) {
		NSLog(@"No OpenGL pixel format");
	}
	_transformView = [[_Transform_GL_View alloc] initWithFrame:NSMakeRect(0.0, 0.0, 1.0, 1.0) pixelFormat:format];
	GLint opacity = 0;
	[[_transformView openGLContext] setValues:&opacity forParameter:NSOpenGLContextParameterSurfaceOpacity];
	[_transformView setMaxFPSLimit:30.0];
	[_transformView createSMKGLContextForNSOpenGLContext:[_transformView openGLContext]];
	[_transformView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

@end

// the borderless window the transition is drawn in
@implementation _TransformWindow

- (BOOL)canBecomeMainWindow
{
	return _canBeMain;
}

- (BOOL)canBecomeKeyWindow
{
	return _canBeKey;
}

- (void)setCanBecomeMainWindow:(BOOL)aWindow
{
	_canBeMain = aWindow;
}

- (void)setCanBecomeKeyWindow:(BOOL)aWindow
{
	_canBeKey = aWindow;
}

@end

@implementation _Transform_GL_View

- (void)createSMKGLContextForNSOpenGLContext:(id)aContext
{
	[super createSMKGLContextForNSOpenGLContext:aContext];
	[[self context] setClearColor:(SMK_GL_Color){ 0.0f, 0.0f, 0.0f, 0.0f }];
}

- (BOOL)isOpaque
{
	return NO;
}

- (BOOL)isDoubleBuffered
{
	return NO;
}

- (void)drawRect:(NSRect)aRect
{
	if (_drawEnabled) {
		[super drawRect:aRect];
	}
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];
	[[self window] setOpaque:NO];
	[[self window] setAlphaValue:1.0];
	_traceFPS = YES;
}

- (void)animate:(double)aAnimate
{
	[self setNeedsDisplay:YES];
}

- (BOOL)mouseDownCanMoveWindow
{
	return NO;
}

- (void)setDrawEnabled:(BOOL)aEnabled
{
	_drawEnabled = aEnabled;
}

@end
