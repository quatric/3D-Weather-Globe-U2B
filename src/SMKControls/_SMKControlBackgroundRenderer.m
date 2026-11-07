// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/Utility/_SMKControlBackgroundRenderer.m
#import "_SMKControlBackgroundRenderer.h"

// one shared renderer per control size: regular, small, mini
static _SMKControlBackgroundRenderer *_sCachedInstances[3];
static BOOL _sCachedTintValid;
static BOOL _sInit;
static BOOL _sShouldGetTintFromPrefs;
static NSInteger _sCachedTint;

// Draws a segmented background from images: a left cap, a right cap, and a
// fill between them that starts with a divider piece unless the segment has
// a left cap. Image tags are the piece (0 fill, 1 left cap, 2 right cap,
// 3 divider) or'ed with the state: 4 selected, 8 graphite, 16 disabled.
@implementation _SMKControlBackgroundRenderer

+ (void)controlTintDidChange:(id)aChange
{
	_sCachedTintValid = NO;
}

+ (NSInteger)currentControlTint
{
	if (!_sInit) {
		if (![NSColor respondsToSelector:@selector(currentControlTint)]) {
			_sShouldGetTintFromPrefs = YES;
			_sCachedTintValid = NO;
			_sCachedTint = [self _getCurrentControlTint];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlTintDidChange:)
				name:NSControlTintDidChangeNotification object:nil];
		}
		_sInit = YES;
	}
	if (!_sShouldGetTintFromPrefs) {
		return [NSColor currentControlTint];
	}
	if (!_sCachedTintValid) {
		_sCachedTint = [self _getCurrentControlTint];
		_sCachedTintValid = YES;
	}
	return _sCachedTint;
}

