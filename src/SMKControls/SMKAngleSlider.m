// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKAngleSlider.m
#import "SMKAngleSlider.h"

// A round slider choosing an angle; arrow keys turn it.
@implementation SMKAngleSlider

+ (Class)cellClass
{
	return [SMKAngleSliderCell class];
}

- (void)setAngle:(CGFloat)aAngle
{
	_cachedAngleValue = (float)aAngle;
	[[self cell] setAngleValue:aAngle];
}

- (CGFloat)angle
{
	return _cachedAngleValue;
}

- (void)setFloatValue:(float)aValue
{
	[self setAngle:aValue];
}

- (float)floatValue
{
	return (float)[self angle];
}

// up and right turn one way, down and left the other
- (void)keyDown:(id)aDown
{
	NSEventModifierFlags flags = [aDown modifierFlags];
	NSString *characters = [[aDown charactersIgnoringModifiers] retain];
	NSUInteger i = [characters length];
	while (i != 0) {
		i--;
		unichar c = [characters characterAtIndex:i];
		if (c == NSUpArrowFunctionKey || c == NSRightArrowFunctionKey) {
			[[self cell] moveInDirection:0 withFlags:flags];
		}
		else if (c == NSDownArrowFunctionKey || c == NSLeftArrowFunctionKey) {
			[[self cell] moveInDirection:1 withFlags:flags];
		}
		else {
			[super keyDown:aDown];
		}
	}
	[characters release];
}

// only actually changed angles are sent
- (BOOL)sendAction:(SEL)aAction to:(id)aTo
{
	float angle = (float)[[self cell] angleValue];
	if (_cachedAngleValue == angle) {
		return NO;
	}
	_cachedAngleValue = angle;
	return [super sendAction:aAction to:aTo];
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self != nil) {
		_cachedAngleValue = 0.0f;
	}
	return self;
}

- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	if (self != nil) {
		[self setContinuous:YES];
		_cachedAngleValue = 0.0f;
	}
	return self;
}

- (BOOL)acceptsFirstMouse:(id)aMouse
{
	return YES;
}

- (BOOL)isOpaque
{
	return NO;
}

@end
