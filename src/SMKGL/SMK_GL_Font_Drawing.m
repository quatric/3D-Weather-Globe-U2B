// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Font_Drawing.m
#import "SMK_GL_Font_Drawing.h"

// Text is drawn in 2D mode coordinates (-1..1) as textured quads, 128 at a
// time. A vertex is a position and two texture coordinate sets.
#define SMK_GL_FONT_VERTEX_FLOATS 7
#define SMK_GL_FONT_BATCH 0x80

// Writes one character's quad and returns the x where the next one starts.
static float _putCharQuad(float *aVertex, float aX, float aY, float aWidth, float aHeight, const SMK_GL_Vec2 *aCoords)
{
	float right = aX + aWidth;
	float top = aY + aHeight;
	float corners[4][2] = { { aX, aY }, { right, aY }, { right, top }, { aX, top } };
	for (int k = 0; k < 4; k++) {
		float *v = aVertex + k * SMK_GL_FONT_VERTEX_FLOATS;
		v[0] = corners[k][0];
		v[1] = corners[k][1];
		v[3] = aCoords[k].x;
		v[4] = aCoords[k].y;
		v[5] = aCoords[k].x;
		v[6] = aCoords[k].y;
	}
	return right;
}

@implementation SMK_GL_Font (Drawing)

// hAlignment: 0 left, 1 right, 2 center; vAlignment: 0 top, 1 center, 2 bottom
- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2 fontColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2
{
	if (aString == nil) {
		return;
	}
	NSAssert(aColor != NULL, @"fontColor can not be nil in drawString:inRect:hAlignment:vAlignment:fontColor:backColor: .");
	id context = [self context];
	NSData *data = [aString dataUsingEncoding:NSMacOSRomanStringEncoding];
	if (data == nil) {
		return;
	}
	const unsigned char *bytes = [data bytes];
	const unsigned char *end = bytes + [data length];
	[context pushStateComponents:kSMK_GL_StateColor | kSMK_GL_StateBlendEnable | kSMK_GL_StateBlendFunc];
	glEnable(GL_BLEND);
	[context setVertexBuffer:_vertexBuffer];
	[context setIndexBuffer:_indexBuffer];
	[context setTexture:nil atStage:1];
	NSSize viewSize = [context size];
	float xScale = 2.0f / (float)viewSize.width;
	float yScale = 2.0f / (float)viewSize.height;
	int lineCount;
	float maxWidth;
	[self _calculateTextDimension:data outLineCount:&lineCount outMaxWidth:&maxWidth];
	float lineHeight = yScale * (float)_oneCharSize.height;
	float x0 = (float)aRect.origin.x;
	float y0 = (float)aRect.origin.y;
	float width = (float)aRect.size.width;
	float height = (float)aRect.size.height;
	float top;
	if (aAlignment2 == 1) {
		top = (y0 + height + (height - (float)lineCount * lineHeight) * -0.5f) - lineHeight;
	}
	else if (aAlignment2 == 0) {
		top = (height + y0) - lineHeight;
	}
	else if (aAlignment2 == 2) {
		top = ((float)lineCount * lineHeight + y0) - lineHeight;
	}
	else {
		NSAssert(NO, @"Wrong vertical alignment in 'drawString:inRect:hAlignment:vAlignment:fontColor:' !");
		top = 0.0f;
	}
	[self bindTextureWithForeColor:aColor backColor:aColor2];
	float *vertex = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
	int count = 0;
	const unsigned char *line = bytes;
	while (*line != 0 && line < end) {
		float lineWidth = 0.0f;
		for (const unsigned char *p = line; *p != 0 && *p != '\n' && p != end; p++) {
			NSAssert(*p >= 0x20, @"First 32 characters only must be in this place.");
			lineWidth += (float)_characterSizesIn2DMode[*p - 0x20].width;
		}
		float x;
		if (aAlignment == 1) {
			x = (x0 + width) - lineWidth * xScale;
		}
		else if (aAlignment == 0) {
			x = x0;
		}
		else if (aAlignment == 2) {
			x = (width - lineWidth * xScale) * 0.5f + x0;
		}
		else {
			NSAssert(NO, @"Wrong horisontal alignment 'drawString: inRect: hAlignment: vAlignment: fontColor:' !");
			x = 0.0f;
		}
		const unsigned char *p = line;
		unsigned char c;
		while ((c = *p) != 0 && c != '\n' && p != end) {
			NSSize size = _characterSizesIn2DMode[c - 0x20];
			x = _putCharQuad(vertex, x, top, (float)size.width * xScale, (float)size.height * yScale,
				_texturesCharactersCoordinates[c - 0x20]);
			vertex += SMK_GL_FONT_VERTEX_FLOATS * 4;
			if (++count >= SMK_GL_FONT_BATCH) {
				[_vertexBuffer unlock];
				[context drawIndexedInMode:GL_TRIANGLES first:0 count:count * 6];
				vertex = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
				count = 0;
			}
			p++;
		}
		top -= lineHeight;
		if (c != '\n') {
			break;
		}
		line = p + 1;
	}
	[_vertexBuffer unlock];
	if (count > 0) {
		[context drawIndexedInMode:GL_TRIANGLES first:0 count:count * 6];
	}
	glDisable(GL_BLEND);
	[context popState];
}

