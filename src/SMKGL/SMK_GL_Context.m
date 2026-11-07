// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Context.m
#import "SMK_GL_Context.h"

// what pushStateComponents: saves, popped by popState
typedef struct {
	int components;
	SMK_GL_Color color;
	GLfloat blendColor[4];
	GLint blendDst;
	GLint blendSrc;
	GLboolean blend;
	GLboolean cullFace;
	GLint cullFaceMode;
} SMK_GL_SavedState;

@implementation SMK_GL_Context

- (const SMK_GL_Matrix *)worldMatrixInverse
{
	if (!_invWorldMatrixisValid && _drawable != nil) {
		matrix_invert(&_invWorldMatrix, [_drawable matrix]);
		_invWorldMatrixisValid = YES;
	}
	return &_invWorldMatrix;
}

- (const SMK_GL_Matrix *)worldMatrix
{
	return [_drawable matrix];
}

- (id)currentDrawable
{
	return _drawable;
}

- (void)invalDrawableMatricesForDrawable:(id)aDrawable
{
	if (aDrawable == _drawable) {
		_invWorldMatrixisValid = NO;
	}
}

- (void)setCurrentDrawable:(id)aDrawable
{
	_invWorldMatrixisValid = NO;
	_drawable = aDrawable;
}

- (void)popState
{
	NSAssert([_stateStorage length] != 0 && [_stateStorage length] % sizeof(SMK_GL_SavedState) == 0,
		@"GL context state's stack error!");
	SMK_GL_SavedState s;
	memcpy(&s, (const char *)[_stateStorage bytes] + [_stateStorage length] - sizeof(s), sizeof(s));
	if (s.components & kSMK_GL_StateColor) {
		[self setColor:&s.color];
	}
	if (s.components & kSMK_GL_StateBlendEnable) {
		if (s.blend == GL_TRUE) {
			glEnable(GL_BLEND);
		}
		else {
			glDisable(GL_BLEND);
		}
	}
	if (s.components & kSMK_GL_StateBlendFunc) {
		glBlendFunc(s.blendSrc, s.blendDst);
		glBlendColor(s.blendColor[0], s.blendColor[1], s.blendColor[2], s.blendColor[3]);
	}
	if (s.components & kSMK_GL_StateCullEnable) {
		if (s.cullFace == GL_TRUE) {
			glEnable(GL_CULL_FACE);
		}
		else {
			glDisable(GL_CULL_FACE);
		}
	}
	if (s.components & kSMK_GL_StateCullFace) {
		glCullFace(s.cullFaceMode);
	}
	[_stateStorage setLength:[_stateStorage length] - sizeof(s)];
}

- (void)pushStateComponents:(NSInteger)aComponents
{
	SMK_GL_SavedState s;
	memset(&s, 0, sizeof(s));
	s.components = (int)aComponents;
	if (aComponents & kSMK_GL_StateColor) {
		memcpy(&s.color, [self color], sizeof(s.color));
	}
	if (aComponents & kSMK_GL_StateBlendEnable) {
		glGetBooleanv(GL_BLEND, &s.blend);
	}
	if (aComponents & kSMK_GL_StateBlendFunc) {
		glGetFloatv(GL_BLEND_COLOR, s.blendColor);
		glGetIntegerv(GL_BLEND_DST, &s.blendDst);
		glGetIntegerv(GL_BLEND_SRC, &s.blendSrc);
	}
	if (aComponents & kSMK_GL_StateCullEnable) {
		glGetBooleanv(GL_CULL_FACE, &s.cullFace);
	}
	if (aComponents & kSMK_GL_StateCullFace) {
		glGetIntegerv(GL_CULL_FACE_MODE, &s.cullFaceMode);
	}
	[_stateStorage appendBytes:&s length:sizeof(s)];
}

- (void)drawNonIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount
{
	[self _bindBuffersBeforeDraw];
	[_currentVertBuffer startDrawing];
	[_currentVertBuffer drawNonIndexedInMode:aMode first:aFirst count:aCount];
	[_currentVertBuffer stopDrawing];
}

- (void)drawIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount
{
	[self _bindBuffersBeforeDraw];
	[_currentVertBuffer startDrawing];
	[_currentIndBuffer startDrawing];
	[_currentIndBuffer drawInMode:aMode first:aFirst count:aCount];
	[_currentIndBuffer stopDrawing];
	[_currentVertBuffer stopDrawing];
}

