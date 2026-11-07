// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_RenderTarget.m
#import "SMK_GL_RenderTarget.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// A texture that can be rendered into through an OpenGL pixel buffer.
@implementation SMK_GL_RenderTarget

- (void)bindAtStage:(NSInteger)aStage
{
	[super bindAtStage:aStage];
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	if (_textureTarget == GL_TEXTURE_RECTANGLE_EXT) {
		// rectangle textures use texel coordinates
		glScalef((float)_width, (float)_height, 1.0f);
	}
	glMatrixMode(GL_MODELVIEW);
}

- (void)deactivateInContext:(id)aContext
{
	if (_pBuffer != nil) {
		NSOpenGLContext *system = [aContext systemContext];
		glFinish();
		[system makeCurrentContext];
		_isDirty = YES;
	}
}

- (BOOL)activateAsRenderTargetInContext:(id)aContext
{
	if (_pBuffer == nil) {
		return NO;
	}
	glFinish();
	[_pBuffContext makeCurrentContext];
	glViewport(0, 0, _width, _height);
	return YES;
}

- (void)setClearColor:(SMK_GL_Color)aColor
{
	_clearColor = aColor;
}

- (SMK_GL_Color)clearColor
{
	return _clearColor;
}

- (void)setScene:(id)aScene
{
	[aScene retain];
	[_scene release];
	_scene = aScene;
}

- (id)scene
{
	return _scene;
}

- (NSSize)size
{
	return NSMakeSize((float)_width, (float)_height);
}

- (void)contextWillBeDetached
{
	[_pBuffContext release];
	_pBuffContext = nil;
	_pBuffer = nil;
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	_textureTarget = (unsigned int)[self textureTarget];
	[super contextWasAttached:aAttached];
	if (![aAttached pixelBuffers]) {
		return;
	}
	Class pixelBufferClass = NSClassFromString(@"NSOpenGLPixelBuffer");
	if (pixelBufferClass == Nil) {
		return;
	}
	NSOpenGLPixelFormatAttribute attributes[] = {
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, _format == GL_RGBA ? 8 : 0,
		NSOpenGLPFADepthSize, 0,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAPixelBuffer,
		0
	};
	NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
	_pBuffContext = [[NSOpenGLContext alloc] initWithFormat:format shareContext:[aAttached systemContext]];
	NSAssert(_pBuffContext != nil, @"Unable to create pixel buffer's context");
	_pBuffer = [[[pixelBufferClass alloc] initWithTextureTarget:_textureTarget textureInternalFormat:_format
		textureMaxMipMapLevel:0 pixelsWide:_width pixelsHigh:_height] autorelease];
	[_pBuffContext setPixelBuffer:_pBuffer cubeMapFace:0 mipMapLevel:0 currentVirtualScreen:0];
	glActiveTextureARB(GL_TEXTURE0_ARB);
	glBindTexture(_textureTarget, _textureID);
	glEnable(_textureTarget);
	glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	[[_context systemContext] setTextureImageToPixelBuffer:_pBuffer colorBuffer:GL_FRONT_LEFT];
	if (!glIsTexture(_textureID)) {
		NSLog(@"failed to create texture attached to pbuffer");
	}
	glDisable(_textureTarget);
}

- (NSUInteger)textureTarget
{
	const GLubyte *extensions = glGetString(GL_EXTENSIONS);
	if (gluCheckExtension((const GLubyte *)"GL_EXT_texture_rectangle", extensions) == GL_TRUE
		&& (_width != _height || (_width & (_width - 1)) != 0)) {
		return GL_TEXTURE_RECTANGLE_EXT;
	}
	return GL_TEXTURE_2D;
}

- (BOOL)isValid
{
	return _pBuffer != nil;
}

- (void)dealloc
{
	[_pBuffer release];
	_pBuffer = nil;
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer width:(NSInteger)aWidth height:(NSInteger)aHeight format:(NSUInteger)aFormat
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		if (aWidth == aHeight && (aWidth & (aWidth - 1)) == 0) {
			_width = (int)aWidth;
			_height = (int)aWidth;
			_format = (unsigned int)aFormat;
		}
		else {
			NSLog(@"Only square power-of-two size render targets are allowed.");
			[self dealloc];
			self = nil;
		}
	}
	return self;
}

@end