- (void)drawString:(id)aString atPoint:(NSPoint)aPoint fontColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2
{
	if (aString == nil) {
		return;
	}
	NSAssert(aColor != NULL, @"fontColor can not be nil in drawString:atPoint:fontColor:backColor: .");
	NSData *data = [aString dataUsingEncoding:NSMacOSRomanStringEncoding];
	if (data == nil) {
		return;
	}
	const unsigned char *bytes = [data bytes];
	NSInteger length = (NSInteger)[data length];
	id context = [self context];
	[context pushStateComponents:kSMK_GL_StateColor | kSMK_GL_StateBlendEnable | kSMK_GL_StateBlendFunc];
	NSSize viewSize = [context size];
	float xScale = 2.0f / (float)viewSize.width;
	float yScale = 2.0f / (float)viewSize.height;
	float lineHeight = (float)_oneCharSize.height;
	glEnable(GL_BLEND);
	[context setVertexBuffer:_vertexBuffer];
	[context setIndexBuffer:_indexBuffer];
	[self bindTextureWithForeColor:aColor backColor:aColor2];
	float *vertex = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
	float x = (float)aPoint.x;
	float y = (float)aPoint.y;
	int count = 0;
	for (NSInteger i = 0; bytes[i] != 0 && i < length; i++) {
		unsigned char c = bytes[i];
		if (c == '\n') {
			y -= yScale * lineHeight;
			x = (float)aPoint.x;
			continue;
		}
		if (c < 0x20) {
			NSAssert(NO, @"First 32 characters except '\\n' are not supported in SMK_GL_Font.");
			continue;
		}
		NSSize size = _characterSizesIn2DMode[c - 0x20];
		x = _putCharQuad(vertex, x, y, (float)size.width * xScale, (float)size.height * yScale,
			_texturesCharactersCoordinates[c - 0x20]);
		vertex += SMK_GL_FONT_VERTEX_FLOATS * 4;
		if (++count >= SMK_GL_FONT_BATCH) {
			[_vertexBuffer unlock];
			[context drawIndexedInMode:GL_TRIANGLES first:0 count:count * 6];
			vertex = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
			count = 0;
		}
	}
	[_vertexBuffer unlock];
	if (count > 0) {
		[context drawIndexedInMode:GL_TRIANGLES first:0 count:count * 6];
	}
	glDisable(GL_BLEND);
	[context popState];
}

// the number of lines and the widest line, in font units
- (void)_calculateTextDimension:(id)aDimension outLineCount:(int *)aCount outMaxWidth:(float *)aWidth
{
	*aCount = 0;
	*aWidth = 0.0f;
	const unsigned char *p = [aDimension bytes];
	NSInteger length = (NSInteger)[aDimension length];
	if (*p == 0 || length == 0) {
		return;
	}
	*aCount = 1;
	float width = 0.0f;
	for (; *p != 0 && length > 0; p++, length--) {
		if (*p == '\n') {
			(*aCount)++;
			if (*aWidth < width) {
				*aWidth = width;
			}
			width = 0.0f;
		}
		else if (*p < 0x20) {
			NSAssert(NO, @"First 32 characters except '\\n' are not supported in SMK_GL_Font.");
		}
		else {
			width += (float)_characterSizesIn2DMode[*p - 0x20].width;
		}
	}
	if (*aWidth < width) {
		*aWidth = width;
	}
}

- (void)_drawBackgroundInContext:(id)aContext rect:(NSRect)aRect color:(const SMK_GL_Color *)aColor
{
	glPushAttrib(GL_CURRENT_BIT | GL_LIGHTING_BIT);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glColor4fv(&aColor->r);
	glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, &aColor->r);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	SMK_GL_Matrix m;
	matrix_make_identity(&m);
	m._11 = (float)aRect.size.width;
	m._22 = (float)aRect.size.height;
	m._14 = (float)aRect.origin.x;
	m._24 = (float)aRect.origin.y;
	glMultTransposeMatrixfARB(&m._11);
	[aContext setTexture:nil atStage:0];
	float *v = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
	v[0] = 0.0f;
	v[1] = 0.0f;
	v[7] = 1.0f;
	v[8] = 0.0f;
	v[14] = 1.0f;
	v[15] = 1.0f;
	v[21] = 0.0f;
	v[22] = 1.0f;
	[_vertexBuffer unlock];
	[aContext drawIndexedInMode:GL_TRIANGLES first:0 count:6];
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glPopAttrib();
}

@end