- (void)_bindBuffersBeforeDraw
{
	if (_currentVertBuffer == _prevUsedVertBuffer) {
		if ([_currentVertBuffer isDirty]) {
			[_currentVertBuffer rebind];
		}
	}
	else {
		[_prevUsedVertBuffer unbind];
		[_currentVertBuffer bind];
		_prevUsedVertBuffer = _currentVertBuffer;
	}
	if (_currentIndBuffer == _prevUsedIndBuffer) {
		if ([_currentIndBuffer isDirty]) {
			[_currentIndBuffer rebind];
		}
	}
	else {
		[_prevUsedIndBuffer unbind];
		[_currentIndBuffer bind];
		_prevUsedIndBuffer = _currentIndBuffer;
	}
}

- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2 backColor:(const SMK_GL_Color *)aColor
{
	[[self currentFont] drawString:aString inRect:aRect hAlignment:aAlignment vAlignment:aAlignment2
		fontColor:&_color backColor:aColor];
}

- (void)drawString:(id)aString atPosition:(NSPoint)aPosition backColor:(const SMK_GL_Color *)aColor
{
	[[self currentFont] drawString:aString atPoint:aPosition fontColor:&_color backColor:aColor];
}

- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2
{
	[self drawString:aString inRect:aRect hAlignment:aAlignment vAlignment:aAlignment2 backColor:NULL];
}

- (void)drawString:(id)aString atPosition:(NSPoint)aPosition
{
	[self drawString:aString atPosition:aPosition backColor:NULL];
}

- (void)setFont:(id)aFont
{
	[aFont retain];
	[_currentFont release];
	_currentFont = aFont;
}

- (id)currentFont
{
	if (_currentFont == nil) {
		_currentFont = [[self defaultFont] retain];
	}
	return _currentFont;
}

