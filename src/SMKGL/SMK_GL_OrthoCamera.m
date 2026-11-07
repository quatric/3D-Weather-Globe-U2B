// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_OrthoCamera.m
#import "SMK_GL_OrthoCamera.h"

@implementation SMK_GL_OrthoCamera

- (CGFloat)frustumHeight
{
	return _frustHeight;
}

- (CGFloat)frustumWidth
{
	return _frustWidth;
}

- (void)applyCameraMatricesForSize:(NSSize)aSize
{
	[super applyCameraMatricesForSize:aSize];
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(_frustWidth * -0.5f, _frustWidth * 0.5f, _frustHeight * -0.5f, _frustHeight * 0.5f,
		_minZ, _maxZ);
	glMatrixMode(GL_MODELVIEW);
}

- (void)setFrustumHeight:(CGFloat)aHeight
{
	_frustHeight = aHeight;
}

- (void)setFrustumWidth:(CGFloat)aWidth
{
	_frustWidth = aWidth;
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_frustWidth = 2.0f;
		_frustHeight = 2.0f;
	}
	return self;
}

@end
