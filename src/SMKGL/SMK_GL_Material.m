// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Material.m
#import "SMK_GL_Material.h"

// GL material colors plus up to 16 texture stages and optional programs.
@implementation SMK_GL_Material

- (void)setFragmentProgram:(id)aProgram
{
	[aProgram retain];
	[_fragmentProg release];
	_fragmentProg = aProgram;
}

- (void)setVertexProgram:(id)aProgram
{
	[aProgram retain];
	[_vertexProg release];
	_vertexProg = aProgram;
}

- (id)textureAtStage:(NSInteger)aStage
{
	NSAssert((NSUInteger)aStage < 16, @"Bad texture index.");
	return _textures[aStage];
}

- (void)setTexture:(id)aTexture atStage:(NSInteger)aStage
{
	NSAssert((NSUInteger)aStage < 16, @"Bad texture index.");
	if (_textures[aStage] != aTexture) {
		[_textures[aStage] release];
		_textures[aStage] = [aTexture retain];
		_isDirty = YES;
	}
}

- (void)setShininess:(CGFloat)aShininess
{
	_shininess = (float)aShininess;
	_isDirty = YES;
}

- (void)setSpecular:(SMK_GL_Color)aSpecular
{
	_specular = aSpecular;
	_isDirty = YES;
}

- (void)setEmission:(SMK_GL_Color)aEmission
{
	_emission = aEmission;
	_isDirty = YES;
}

- (void)setDiffuse:(SMK_GL_Color)aDiffuse
{
	_diffuse = aDiffuse;
	_isDirty = YES;
}

- (void)setAmbient:(SMK_GL_Color)aAmbient
{
	_ambient = aAmbient;
	_isDirty = YES;
}

- (void)unbind
{
	[_vertexProg unbind];
	[_fragmentProg unbind];
	[_context resetAllTextures];
}

- (void)bind
{
	glColor4fv(&_ambient.r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, &_ambient.r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, &_diffuse.r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, &_emission.r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, &_specular.r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, &_shininess);
	[_context setAllTextures:_textures];
	[_vertexProg bind];
	[_fragmentProg bind];
	_isDirty = NO;
}

// programs may have changed their parameters, so a material with them always rebinds
- (BOOL)isDirty
{
	return _isDirty || _vertexProg != nil || _fragmentProg != nil;
}

- (void)dealloc
{
	for (int i = 0; i < 16; i++) {
		[_textures[i] release];
	}
	[_vertexProg release];
	[_fragmentProg release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
	return [super initWithContainer:aContainer];
}

@end