- (id)defaultFont
{
	if (_defaultFont == nil) {
		[_container beginAccumulationBlock];
		_defaultFont = [[SMK_GL_Font alloc] initWithContainer:_container
			font:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		[_container endAccumulationBlock];
	}
	return _defaultFont;
}

- (SMK_GL_Color *)color
{
	return &_color;
}

- (void)setColor:(const SMK_GL_Color *)aColor
{
	_color = *aColor;
}

- (void)drawTexture0:(id)aTexture0 texture1:(id)aTexture1 inRect:(NSRect)aRect
{
	[self _create2DMeshIfNeeded];
	[[_2DMesh material] setTexture:aTexture0 atStage:0];
	[[_2DMesh material] setTexture:aTexture1 atStage:1];
	[self _draw2DInRect:aRect];
}

- (void)drawTexture:(id)aTexture inRect:(NSRect)aRect
{
	[self _create2DMeshIfNeeded];
	[[_2DMesh material] setTexture:aTexture atStage:0];
	[[_2DMesh material] setTexture:nil atStage:1];
	[self _draw2DInRect:aRect];
}

// The 2D mesh is a unit square; this scales and moves it onto the rect.
- (void)_draw2DInRect:(NSRect)aRect
{
	GLfloat m[16];
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	matrix_make_identity((SMK_GL_Matrix *)m);
	m[0] = aRect.size.width;
	m[5] = aRect.size.height;
	m[12] = aRect.origin.x;
	m[13] = aRect.origin.y;
	glMultMatrixf(m);
	[[_2DMesh material] setAmbient:_color];
	[_2DMesh drawInContext:self];
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}

- (BOOL)isIn2DMode
{
	return _isIn2DMode;
}

- (void)exit2DMode
{
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	if (_depthWasEnabledBefore2D) {
		glEnable(GL_DEPTH_TEST);
	}
	glDisable(GL_BLEND);
	[self turnOnLighting];
	_isIn2DMode = NO;
}

- (void)enter2DMode
{
	glGetBooleanv(GL_DEPTH_TEST, &_depthWasEnabledBefore2D);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	if (_depthWasEnabledBefore2D) {
		glDisable(GL_DEPTH_TEST);
	}
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[self turnOffLighting];
	glDisable(GL_CULL_FACE);
	_isIn2DMode = YES;
}

- (void)_create2DMeshIfNeeded
{
	if (_2DMesh != nil) {
		return;
	}
	[_container beginAccumulationBlock];
	_2DMesh = [[SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(0, 0, 1, 1) xSegments:1 ySegments:1
		container:_container fvf:0x202 usage:0] retain];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[material setAmbient:(SMK_GL_Color){ 1, 1, 1, 1 }];
	[material setDiffuse:(SMK_GL_Color){ 1, 1, 1, 1 }];
	[_2DMesh setMaterial:material];
	[_container endAccumulationBlock];
}

- (void)turnOnLighting
{
	if (_lightsCount > 0) {
		glEnable(GL_LIGHTING);
	}
}

- (void)turnOffLighting
{
	if (_lightsCount > 0) {
		glDisable(GL_LIGHTING);
	}
}

- (void)deactivateLight:(id)aLight
{
	for (int i = 0; i < 8; i++) {
		if (_activeLights[i] == aLight) {
			glDisable(GL_LIGHT0 + i);
			[_activeLights[i] disableInContext:self withIndex:i];
			[_activeLights[i] release];
			_activeLights[i] = nil;
			if (--_lightsCount <= 0) {
				glDisable(GL_LIGHTING);
			}
			return;
		}
	}
}

- (void)activateLight:(id)aLight
{
	for (int i = 0; i < 8; i++) {
		if (_activeLights[i] == nil) {
			_activeLights[i] = [aLight retain];
			[aLight enableInContext:self withIndex:i];
			if (_lightsCount++ <= 0) {
				glEnable(GL_LIGHTING);
			}
			return;
		}
	}
}

- (void)resetAllLights
{
	if (_lightsCount == 0) {
		return;
	}
	for (int i = 0; i < 8; i++) {
		if (_activeLights[i] != nil) {
			[_activeLights[i] disableInContext:self withIndex:i];
			[_activeLights[i] release];
			_activeLights[i] = nil;
		}
	}
	glDisable(GL_LIGHTING);
	_lightsCount = 0;
}

- (void)resetAllTextures
{
	for (int i = 0; i < _textureUnitsCount; i++) {
		if (_currentTextures[i] != nil) {
			[_currentTextures[i] unbindAtStage:i];
			[_currentTextures[i] release];
			_currentTextures[i] = nil;
		}
	}
}

- (void)setTexture:(id)aTexture atStage:(NSInteger)aStage
{
	NSAssert(aStage >= 0 && aStage < _textureUnitsCount,
		@"texture stage index is invalid during setTexture call");
	if (aTexture == _currentTextures[aStage] && ![aTexture isDirty]) {
		return;
	}
	[aTexture retain];
	[_currentTextures[aStage] unbindAtStage:aStage];
	[_currentTextures[aStage] release];
	[aTexture bindAtStage:aStage];
	_currentTextures[aStage] = aTexture;
}

- (void)setAllTextures:(id *)aTextures
{
	for (int i = 0; i < _textureUnitsCount; i++) {
		[self setTexture:aTextures[i] atStage:i];
	}
}

- (NSInteger)textureUnitsCount
{
	return _textureUnitsCount;
}

- (void)_bufferWillDie:(id)aDie
{
	if (_currentVertBuffer == aDie) {
		_currentVertBuffer = nil;
	}
	if (_currentIndBuffer == aDie) {
		_currentIndBuffer = nil;
	}
	if (_prevUsedVertBuffer == aDie) {
		_prevUsedVertBuffer = nil;
	}
	if (_prevUsedIndBuffer == aDie) {
		_prevUsedIndBuffer = nil;
	}
}

- (void)_resetAllBondBuffers
{
	[_prevUsedVertBuffer unbind];
	_prevUsedVertBuffer = nil;
	_currentVertBuffer = nil;
	[_prevUsedIndBuffer unbind];
	_prevUsedIndBuffer = nil;
	_currentIndBuffer = nil;
}

- (void)setIndexBuffer:(id)aBuffer
{
	_currentIndBuffer = aBuffer;
}

- (void)setVertexBuffer:(id)aBuffer
{
	_currentVertBuffer = aBuffer;
}

- (void)setMaterial:(id)aMaterial
{
	if (_currentMaterial == aMaterial && ![aMaterial isDirty]) {
		return;
	}
	[aMaterial retain];
	[_currentMaterial unbind];
	[_currentMaterial release];
	[aMaterial bind];
	_currentMaterial = aMaterial;
}

- (BOOL)setRenderTarget:(id)aTarget
{
	[_renderTarget deactivateInContext:self];
	if ([aTarget activateAsRenderTargetInContext:self]) {
		[aTarget retain];
		[_renderTarget release];
		_renderTarget = aTarget;
		return YES;
	}
	[_renderTarget release];
	_renderTarget = nil;
	return NO;
}

- (id)renderTarget
{
	return _renderTarget;
}

- (void)evaluateFrustumForCamera:(id)aCamera forSize:(NSSize)aSize
{
	_size = aSize;
	[aCamera evaluateViewFrustum:&_frustum forSize:aSize];
}

- (SMK_GL_Frustum *)viewFrustum
{
	return &_frustum;
}

- (void)setClearColor:(SMK_GL_Color)aColor
{
	_clearColor = aColor;
}

- (SMK_GL_Color)clearColor
{
	return _clearColor;
}

- (NSSize)size
{
	return [[_nsContext view] bounds].size;
}

- (id)creationThread
{
	return _creationThread;
}

- (id)objectsContainer
{
	return _container;
}

- (void)makeCurrent
{
	[_nsContext makeCurrentContext];
}

- (BOOL)pixelBuffers
{
	return _pixelBuffers;
}

- (BOOL)textureLodSGIS
{
	return _textureLodSGIS;
}

- (BOOL)generateMipmapSGIS
{
	return _generateMipmapSGIS;
}

- (BOOL)vertexShaderARB
{
	return _vertexShaderARB;
}

- (BOOL)fragmentShaderARB
{
	return _fragmentShaderARB;
}

- (BOOL)vertexProgramARB
{
	return _vertexProgramARB;
}

- (BOOL)fragmentProgramARB
{
	return _fragmentProgramARB;
}

- (BOOL)elementArrayAPPLE
{
	return _elementArrayAPPLE && _vertexArrayRangeAPPLE;
}

- (BOOL)drawRangeElementsEXT
{
	return _drawRangeElementsEXT;
}

- (BOOL)vertexBufferObjectARB
{
	return _vertexBufferObjectARB;
}

- (BOOL)vertexArrayRangeAPPLE
{
	return _vertexArrayRangeAPPLE;
}

- (BOOL)textureRangeAPPLE
{
	return _textureRangeAPPLE;
}

- (BOOL)textureRectangleEXT
{
	return _textureRectangleEXT;
}

- (BOOL)textureDot3ARB
{
	return _textureDot3ARB;
}

- (BOOL)textureCombineARB
{
	return _textureCombineARB;
}

// Vertex array range (APPLE_vertex_array_range) storage: one block of memory,
// handed out in ranges with a free list.

- (void *)_currentPointerVAR
{
	return [_VAR mutableBytes];
}

- (void)_flushVAR:(NSRange)aVAR
{
	if (NSIntersectionRange(_flushRangesInVAR, aVAR).length != 0) {
		glFlushVertexArrayRangeAPPLE((GLsizei)_flushRangesInVAR.length,
			(char *)[_VAR mutableBytes] + _flushRangesInVAR.location);
		_flushRangesInVAR = NSMakeRange(NSNotFound, 0);
	}
}

- (void)_accumulateFlushVAR:(NSRange)aVAR
{
	if (_flushRangesInVAR.length == 0) {
		_flushRangesInVAR = aVAR;
	}
	else {
		_flushRangesInVAR = NSUnionRange(_flushRangesInVAR, aVAR);
	}
}

- (void)_deallocateVAR:(NSRange)aVAR
{
	[_freeRangesInVAR addObject:[NSValue valueWithRange:aVAR]];
}

- (NSRange)_allocateVAR:(NSUInteger)aVAR
{
	// the smallest free range that fits
	NSUInteger count = [_freeRangesInVAR count];
	NSUInteger best = NSNotFound;
	NSRange bestRange = NSMakeRange(0, 0);
	for (NSUInteger i = 0; i < count; i++) {
		NSRange r = [[_freeRangesInVAR objectAtIndex:i] rangeValue];
		if (aVAR <= r.length && (r.length < bestRange.length || bestRange.length == 0)) {
			best = i;
			bestRange = r;
		}
	}
	if (best != NSNotFound) {
		[_freeRangesInVAR removeObjectAtIndex:best];
		return bestRange;
	}
	// otherwise grow the block, reusing a free range at its end
	NSUInteger location;
	NSValue *last = [_freeRangesInVAR lastObject];
	NSRange lastRange = last != nil ? [last rangeValue] : NSMakeRange(0, 0);
	if (last != nil && NSMaxRange(lastRange) == [_VAR length]) {
		[_freeRangesInVAR removeLastObject];
		location = lastRange.location;
		[_VAR increaseLengthBy:aVAR - lastRange.length];
	}
	else {
		location = [_VAR length];
		[_VAR increaseLengthBy:aVAR];
	}
	glVertexArrayRangeAPPLE((GLsizei)[_VAR length], [_VAR mutableBytes]);
	return NSMakeRange(location, aVAR);
}

- (void)dealloc
{
	[self makeCurrent];
	[self resetAllLights];
	[self resetAllTextures];
	[_currentVertBuffer unbind];
	_currentVertBuffer = nil;
	[_currentIndBuffer unbind];
	_currentIndBuffer = nil;
	[_currentMaterial unbind];
	[_currentMaterial release];
	_currentMaterial = nil;
	[_2DMesh release];
	[_currentFont release];
	[_defaultFont release];
	[_stateStorage release];
	if (_vertexArrayRangeAPPLE) {
		glVertexArrayRangeAPPLE(0, NULL);
		[_freeRangesInVAR release];
		[_VAR release];
	}
	[super dealloc];
}

- (id)glView
{
	return _view;
}

- (id)systemContext
{
	return _nsContext;
}

- (id)initWithContainer:(id)aContainer systemContext:(id)aContext view:(id)aView
{
	self = [super init];
	if (self == nil) {
		return nil;
	}
	_container = aContainer;
	_nsContext = aContext;
	_view = aView;
	_clearColor = (SMK_GL_Color){ 0.2f, 0.2f, 0.2f, 0.0f };
	_color = (SMK_GL_Color){ 1.0f, 1.0f, 1.0f, 1.0f };
	_creationThread = [NSThread currentThread];
	_stateStorage = [[NSMutableData alloc] initWithCapacity:20 * sizeof(SMK_GL_SavedState)];
	if (aContext != nil) {
		[self makeCurrent];
		glGetIntegerv(GL_MAX_TEXTURE_UNITS, &_textureUnitsCount);
		if (_textureUnitsCount > 16) {
			_textureUnitsCount = 16;
		}
		const GLubyte *ext = glGetString(GL_EXTENSIONS);
		_textureCombineARB = gluCheckExtension((const GLubyte *)"GL_ARB_texture_env_combine", ext);
		_textureDot3ARB = gluCheckExtension((const GLubyte *)"GL_ARB_texture_env_dot3", ext);
		_textureRectangleEXT = [SMK_GL_Config rectangleIsEnabled] &&
			gluCheckExtension((const GLubyte *)"GL_EXT_texture_rectangle", ext);
		_textureRangeAPPLE = [SMK_GL_Config textureRangeIsEnabled] &&
			gluCheckExtension((const GLubyte *)"GL_APPLE_texture_range", ext);
		_vertexArrayRangeAPPLE = [SMK_GL_Config vertexArrayRangeIsEnabled] &&
			gluCheckExtension((const GLubyte *)"GL_APPLE_vertex_array_range", ext);
		_elementArrayAPPLE = gluCheckExtension((const GLubyte *)"GL_APPLE_element_array", ext);
		_drawRangeElementsEXT = gluCheckExtension((const GLubyte *)"GL_EXT_draw_range_elements", ext);
		_vertexBufferObjectARB = [SMK_GL_Config vertexBufferObjectIsEnabled] &&
			gluCheckExtension((const GLubyte *)"GL_ARB_vertex_buffer_object", ext);
		_fragmentProgramARB = gluCheckExtension((const GLubyte *)"GL_ARB_fragment_program", ext);
		_vertexProgramARB = gluCheckExtension((const GLubyte *)"GL_ARB_vertex_program", ext);
		_fragmentShaderARB = gluCheckExtension((const GLubyte *)"GL_ARB_fragment_shader", ext);
		_vertexShaderARB = gluCheckExtension((const GLubyte *)"GL_ARB_vertex_shader", ext);
		_generateMipmapSGIS = gluCheckExtension((const GLubyte *)"GL_SGIS_generate_mipmap", ext);
		_textureLodSGIS = gluCheckExtension((const GLubyte *)"GL_SGIS_texture_lod", ext);
		_pixelBuffers = gluCheckExtension((const GLubyte *)"GL_APPLE_pixel_buffer", ext);
		if (_vertexArrayRangeAPPLE) {
			_VAR = [[NSMutableData alloc] initWithCapacity:0x100000];
			_freeRangesInVAR = [[NSMutableArray alloc] initWithCapacity:100];
		}
	}
	return self;
}

@end
