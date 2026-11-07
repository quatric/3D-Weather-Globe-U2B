// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_TextureCore.m
#import "SMKGLPrefix.h"
#import "SMK_GL_object.h"


@interface SMK_GL_TextureCore : SMK_GL_Object
{
    unsigned int _textureID;
    unsigned int _textureTarget;
    unsigned int _sWrapMode;
    unsigned int _tWrapMode;
    BOOL _wrapModeChanged;
    float _bias;
    BOOL _biasChanged;
    BOOL _isDirty;
    BOOL _combineExt;
    BOOL _useCombiners;
    unsigned int _combinerMode;
    unsigned int _combinerAlphaMode;
    unsigned int _combinerRGBArg0;
    unsigned int _combinerRGBArg1;
    unsigned int _combinerRGBArg2;
    unsigned int _combinerAlphaArg0;
    unsigned int _combinerAlphaArg1;
    unsigned int _combinerAlphaArg2;
    unsigned int _combinerRGBSrc0;
    unsigned int _combinerRGBSrc1;
    unsigned int _combinerRGBSrc2;
    unsigned int _combinerAlphaSrc0;
    unsigned int _combinerAlphaSrc1;
    unsigned int _combinerAlphaSrc2;
    int _combinerRGBScale;
    int _combinerAlphaScale;
    SMK_GL_Color _constantColor;
}
- (void)unbindAtStage:(NSInteger)aStage;
- (void)bindAtStage:(NSInteger)aStage;
- (BOOL)isDirty;
- (void)setConstantColor:(SMK_GL_Color)aColor;
- (void)setCombinerAlphaScale:(NSInteger)aScale;
- (void)setCombinerRGBScale:(NSInteger)aScale;
- (void)setCombinerAlphaSrc0:(NSUInteger)aSrc0 src1:(NSUInteger)aSrc1 src2:(NSUInteger)aSrc2;
- (void)setCombinerRGBSrc0:(NSUInteger)aSrc0 src1:(NSUInteger)aSrc1 src2:(NSUInteger)aSrc2;
- (void)setCombinerAlphaArg0:(NSUInteger)aArg0 arg1:(NSUInteger)aArg1 arg2:(NSUInteger)aArg2;
- (void)setCombinerRGBArg0:(NSUInteger)aArg0 arg1:(NSUInteger)aArg1 arg2:(NSUInteger)aArg2;
- (void)setCombinerAlphaMode:(NSUInteger)aMode;
- (void)setCombinerMode:(NSUInteger)aMode;
- (void)setEnvMode:(NSUInteger)aMode;
- (void)setLODBias:(CGFloat)aBias;
- (void)setWrapS:(NSUInteger)aS T:(NSUInteger)aT;
- (NSUInteger)textureTarget;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (id)initWithContainer:(id)aContainer;
@end

