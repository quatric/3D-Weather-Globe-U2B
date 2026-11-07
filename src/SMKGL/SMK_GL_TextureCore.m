// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_TextureCore.m
#import "SMK_GL_TextureCore.h"

// Texture object and texture environment state. The "arg" setters choose
// the combiner sources and the "src" setters their operands.
@implementation SMK_GL_TextureCore

- (void)unbindAtStage:(NSInteger)aStage
{
	glActiveTextureARB(GL_TEXTURE0_ARB + (GLenum)aStage);
	glDisable(_textureTarget);
}

- (void)bindAtStage:(NSInteger)aStage
{
	glActiveTextureARB(GL_TEXTURE0_ARB + (GLenum)aStage);
	glEnable(_textureTarget);
	glBindTexture(_textureTarget, _textureID);
	if (_wrapModeChanged) {
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_S, _sWrapMode);
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_T, _tWrapMode);
		_wrapModeChanged = NO;
	}
	if (_biasChanged) {
		glTexParameterf(_textureTarget, GL_TEXTURE_LOD_BIAS_EXT, _bias);
		_biasChanged = NO;
	}
	if (_useCombiners && _combineExt) {
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE_ARB);
		glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_RGB_ARB, _combinerMode);
		glTexEnvi(GL_TEXTURE_ENV, GL_COMBINE_ALPHA_ARB, _combinerAlphaMode);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_RGB_ARB, _combinerRGBArg0);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_RGB_ARB, _combinerRGBArg1);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_RGB_ARB, _combinerRGBArg2);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE0_ALPHA_ARB, _combinerAlphaArg0);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE1_ALPHA_ARB, _combinerAlphaArg1);
		glTexEnvi(GL_TEXTURE_ENV, GL_SOURCE2_ALPHA_ARB, _combinerAlphaArg2);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_RGB_ARB, _combinerRGBSrc0);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_RGB_ARB, _combinerRGBSrc1);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_RGB_ARB, _combinerRGBSrc2);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND0_ALPHA_ARB, _combinerAlphaSrc0);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND1_ALPHA_ARB, _combinerAlphaSrc1);
		glTexEnvi(GL_TEXTURE_ENV, GL_OPERAND2_ALPHA_ARB, _combinerAlphaSrc2);
		glTexEnvi(GL_TEXTURE_ENV, GL_RGB_SCALE_ARB, _combinerRGBScale);
		glTexEnvi(GL_TEXTURE_ENV, GL_ALPHA_SCALE, _combinerAlphaScale);
	}
	else {
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, _combinerMode);
	}
	glTexEnvfv(GL_TEXTURE_ENV, GL_TEXTURE_ENV_COLOR, &_constantColor.r);
	_isDirty = NO;
}

- (BOOL)isDirty
{
	return _isDirty;
}

- (void)setConstantColor:(SMK_GL_Color)aColor
{
	_constantColor = aColor;
	_isDirty = YES;
}

- (void)setCombinerAlphaScale:(NSInteger)aScale
{
	_combinerAlphaScale = (int)aScale;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerRGBScale:(NSInteger)aScale
{
	_combinerRGBScale = (int)aScale;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerAlphaSrc0:(NSUInteger)aSrc0 src1:(NSUInteger)aSrc1 src2:(NSUInteger)aSrc2
{
	_combinerAlphaSrc0 = (unsigned int)aSrc0;
	_combinerAlphaSrc1 = (unsigned int)aSrc1;
	_combinerAlphaSrc2 = (unsigned int)aSrc2;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerRGBSrc0:(NSUInteger)aSrc0 src1:(NSUInteger)aSrc1 src2:(NSUInteger)aSrc2
{
	_combinerRGBSrc0 = (unsigned int)aSrc0;
	_combinerRGBSrc1 = (unsigned int)aSrc1;
	_combinerRGBSrc2 = (unsigned int)aSrc2;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerAlphaArg0:(NSUInteger)aArg0 arg1:(NSUInteger)aArg1 arg2:(NSUInteger)aArg2
{
	_combinerAlphaArg0 = (unsigned int)aArg0;
	_combinerAlphaArg1 = (unsigned int)aArg1;
	_combinerAlphaArg2 = (unsigned int)aArg2;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerRGBArg0:(NSUInteger)aArg0 arg1:(NSUInteger)aArg1 arg2:(NSUInteger)aArg2
{
	_combinerRGBArg0 = (unsigned int)aArg0;
	_combinerRGBArg1 = (unsigned int)aArg1;
	_combinerRGBArg2 = (unsigned int)aArg2;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerAlphaMode:(NSUInteger)aMode
{
	_combinerAlphaMode = (unsigned int)aMode;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setCombinerMode:(NSUInteger)aMode
{
	_combinerMode = (unsigned int)aMode;
	_useCombiners = YES;
	_isDirty = YES;
}

- (void)setEnvMode:(NSUInteger)aMode
{
	_combinerMode = (unsigned int)aMode;
	_useCombiners = NO;
	_isDirty = YES;
}

- (void)setLODBias:(CGFloat)aBias
{
	_bias = aBias;
	_biasChanged = YES;
	_isDirty = YES;
}

- (void)setWrapS:(NSUInteger)aS T:(NSUInteger)aT
{
	_sWrapMode = (unsigned int)aS;
	_tWrapMode = (unsigned int)aT;
	_wrapModeChanged = YES;
	_isDirty = YES;
}

- (NSUInteger)textureTarget
{
	return 0;
}

- (void)contextWillBeDetached
{
	if (_textureID != 0) {
		glDeleteTextures(1, &_textureID);
	}
	_textureID = 0;
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	[super contextWasAttached:aAttached];
	glGenTextures(1, &_textureID);
}

- (id)initWithContainer:(id)aContainer
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		_sWrapMode = GL_CLAMP_TO_EDGE;
		_tWrapMode = GL_CLAMP_TO_EDGE;
		_wrapModeChanged = YES;
		_combinerMode = GL_MODULATE;
		_combinerAlphaMode = GL_MODULATE;
		_combinerRGBArg0 = GL_TEXTURE;
		_combinerRGBArg1 = GL_PREVIOUS_ARB;
		_combinerRGBArg2 = GL_CONSTANT_ARB;
		_combinerAlphaArg0 = GL_TEXTURE;
		_combinerAlphaArg1 = GL_PREVIOUS_ARB;
		_combinerAlphaArg2 = GL_CONSTANT_ARB;
		_combinerRGBSrc0 = GL_SRC_COLOR;
		_combinerRGBSrc1 = GL_SRC_COLOR;
		_combinerRGBSrc2 = GL_SRC_COLOR;
		_combinerAlphaSrc0 = GL_SRC_ALPHA;
		_combinerAlphaSrc1 = GL_SRC_ALPHA;
		_combinerAlphaSrc2 = GL_SRC_ALPHA;
		_combinerRGBScale = 1;
		_combinerAlphaScale = 1;
	}
	return self;
}

@end
