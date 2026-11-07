// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/TransformerScene.m
#import "TransformerScene.h"
#import "PlaneTransformer.h"

// The base of the window transition scenes. Type 1 is the plane flip.
@implementation _TransformerScene

+ (id)transformerSceneWithType:(NSInteger)aType viewTransformer:(id)aTransformer
{
	if (aType == 1) {
		return [[[_PlaneScene alloc] initWithTransformer:aTransformer type:1] autorelease];
	}
	return nil;
}

+ (NSRect)windowRectForContentRect:(NSRect)aRect transformerType:(NSInteger)aType
{
	if (aType == 1) {
		return [_PlaneScene windowRectForContentRect:aRect];
	}
	return aRect;
}

- (double)transformDuration
{
	return 1.0;
}

- (id)nextTexture
{
	return [_transformer nextTexture];
}

- (id)currentTexture
{
	return [_transformer currentTexture];
}

- (BOOL)animateWithProgress:(CGFloat)aProgress
{
	_progress = (float)aProgress;
	return YES;
}

- (NSSize)frameSize
{
	return [[_transformer glView] frame].size;
}

- (NSRect)contentRect
{
	return [_transformer contentRect];
}

- (NSInteger)transformType
{
	return _type;
}

- (id)initWithTransformer:(id)aTransformer type:(NSInteger)aType
{
	self = [super init];
	if (self != nil) {
		_transformer = aTransformer;
		_type = (int)aType;
		_container = [[aTransformer glView] objectsContainer];
	}
	return self;
}

@end

@implementation WindowTransformer (TransformerScenePrivate)

- (NSRect)contentRect
{
	return _contentRect;
}

- (id)nextTexture
{
	return _textureNext;
}

- (id)currentTexture
{
	return _textureCurrent;
}

@end
