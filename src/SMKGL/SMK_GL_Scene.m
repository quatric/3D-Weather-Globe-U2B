// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Scene.m
#import "SMK_GL_Scene.h"

// Control states: 0 normal, 1 mouse over, 2 pressed.
@implementation SMK_GL_Scene

- (void)animate:(double)aAnimate
{
}

- (void)keyUp:(id)aUp inView:(id)aView
{
}

- (void)keyDown:(id)aDown inView:(id)aView
{
}

- (void)mouseExited:(id)aExited inView:(id)aView
{
}

- (void)mouseEntered:(id)aEntered inView:(id)aView
{
}

- (BOOL)acceptsFirstResponderInView:(id)aView
{
	return [_controls count] != 0;
}

- (void)mouseMoved:(id)aMoved inView:(id)aView
{
	NSPoint p = [self _glPointFromEvent:aMoved inView:aView];
	if (p.x < -1.0 || p.y < -1.0 || p.x > 1.0 || p.y > 1.0) {
		if (_prevOverControl == nil) {
			return;
		}
		[_prevOverControl setState:0];
		_prevOverControl = nil;
	}
	else {
		NSUInteger count = [_controls count];
		NSUInteger i;
		for (i = 0; i < count; i++) {
			id control = [_controls objectAtIndex:i];
			if ([control hitByPoint:p]) {
				[_prevOverControl setState:0];
				_prevOverControl = control;
				[control setState:1];
				break;
			}
		}
		if (i == count) {
			[_prevOverControl setState:0];
			_prevOverControl = nil;
		}
	}
	[self _controlsAppearanceWasChanged];
}

- (void)mouseUp:(id)aUp inView:(id)aView
{
	NSPoint p = [self _glPointFromEvent:aUp inView:aView];
	if ([_prevOverControl hitByPoint:p]) {
		[_prevOverControl performAction];
		[_prevOverControl setState:1];
	}
	else {
		[_prevOverControl setState:0];
		NSUInteger count = [_controls count];
		for (NSUInteger i = 0; i < count; i++) {
			id control = [_controls objectAtIndex:i];
			if ([control hitByPoint:p]) {
				_prevOverControl = control;
				[control setState:1];
				break;
			}
		}
	}
	[self _controlsAppearanceWasChanged];
}

- (void)mouseDragged:(id)aDragged inView:(id)aView
{
	if (_prevOverControl != nil) {
		NSPoint p = [self _glPointFromEvent:aDragged inView:aView];
		[_prevOverControl setState:[_prevOverControl hitByPoint:p] ? 2 : 0];
		[self _controlsAppearanceWasChanged];
	}
}

- (void)mouseDown:(id)aDown inView:(id)aView
{
	NSPoint p = [self _glPointFromEvent:aDown inView:aView];
	NSUInteger count = [_controls count];
	for (NSUInteger i = 0; i < count; i++) {
		id control = [_controls objectAtIndex:i];
		if ([control hitByPoint:p]) {
			[_prevOverControl setState:0];
			_prevOverControl = control;
			[control setState:2];
			[self _controlsAppearanceWasChanged];
			return;
		}
	}
}

// the event's location in GL's -1..1 viewport coordinates
- (NSPoint)_glPointFromEvent:(id)aEvent inView:(id)aView
{
	NSPoint p = [aView convertPoint:[aEvent locationInWindow] fromView:nil];
	NSRect frame = [aView frame];
	float x = (float)(p.x + frame.origin.x) / (float)frame.size.width;
	float y = (float)(p.y + 0.0f) / (float)frame.size.height;
	return NSMakePoint(x + x - 1.0f, y + y - 1.0f);
}

- (void)removeAllControls
{
	if (_controls != nil) {
		[_controls removeAllObjects];
		[_controls release];
		_controls = nil;
	}
}

- (void)removeControl:(id)aControl
{
	if (_controls != nil) {
		if (_prevOverControl == aControl) {
			_prevOverControl = nil;
		}
		[_controls removeObject:aControl];
		[self _controlsAppearanceWasChanged];
	}
}

- (void)addControl:(id)aControl
{
	if (_controls == nil) {
		_controls = [NSMutableArray new];
	}
	[_controls addObject:aControl];
	[self _controlsAppearanceWasChanged];
}

- (void)_controlsAppearanceWasChanged
{
}

- (void)drawInFocusedView:(id)aView inRect:(NSRect)aRect
{
}

- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize
{
	[aContext evaluateFrustumForCamera:_camera forSize:aSize];
	[_camera applyCameraMatricesForSize:aSize];
	[self setupLightsInContext:aContext];
	[self drawObjectsInContext:aContext];
	[self drawControlsInContext:aContext];
}

- (void)drawControlsInContext:(id)aContext
{
	[aContext enter2DMode];
	[_controls makeObjectsPerformSelector:@selector(drawInContext:) withObject:aContext];
	[aContext exit2DMode];
}

- (void)drawObjectsInContext:(id)aContext
{
	[_objects makeObjectsPerformSelector:@selector(drawInContext:) withObject:aContext];
}

- (void)setupLightsInContext:(id)aContext
{
	[aContext resetAllLights];
	NSEnumerator *e = [_lights objectEnumerator];
	id light;
	while ((light = [e nextObject]) != nil) {
		if ([light isActive]) {
			[aContext activateLight:light];
		}
	}
}

- (void)setupCameraForSize:(NSSize)aSize
{
	[_camera applyCameraMatricesForSize:aSize];
}

- (void)setCamera:(id)aCamera
{
	if (_camera != aCamera) {
		[_camera release];
		_camera = [aCamera retain];
	}
}

- (id)camera
{
	return _camera;
}

- (void)removeLight:(id)aLight
{
	[_lights removeObject:aLight];
}

- (void)addLight:(id)aLight
{
	[_lights addObject:aLight];
}

- (id)lights
{
	return [_lights allObjects];
}

- (void)removeDrawable:(id)aDrawable
{
	[_objects removeObject:aDrawable];
}

- (void)addDrawable:(id)aDrawable
{
	NSAssert(![_objects containsObject:aDrawable], @"Unable add drawable more than once.");
	[_objects addObject:aDrawable];
}

- (id)controlObjects
{
	return _controls;
}

- (id)drawableObjects
{
	return _objects;
}

- (void)dealloc
{
	[_controls release];
	[_lights release];
	[_objects release];
	[_camera release];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_camera = [SMK_GL_Camera new];
		_objects = [NSMutableArray new];
		_lights = [NSMutableSet new];
	}
	return self;
}

@end
