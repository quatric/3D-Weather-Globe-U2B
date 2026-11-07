// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Control.m
#import "SMK_GL_Control.h"

// A button drawn in 2D mode. States: 0 normal, 1 mouse over, 2 pressed,
// 3 disabled.
@implementation SMK_GL_Control

- (void)drawInContext:(id)aContext
{
	NSRect r = _rect;
	if (_keepProportions) {
		// keep the rect square on screen, centered in the original one
		NSSize size = [aContext size];
		float aspect = (float)size.width / (float)size.height;
		if (aspect <= 1.0f) {
			r.origin.y = (float)r.origin.y + (float)r.size.height * 0.5f + (float)r.size.height * -0.5f * aspect;
			r.size.height = (float)r.size.height * aspect;
		}
		else {
			r.origin.x = (float)r.origin.x + (float)r.size.width * 0.5f + ((float)r.size.width * -0.5f) / aspect;
			r.size.width = (float)r.size.width / aspect;
		}
	}
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	id texture = nil;
	switch (_currentState) {
	case 1:
		if (_overTexture != nil) {
			[aContext setColor:&white];
			texture = _overTexture;
			break;
		}
		// fall through
	case 0:
		if (_normalTexture != nil) {
			[aContext setColor:&white];
			texture = _normalTexture;
		}
		break;
	case 2:
		if (_normalTexture != nil || _overTexture != nil) {
			SMK_GL_Color pressed = { 0.5f, 0.5f, 0.5f, 1.0f };
			[aContext setColor:&pressed];
			texture = _overTexture != nil ? _overTexture : _normalTexture;
		}
		break;
	case 3:
		if (_normalTexture != nil) {
			SMK_GL_Color disabled = { 0.5f, 0.5f, 0.5f, 0.5f };
			[aContext setColor:&disabled];
			texture = _normalTexture;
		}
		break;
	}
	if (texture != nil) {
		[aContext drawTexture:texture inRect:r];
	}
	[aContext setColor:&white];
	if ([_title length] != 0) {
		[aContext setFont:_font];
		SMK_GL_Color shadow = { 0.0f, 0.0f, 0.0f, 1.0f };
		NSRect titleRect = NSMakeRect((float)(r.origin.x + r.size.width * 0.5) - 1.0f,
			((float)r.origin.y + 0.015f) - 1.0f, 2.0f, 1.0f);
		[aContext drawString:_title inRect:titleRect hAlignment:2 vAlignment:0 backColor:&shadow];
	}
}

- (NSRect)rect
{
	return _rect;
}

- (void)setRect:(NSRect)aRect
{
	_rect = aRect;
}

- (void)setKeepProportions:(BOOL)aProportions
{
	_keepProportions = aProportions;
}

- (void)setTitle:(id)aTitle
{
	[_title release];
	_title = aTitle != nil ? [[NSString alloc] initWithString:aTitle] : nil;
}

- (id)title
{
	return _title;
}

- (void)setFont:(id)aFont
{
	[aFont retain];
	[_font release];
	_font = aFont;
}

- (id)font
{
	return _font;
}

- (void)performAction
{
	if (_currentState != 3) {
		[_target performSelector:_selector withObject:self];
	}
}

- (void)setTag:(NSInteger)aTag
{
	_tag = (int)aTag;
}

- (NSInteger)tag
{
	return _tag;
}

- (void)setTarget:(id)aTarget selector:(SEL)aSelector
{
	_target = aTarget;
	_selector = aSelector;
}

- (void)setTrackable:(BOOL)aTrackable
{
	_trackable = aTrackable;
}

- (void)setState:(NSInteger)aState
{
	_currentState = (int)aState;
}

- (NSInteger)state
{
	return _currentState;
}

- (BOOL)hitByPoint:(NSPoint)aPoint
{
	return _currentState != 3 && _trackable && NSPointInRect(aPoint, _rect);
}

- (NSRect)frame
{
	return _rect;
}

- (void)dealloc
{
	[_normalTexture release];
	[_overTexture release];
	[_title release];
	[_font release];
	[super dealloc];
}

- (id)initWithNormalTexture:(id)aTexture mouseOverTexture:(id)aTexture2 rect:(NSRect)aRect
{
	self = [super init];
	if (self != nil) {
		_normalTexture = [aTexture retain];
		_overTexture = [aTexture2 retain];
		_rect = aRect;
		_trackable = YES;
	}
	return self;
}

@end
