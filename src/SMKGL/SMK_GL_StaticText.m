// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_StaticText.m
#import "SMK_GL_StaticText.h"

// Many short captions drawn with one font as one vertex buffer. Captions are
// recorded between beginRecordBlock and endRecordBlock; the buffer is rebuilt
// when the view size or a caption position changes. An optional layouter can
// move the captions around.
@implementation SMK_GL_StaticText

- (void)drawInContext:(id)aContext foreColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2
{
	if (_vertexBuffer == nil || _indexBuffer == nil) {
		return;
	}
	NSSize size = [aContext size];
	if ((!_recordBlockIsActive && !NSEqualSizes(_prevContextSize, size)) || _dataIsDraft) {
		_prevContextSize = size;
		[self _recalcBuffersForContextSize:size];
	}
	if ([_layouter haveNewLayout]) {
		NSInteger count = (NSInteger)[self captionsCount];
		for (NSInteger i = 0; i < count; i++) {
			NSPoint p = [_layouter basePointInRectForCaptionAtIndex:i];
			SMK_GL_Vec2 position = { (float)p.x, (float)p.y };
			[self _setNewPosition:&position forCaptionAtIndex:i];
		}
	}
	[aContext setVertexBuffer:_vertexBuffer];
	[aContext setIndexBuffer:_indexBuffer];
	[aContext setMaterial:_material];
	BOOL was2D = [aContext isIn2DMode];
	if (!was2D) {
		[aContext enter2DMode];
	}
	[aContext pushStateComponents:kSMK_GL_StateColor | kSMK_GL_StateBlendEnable | kSMK_GL_StateBlendFunc];
	glEnable(GL_BLEND);
	SMK_GL_Matrix m;
	matrix_make_identity(&m);
	m._14 = _translationVec.x;
	m._24 = _translationVec.y;
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glMultTransposeMatrixfARB(&m._11);
	[_font bindTextureWithForeColor:aColor backColor:aColor2];
	[aContext drawIndexedInMode:GL_TRIANGLES first:0 count:_primitivesCount * 3];
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	[aContext popState];
	if (!was2D) {
		[aContext exit2DMode];
	}
}

- (void)_setNewPosition:(const SMK_GL_Vec2 *)aPosition forCaptionAtIndex:(NSUInteger)aIndex
{
	[_captionPositions replaceBytesInRange:NSMakeRange(aIndex * sizeof(SMK_GL_Vec2), sizeof(SMK_GL_Vec2))
		withBytes:aPosition];
	_dataIsDraft = YES;
}

// Lays every caption's characters out from its position, in 2D mode units.
- (void)_recalcBuffersForContextSize:(NSSize)aSize
{
	if (_charactersCount == 0) {
		return;
	}
	_primitivesCount = _charactersCount * 2;
	const SMK_GL_Vec2 *position = [_captionPositions bytes];
	NSInteger remaining = (NSInteger)([_captionPositions length] / sizeof(SMK_GL_Vec2));
	const unsigned char *p = [_captions bytes];
	float xScale = 2.0f / (float)aSize.width;
	float yScale = 2.0f / (float)aSize.height;
	float maxHeight = (float)[_font maxHeight];
	float baseX = position->x;
	float baseY = position->y;
	float x = _scaleVec.x * baseX;
	float y = _scaleVec.y * baseY;
	float *v = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
	for (int i = 0; i < _charactersCount; i++) {
		unsigned char c;
		for (;;) {
			c = *p++;
			if (c == 0) {
				// next caption
				if (remaining < 1) {
					goto done;
				}
				position++;
				remaining--;
				baseX = position->x;
				baseY = position->y;
				x = baseX * _scaleVec.x;
				y = baseY * _scaleVec.y;
			}
			else if (c == '\r' || c == '\n') {
				// the original keeps the scaled position as the new base
				x = baseX * _scaleVec.x;
				y = baseY * _scaleVec.y + maxHeight * 1.4f * yScale;
				baseX = x;
				baseY = y;
			}
			else {
				break;
			}
		}
		if (remaining < 1) {
			break;
		}
		NSSize size = *[_font sizeOfCharacter:c];
		const SMK_GL_Vec2 *coords = [_font textureCoordinatesForCharacter:c];
		float top = (float)size.height * yScale + y;
		float right = x + (float)size.width * xScale;
		// bottom left, top left, bottom right, top right
		float corners[4][2] = { { x, y }, { x, top }, { right, y }, { right, top } };
		const SMK_GL_Vec2 *tex[4] = { &coords[0], &coords[3], &coords[1], &coords[2] };
		for (int k = 0; k < 4; k++) {
			v[0] = corners[k][0];
			v[1] = corners[k][1];
			v[2] = 0.0f;
			v[3] = tex[k]->x;
			v[4] = tex[k]->y;
			v[5] = tex[k]->x;
			v[6] = tex[k]->y;
			v += 7;
		}
		x = right;
	}
done:
	[_vertexBuffer unlock];
	_dataIsDraft = NO;
}

- (void)setScale:(const SMK_GL_Vec2 *)aScale
{
	_prevContextSize = NSZeroSize;
	_scaleVec = *aScale;
}

- (void)setTranslation:(const SMK_GL_Vec2 *)aTranslation
{
	_translationVec = *aTranslation;
}

- (void)setLayouter:(id)aLayouter
{
	[aLayouter retain];
	[_layouter release];
	_layouter = aLayouter;
}

- (id)layouter
{
	return _layouter;
}

- (void)setNewPosition:(const SMK_GL_Vec2 *)aPosition forCaption:(id)aCaption
{
	[_layouter setNewPosition:aPosition forCaptionAtIndex:[aCaption index]];
}

- (NSUInteger)captionsCount
{
	return [_captionPositions length] / sizeof(SMK_GL_Vec2);
}

