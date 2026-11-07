// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Context.m
#import "SMKGLPrefix.h"

// pushStateComponents: flags
enum {
	kSMK_GL_StateColor = 1 << 0,
	kSMK_GL_StateBlendEnable = 1 << 1,
	kSMK_GL_StateBlendFunc = 1 << 2,
	kSMK_GL_StateCullEnable = 1 << 3,
	kSMK_GL_StateCullFace = 1 << 4,
};


@interface SMK_GL_Context : NSObject
{
    SMK_GL_ObjectsContainer *_container;
    NSOpenGLContext *_nsContext;
    SMK_GL_View *_view;
    SMK_GL_VertexBuffer *_currentVertBuffer;
    SMK_GL_VertexBuffer *_prevUsedVertBuffer;
    SMK_GL_IndexBuffer *_currentIndBuffer;
    SMK_GL_IndexBuffer *_prevUsedIndBuffer;
    SMK_GL_TextureCore * _currentTextures[16];
    SMK_GL_Material *_currentMaterial;
    int _textureUnitsCount;
    SMK_GL_Light * _activeLights[8];
    int _lightsCount;
    SMK_GL_Color _clearColor;
    SMK_GL_Color _color;
    SMK_GL_Frustum _frustum;
    NSSize _size;
    SMK_GL_Mesh *_2DMesh;
    SMK_GL_Font *_currentFont;
    SMK_GL_Font *_defaultFont;
    unsigned char _depthWasEnabledBefore2D;
    NSThread *_creationThread;
    NSMutableData *_VAR;
    NSMutableArray *_freeRangesInVAR;
    NSRange _flushRangesInVAR;
    BOOL _isIn2DMode;
    BOOL _textureCombineARB;
    BOOL _textureDot3ARB;
    BOOL _textureRectangleEXT;
    BOOL _textureRangeAPPLE;
    BOOL _vertexArrayRangeAPPLE;
    BOOL _vertexBufferObjectARB;
    BOOL _drawRangeElementsEXT;
    BOOL _elementArrayAPPLE;
    BOOL _fragmentProgramARB;
    BOOL _vertexProgramARB;
    BOOL _fragmentShaderARB;
    BOOL _vertexShaderARB;
    BOOL _generateMipmapSGIS;
    BOOL _textureLodSGIS;
    BOOL _pixelBuffers;
    NSMutableData *_stateStorage;
    SMK_GL_RenderTarget *_renderTarget;
    SMK_GL_Drawable *_drawable;
    BOOL _invWorldMatrixisValid;
    SMK_GL_Matrix _invWorldMatrix;
}
- (const SMK_GL_Matrix *)worldMatrixInverse;
- (const SMK_GL_Matrix *)worldMatrix;
- (id)currentDrawable;
- (void)invalDrawableMatricesForDrawable:(id)aDrawable;
- (void)setCurrentDrawable:(id)aDrawable;
- (void)popState;
- (void)pushStateComponents:(NSInteger)aComponents;
- (void)drawNonIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount;
- (void)drawIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount;
- (void)_bindBuffersBeforeDraw;
- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2 backColor:(const SMK_GL_Color *)aColor;
- (void)drawString:(id)aString atPosition:(NSPoint)aPosition backColor:(const SMK_GL_Color *)aColor;
- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2;
- (void)drawString:(id)aString atPosition:(NSPoint)aPosition;
- (void)setFont:(id)aFont;
- (id)currentFont;
- (id)defaultFont;
- (SMK_GL_Color *)color;
- (void)setColor:(const SMK_GL_Color *)aColor;
- (void)drawTexture0:(id)aTexture0 texture1:(id)aTexture1 inRect:(NSRect)aRect;
- (void)drawTexture:(id)aTexture inRect:(NSRect)aRect;
- (void)_draw2DInRect:(NSRect)aRect;
- (BOOL)isIn2DMode;
- (void)exit2DMode;
- (void)enter2DMode;
- (void)_create2DMeshIfNeeded;
- (void)turnOnLighting;
- (void)turnOffLighting;
- (void)deactivateLight:(id)aLight;
- (void)activateLight:(id)aLight;
- (void)resetAllLights;
- (void)resetAllTextures;
- (void)setTexture:(id)aTexture atStage:(NSInteger)aStage;
- (void)setAllTextures:(id *)aTextures;
- (NSInteger)textureUnitsCount;
- (void)_bufferWillDie:(id)aDie;
- (void)_resetAllBondBuffers;
- (void)setIndexBuffer:(id)aBuffer;
- (void)setVertexBuffer:(id)aBuffer;
- (void)setMaterial:(id)aMaterial;
- (BOOL)setRenderTarget:(id)aTarget;
- (id)renderTarget;
- (void)evaluateFrustumForCamera:(id)aCamera forSize:(NSSize)aSize;
- (SMK_GL_Frustum *)viewFrustum;
- (void)setClearColor:(SMK_GL_Color)aColor;
- (SMK_GL_Color)clearColor;
- (NSSize)size;
- (id)creationThread;
- (id)objectsContainer;
- (void)makeCurrent;
- (BOOL)pixelBuffers;
- (BOOL)textureLodSGIS;
- (BOOL)generateMipmapSGIS;
- (BOOL)vertexShaderARB;
- (BOOL)fragmentShaderARB;
- (BOOL)vertexProgramARB;
- (BOOL)fragmentProgramARB;
- (BOOL)elementArrayAPPLE;
- (BOOL)drawRangeElementsEXT;
- (BOOL)vertexBufferObjectARB;
- (BOOL)vertexArrayRangeAPPLE;
- (BOOL)textureRangeAPPLE;
- (BOOL)textureRectangleEXT;
- (BOOL)textureDot3ARB;
- (BOOL)textureCombineARB;
- (void *)_currentPointerVAR;
- (void)_flushVAR:(NSRange)aVAR;
- (void)_accumulateFlushVAR:(NSRange)aVAR;
- (void)_deallocateVAR:(NSRange)aVAR;
- (NSRange)_allocateVAR:(NSUInteger)aVAR;
- (void)dealloc;
- (id)glView;
- (id)systemContext;
- (id)initWithContainer:(id)aContainer systemContext:(id)aContext view:(id)aView;
@end

