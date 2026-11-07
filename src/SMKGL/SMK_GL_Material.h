// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Material.m
#import "SMKGLPrefix.h"
#import "SMK_GL_object.h"


@interface SMK_GL_Material : SMK_GL_Object
{
    SMK_GL_Color _ambient;
    SMK_GL_Color _diffuse;
    SMK_GL_Color _emission;
    SMK_GL_Color _specular;
    float _shininess;
    BOOL _isDirty;
    SMK_GL_TextureCore * _textures[16];
    SMK_GL_VertexProgram *_vertexProg;
    SMK_GL_FragmentProgram *_fragmentProg;
}
- (void)setFragmentProgram:(id)aProgram;
- (void)setVertexProgram:(id)aProgram;
- (id)textureAtStage:(NSInteger)aStage;
- (void)setTexture:(id)aTexture atStage:(NSInteger)aStage;
- (void)setShininess:(CGFloat)aShininess;
- (void)setSpecular:(SMK_GL_Color)aSpecular;
- (void)setEmission:(SMK_GL_Color)aEmission;
- (void)setDiffuse:(SMK_GL_Color)aDiffuse;
- (void)setAmbient:(SMK_GL_Color)aAmbient;
- (void)unbind;
- (void)bind;
- (BOOL)isDirty;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
@end

