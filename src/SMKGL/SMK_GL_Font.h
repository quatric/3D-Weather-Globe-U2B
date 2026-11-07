// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Font.m
#import "SMKGLPrefix.h"
#import "SMK_GL_object.h"


@interface SMK_GL_Font : SMK_GL_Object
{
    NSFont *_font;
    BOOL _useGlyphs;
    unsigned int _glyphs[25468];
    NSAttributedString *_glyphsSourceString;
    SMK_GL_2DTexture *_texture;
    NSSize _characterSizesIn2DMode[223];
    SMK_GL_Vec2 _texturesCharactersCoordinates[223][4];
    SMK_GL_IndexBuffer *_indexBuffer;
    SMK_GL_VertexBuffer *_vertexBuffer;
    float _spacingX;
    float _spacingY;
    float _fontScale;
    float _maxHeight;
    SMK_GL_Matrix _fontOutlineTranslateMatrix;
    int _textureWidth;
    int _textureHeight;
    NSSize _oneCharSize;
    NSDictionary *_fontAttrDictionary;
    SMK_GL_Vec3 _positionVerexBuffer[4];
}
+ (id)glFontWithContainer:(id)aContainer font:(id)aFont;
- (id)cocoaFont;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer font:(id)aFont;
- (void)_generateGlyphs;
@end

@interface SMK_GL_Font (SMK_GL_ExtendedFont)
- (NSSize *)sizeOfCharacter:(unsigned char)aCharacter;
- (SMK_GL_Vec2 *)textureCoordinatesForCharacter:(unsigned char)aCharacter;
- (CGFloat)maxHeight;
- (void)bindTextureWithForeColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2;
- (id)texture;
@end

@interface SMK_GL_Font (Private)
- (void)setIntAttribute:(NSInteger)aAttribute value:(NSInteger)aValue forGlyphAtIndex:(NSUInteger)aIndex;
- (void)insertGlyphs:(unsigned int *)aGlyphs length:(NSUInteger)aLength forStartingGlyphAtIndex:(NSUInteger)aIndex characterIndex:(NSUInteger)aIndex2;
- (NSUInteger)layoutOptions;
- (id)attributedString;
- (void)_createAndFillTexture;
- (BOOL)_paintAlphabetWithMeasureOnly:(BOOL)aOnly;
@end