+ (NSInteger)_getCurrentControlTint
{
	NSString *variant = [NSString stringWithFormat:@"%@", [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleAquaColorVariant"]];
	return variant != nil ? [variant intValue] : 1;
}

+ (id)newBackgroundRendererForControlSize:(NSInteger)aSize
{
	if ((NSUInteger)aSize > 2) {
		aSize = 0;
	}
	id renderer = [_sCachedInstances[aSize] retain];
	if (renderer == nil) {
		Class class = [_SMKControlBackgroundRendererRegular class];
		if (aSize == 1) {
			class = [_SMKControlBackgroundRendererSmall class];
		}
		else if (aSize == 2) {
			class = [_SMKControlBackgroundRendererMini class];
		}
		renderer = [class new];
		_sCachedInstances[aSize] = renderer;
	}
	return renderer;
}

- (void)drawBackgroundImageForObject:(id)aObject bounds:(NSRect)aBounds style:(NSUInteger)aStyle
{
	NSUInteger state = 0;
	if ([aObject isSelected]) {
		state = [_SMKControlBackgroundRenderer currentControlTint] == NSGraphiteControlTint ? 12 : 4;
	}
	if (![aObject isEnabled]) {
		state |= 16;
	}
	if ([aObject isLeftCap]) {
		[self _drawLeftCap:state client:aObject withBounds:&aBounds];
	}
	if ([aObject isRightCap]) {
		[self _drawRightCap:state client:aObject withBounds:&aBounds];
	}
	[self _drawFill:state client:aObject withBounds:aBounds];
}

// the caps' widths where there are caps
- (struct _SMKInset)contentInsetForObject:(id)aObject
{
	struct _SMKInset inset = [self defaultContentInset];
	if ([aObject isLeftCap]) {
		inset.left = (float)[self leftCapWidthForObject:aObject];
	}
	if ([aObject isRightCap]) {
		inset.right = (float)[self rightCapWidthForObject:aObject];
	}
	return inset;
}

- (struct _SMKInset)defaultContentInset
{
	struct _SMKInset inset = { 6.0f, 2.0f, 4.0f, 2.0f };
	return inset;
}

- (CGFloat)segmentHeightForObject:(id)aObject
{
	if (!_sizesValid) {
		[self _initSizes];
	}
	return _segmentHeight;
}

- (void)_drawFill:(NSUInteger)aFill client:(id)aClient withBounds:(NSRect)aBounds
{
	NSImage *divider = [aClient isLeftCap] ? nil : [self _imageForTag:aFill | 3];
	NSRect r = aBounds;
	if (divider != nil) {
		NSSize size = [divider size];
		NSRect to = aBounds;
		to.size.width = MIN(aBounds.size.width, size.width);
		NSRect from = NSMakeRect(0.0, 0.0, to.size.width, size.height);
		[divider drawInRect:to fromRect:from operation:NSCompositingOperationSourceOver fraction:1.0];
		r.origin.x = NSMaxX(to);
		r.size.width = NSMaxX(aBounds) - r.origin.x;
	}
	if (r.size.width <= 0.0) {
		return;
	}
	NSImage *fill = [self _imageForTag:aFill];
	if (fill != nil) {
		NSRect from = NSZeroRect;
		from.size = [fill size];
		[fill drawInRect:r fromRect:from operation:NSCompositingOperationSourceOver fraction:1.0];
	}
}

- (void)_drawRightCap:(NSUInteger)aCap client:(id)aClient withBounds:(NSRect *)aBounds
{
	NSImage *image = [self _imageForTag:aCap | 2];
	float width = (float)[self rightCapWidthForObject:aClient];
	if (image != nil) {
		NSRect from = NSZeroRect;
		from.size = [image size];
		NSRect to = NSMakeRect(NSMaxX(*aBounds) - width, aBounds->origin.y, width, aBounds->size.height);
		[image drawInRect:to fromRect:from operation:NSCompositingOperationSourceOver fraction:1.0];
	}
	aBounds->size.width -= width;
}

- (void)_drawLeftCap:(NSUInteger)aCap client:(id)aClient withBounds:(NSRect *)aBounds
{
	NSImage *image = [self _imageForTag:aCap | 1];
	float width = (float)[self leftCapWidthForObject:aClient];
	if (image != nil) {
		NSRect from = NSZeroRect;
		from.size = [image size];
		NSRect to = NSMakeRect(aBounds->origin.x, aBounds->origin.y, width, aBounds->size.height);
		[image drawInRect:to fromRect:from operation:NSCompositingOperationSourceOver fraction:1.0];
	}
	aBounds->origin.x += width;
	aBounds->size.width -= width;
}

- (CGFloat)rightCapWidthForObject:(id)aObject
{
	if (!_sizesValid) {
		[self _initSizes];
	}
	return _rightCapWidth;
}

- (CGFloat)leftCapWidthForObject:(id)aObject
{
	if (!_sizesValid) {
		[self _initSizes];
	}
	return _leftCapWidth;
}

// the caps' widths and the fill's height, from the normal state images
- (void)_initSizes
{
	if (_sizesValid) {
		return;
	}
	NSImage *image = [self _imageForTag:1];
	_leftCapWidth = image != nil ? (float)[image size].width : 0.0f;
	image = [self _imageForTag:2];
	_rightCapWidth = image != nil ? (float)[image size].width : 0.0f;
	image = [self _imageForTag:0];
	_segmentHeight = image != nil ? (float)[image size].height : 0.0f;
	_sizesValid = YES;
}

// each image is loaded once, missing or not
- (id)_imageForTag:(NSInteger)aTag
{
	if ((NSUInteger)aTag >= 20) {
		return nil;
	}
	unsigned int bit = 1u << aTag;
	if ((_imageInitAttempts & bit) == 0) {
		_images[aTag] = [self loadImageForTag:aTag];
		_imageInitAttempts |= bit;
	}
	return _images[aTag];
}

- (id)loadImageForTag:(NSInteger)aTag
{
	NSLog(@"-%@ should be implemented in concrete subclass", NSStringFromSelector(_cmd));
	return nil;
}

- (void)dealloc
{
	for (int i = 0; i < 3; i++) {
		if (_sCachedInstances[i] == self) {
			_sCachedInstances[i] = nil;
		}
	}
	for (int i = 0; i < 20; i++) {
		[_images[i] release];
	}
	[super dealloc];
}

@end