- (void)endRecordBlock
{
	if (_numChars > 0x7fff) {
		_numChars = 0x7fff;
	}
	_charactersCount = _numChars;
	_recordBlockIsActive = NO;
	_prevContextSize = NSZeroSize;
	[_layouter endRecordBlock];
	if (_numChars == 0) {
		return;
	}
	[_container beginAccumulationBlock];
	NSInteger usage = _charactersCount > 0x80 ? kSMK_GL_UsageDynamic : kSMK_GL_UsageSystemMemory | kSMK_GL_UsageDynamic;
	_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:_container count:_charactersCount * 4
		usage:usage fvf:kSMK_GL_FVF_Position | SMK_GL_FVF_TEXCOORDS(2)];
	_indexBuffer = [[SMK_GL_IndexBuffer alloc] initWithContainer:_container count:_charactersCount * 6
		usage:kSMK_GL_UsageStatic];
	void *indices = [_indexBuffer lock:kSMK_GL_LockWriteOnly];
	BOOL wide = [_indexBuffer are32BitIndices];
	for (unsigned int i = 0, k = 0; i < (unsigned int)_charactersCount; i++) {
		unsigned int b = i * 4;
		unsigned int quad[6] = { b, b + 3, b + 2, b, b + 1, b + 3 };
		for (int j = 0; j < 6; j++, k++) {
			if (wide) {
				((GLuint *)indices)[k] = quad[j];
			}
			else {
				((GLushort *)indices)[k] = (GLushort)quad[j];
			}
		}
	}
	[_indexBuffer unlock];
	[_container endAccumulationBlock];
}

// Appends a caption; its size in font units goes to aSize and the layouter.
- (id)recordCaption:(id)aCaption atPosition:(const SMK_GL_Vec2 *)aPosition outCaptionSize:(NSSize *)aSize
{
	NSAssert(_captions != nil && _captionPositions != nil, @"'beginRecordBlock' was not called before 'recordCaption'");
	NSData *data = [aCaption dataUsingEncoding:NSMacOSRomanStringEncoding];
	[_captions appendData:data];
	NSUInteger length = [data length];
	_numChars += (int)length;
	unsigned char terminator = 0;
	[_captions appendBytes:&terminator length:1];
	[_captionPositions appendBytes:aPosition length:sizeof(SMK_GL_Vec2)];
	NSSize localSize;
	if (aSize == NULL && _layouter != nil) {
		aSize = &localSize;
	}
	if (aSize != NULL) {
		const unsigned char *bytes = [data bytes];
		float maxHeight = (float)[_font maxHeight];
		aSize->width = 0.0;
		aSize->height = maxHeight;
		float width = 0.0f;
		for (NSUInteger i = 0; i < length && bytes[i] != 0; i++) {
			unsigned char c = bytes[i];
			if (c == '\r' || c == '\n') {
				aSize->height = maxHeight + maxHeight * 0.39999998f + (float)aSize->height;
				if (aSize->width < width) {
					aSize->width = width;
				}
				width = 0.0f;
			}
			else {
				width += (float)[_font sizeOfCharacter:c]->width;
			}
		}
		if (aSize->width < width) {
			aSize->width = width;
		}
		if (_layouter != nil) {
			[_layouter recordCaptionWithSize:*aSize atPosition:NSMakePoint(aPosition->x, aPosition->y)];
		}
	}
	return [SMK_GL_StaticTextCaptionID captionIDWithIndex:[_captionPositions length] / sizeof(SMK_GL_Vec2) - 1];
}

- (id)recordCaption:(id)aCaption atPosition:(const SMK_GL_Vec2 *)aPosition
{
	return [self recordCaption:aCaption atPosition:aPosition outCaptionSize:NULL];
}

- (void)beginRecordBlockWithLayouterOptions:(NSInteger)aOptions
{
	[_vertexBuffer release];
	[_indexBuffer release];
	[_captionPositions release];
	[_captions release];
	_captionPositions = [NSMutableData new];
	_captions = [NSMutableData new];
	_vertexBuffer = nil;
	_indexBuffer = nil;
	_numChars = 0;
	_recordBlockIsActive = YES;
	[_layouter beginRecordBlockWithFlag:aOptions];
}

- (id)glFont
{
	return _font;
}

- (void)dealloc
{
	[_font release];
	[_vertexBuffer release];
	[_indexBuffer release];
	[_material release];
	[_captionPositions release];
	[_captions release];
	[_layouter release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer glFont:(id)aFont
{
	self = [super init];
	if (self != nil) {
		_container = aContainer;
		_font = [aFont retain];
		_scaleVec = (SMK_GL_Vec2){ 1.0f, 1.0f };
		_material = [[SMK_GL_Material alloc] initWithContainer:aContainer];
		[_material setAmbient:(SMK_GL_Color){ 1.0f, 1.0f, 1.0f, 1.0f }];
		[_material setDiffuse:(SMK_GL_Color){ 0.0f, 0.0f, 0.0f, 0.0f }];
	}
	return self;
}

@end

// identifies a recorded caption; can carry an object for the caller
@implementation SMK_GL_StaticTextCaptionID

+ (id)captionIDWithIndex:(NSUInteger)aIndex
{
	SMK_GL_StaticTextCaptionID *captionID = [[self alloc] init];
	if (captionID != nil) {
		captionID->_index = (unsigned int)aIndex;
	}
	return [captionID autorelease];
}

- (void)attachObject:(id)aObject
{
	[aObject retain];
	[_object release];
	_object = aObject;
}

- (id)attachedObject
{
	return _object;
}

- (NSUInteger)index
{
	return _index;
}

- (void)dealloc
{
	[_object release];
	[super dealloc];
}

@end
