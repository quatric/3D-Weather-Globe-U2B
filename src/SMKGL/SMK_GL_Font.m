// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Font.m
#import "SMK_GL_Font.h"

// Characters 0x20..0xfe (Mac Roman) are rendered into one texture. Per
// character the font keeps its 2D size and the four texture corners.
#define SMK_GL_FONT_FIRST_CHAR 0x20
#define SMK_GL_FONT_CHAR_COUNT 223

static NSSize _zeroSize = { 0.0, 0.0 };
static SMK_GL_Vec2 _zeroVec[4];

@implementation SMK_GL_Font

+ (id)glFontWithContainer:(id)aContainer font:(id)aFont
{
	return [[[SMK_GL_Font alloc] initWithContainer:aContainer font:aFont] autorelease];
}

- (id)cocoaFont
{
	return _font;
}

- (void)contextWillBeDetached
{
	[super contextWillBeDetached];
	[_texture contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	[super contextWasAttached:aAttached];
	[_texture contextWasAttached:aAttached];
}

- (void)dealloc
{
	[_font release];
	[_fontAttrDictionary release];
	[_indexBuffer release];
	[_vertexBuffer release];
	[_texture contextWillBeDetached];
	[_texture release];
	[_glyphsSourceString release];
	_indexBuffer = nil;
	_vertexBuffer = nil;
	_texture = nil;
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer font:(id)aFont
{
	self = [super initWithContainer:aContainer];
	if (self == nil) {
		return nil;
	}
	_font = [aFont retain];
	[self _generateGlyphs];
	matrix_make_identity(&_fontOutlineTranslateMatrix);
	_positionVerexBuffer[0] = (SMK_GL_Vec3){ 0.0f, 0.0f, 0.0f };
	_positionVerexBuffer[1] = (SMK_GL_Vec3){ 1.0f, 0.0f, 0.0f };
	_positionVerexBuffer[2] = (SMK_GL_Vec3){ 1.0f, 1.0f, 0.0f };
	_positionVerexBuffer[3] = (SMK_GL_Vec3){ 0.0f, 1.0f, 0.0f };

	// 128 quads, two triangles each
	_indexBuffer = [[SMK_GL_IndexBuffer alloc] initWithContainer:_container count:0x300 usage:kSMK_GL_UsageDynamic];
	void *indices = [_indexBuffer lock:kSMK_GL_LockWriteOnly];
	BOOL wide = [_indexBuffer are32BitIndices];
	for (unsigned int v = 0, k = 0; v < 0x200; v += 4) {
		unsigned int quad[6] = { v, v + 1, v + 3, v + 1, v + 2, v + 3 };
		for (int i = 0; i < 6; i++, k++) {
			if (wide) {
				((GLuint *)indices)[k] = quad[i];
			}
			else {
				((GLushort *)indices)[k] = (GLushort)quad[i];
			}
		}
	}
	[_indexBuffer unlock];

	_vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:_container count:0x200
		usage:kSMK_GL_UsageSystemMemory | kSMK_GL_UsageDynamic
		fvf:kSMK_GL_FVF_Position | SMK_GL_FVF_TEXCOORDS(2)];
	void *vertices = [_vertexBuffer lock:kSMK_GL_LockWriteOnly];
	memset(vertices, 0, [_vertexBuffer length]);
	[_vertexBuffer unlock];
	[self _createAndFillTexture];
	return self;
}

// The original laid the alphabet out with NSLayoutManager and the font's
// glyph generator; Core Text maps the Mac Roman characters directly.
- (void)_generateGlyphs
{
	unichar chars[SMK_GL_FONT_CHAR_COUNT];
	CGGlyph glyphs[SMK_GL_FONT_CHAR_COUNT];
	// the alphabet string runs one character past the texture's (it ends at
	// 0xff); like the original, only the first SMK_GL_FONT_CHAR_COUNT are used
	NSString *alphabet = [[self attributedString] string];
	if ([alphabet length] < SMK_GL_FONT_CHAR_COUNT) {
		return;
	}
	[alphabet getCharacters:chars range:NSMakeRange(0, SMK_GL_FONT_CHAR_COUNT)];
	CTFontGetGlyphsForCharacters((CTFontRef)_font, chars, glyphs, SMK_GL_FONT_CHAR_COUNT);
	for (int i = 0; i < SMK_GL_FONT_CHAR_COUNT; i++) {
		_glyphs[i] = glyphs[i];
	}
	_useGlyphs = YES;
}

@end

@implementation SMK_GL_Font (SMK_GL_ExtendedFont)

- (NSSize *)sizeOfCharacter:(unsigned char)aCharacter
{
	if (aCharacter < SMK_GL_FONT_FIRST_CHAR) {
		return &_zeroSize;
	}
	return &_characterSizesIn2DMode[aCharacter - SMK_GL_FONT_FIRST_CHAR];
}

- (SMK_GL_Vec2 *)textureCoordinatesForCharacter:(unsigned char)aCharacter
{
	if (aCharacter < SMK_GL_FONT_FIRST_CHAR) {
		return _zeroVec;
	}
	return _texturesCharactersCoordinates[aCharacter - SMK_GL_FONT_FIRST_CHAR];
}

- (CGFloat)maxHeight
{
	return _maxHeight;
}

// Without a back color the text is the texture alpha in the fore color. With
// one, stage 0 draws the glyphs shifted one way in the back color and stage 1
// adds them shifted the other way in the fore color, which outlines them.
- (void)bindTextureWithForeColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2
{
	if (aColor2 == NULL) {
		[_texture setCombinerMode:GL_MODULATE];
		[_texture setCombinerRGBArg0:GL_PRIMARY_COLOR arg1:GL_TEXTURE arg2:GL_PREVIOUS];
		[_texture setCombinerAlphaMode:GL_REPLACE];
		[_texture setCombinerAlphaArg0:GL_TEXTURE arg1:GL_PREVIOUS arg2:GL_PREVIOUS];
		[_context setTexture:_texture atStage:0];
		[_context setTexture:nil atStage:1];
	}
	else {
		float offset = -((_fontScale * 0.6f) / (float)_textureWidth);
		_fontOutlineTranslateMatrix._14 = offset;
		_fontOutlineTranslateMatrix._24 = offset;
		[_texture setTransformMatrix:&_fontOutlineTranslateMatrix];
		[_texture setCombinerMode:GL_MODULATE];
		[_texture setCombinerAlphaMode:GL_REPLACE];
		[_texture setCombinerRGBArg0:GL_CONSTANT arg1:GL_TEXTURE arg2:GL_PREVIOUS];
		[_texture setCombinerAlphaArg0:GL_TEXTURE arg1:GL_PREVIOUS arg2:GL_PREVIOUS];
		[_texture setConstantColor:*aColor2];
		[_context setTexture:_texture atStage:0];
		_fontOutlineTranslateMatrix._14 = -_fontOutlineTranslateMatrix._14;
		_fontOutlineTranslateMatrix._24 = -_fontOutlineTranslateMatrix._24;
		[_texture setTransformMatrix:&_fontOutlineTranslateMatrix];
		[_texture setCombinerMode:GL_INTERPOLATE];
		[_texture setCombinerAlphaMode:GL_ADD];
		[_texture setCombinerRGBArg0:GL_PRIMARY_COLOR arg1:GL_PREVIOUS arg2:GL_TEXTURE];
		[_texture setCombinerAlphaArg0:GL_TEXTURE arg1:GL_PREVIOUS arg2:GL_PREVIOUS];
		[_context setTexture:_texture atStage:1];
	}
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	glColor4fv(&aColor->r);
}

- (id)texture
{
	return _texture;
}

@end

// NSGlyphStorage methods the original used with the glyph generator.
@implementation SMK_GL_Font (Private)

- (void)setIntAttribute:(NSInteger)aAttribute value:(NSInteger)aValue forGlyphAtIndex:(NSUInteger)aIndex
{
}

- (void)insertGlyphs:(unsigned int *)aGlyphs length:(NSUInteger)aLength forStartingGlyphAtIndex:(NSUInteger)aIndex characterIndex:(NSUInteger)aIndex2
{
	memcpy(_glyphs, aGlyphs, aLength * sizeof(unsigned int));
}

- (NSUInteger)layoutOptions
{
	return 0;
}

// the alphabet the texture holds
- (id)attributedString
{
	if (_glyphsSourceString == nil) {
		unsigned char chars[SMK_GL_FONT_CHAR_COUNT + 1];
		for (int i = 0; i <= SMK_GL_FONT_CHAR_COUNT; i++) {
			chars[i] = (unsigned char)(i + SMK_GL_FONT_FIRST_CHAR);
		}
		NSString *string = [[NSString alloc] initWithData:[NSData dataWithBytesNoCopy:chars
			length:SMK_GL_FONT_CHAR_COUNT + 1 freeWhenDone:NO] encoding:NSMacOSRomanStringEncoding];
		_glyphsSourceString = [[NSAttributedString alloc] initWithString:string
			attributes:[NSDictionary dictionaryWithObjectsAndKeys:_font, NSFontAttributeName, nil]];
		[string release];
	}
	return _glyphsSourceString;
}

// Grows the texture until the alphabet fits, then shrinks the font if the
// texture got larger than GL allows.
- (void)_createAndFillTexture
{
	_fontAttrDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:_font, NSFontAttributeName, nil];
	_fontScale = 1.0f;
	_textureHeight = 0x80;
	_textureWidth = 0x80;
	while (![self _paintAlphabetWithMeasureOnly:YES]) {
		_textureWidth <<= 1;
		_textureHeight <<= 1;
	}
	GLint maxSize;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxSize);
	if (maxSize < _textureWidth) {
		_fontScale = (float)maxSize / (float)_textureWidth;
		_textureHeight = maxSize;
		_textureWidth = maxSize;
		do {
			_fontScale *= 0.9f;
		} while (![self _paintAlphabetWithMeasureOnly:YES]);
	}
	[self _paintAlphabetWithMeasureOnly:NO];
}

- (BOOL)_paintAlphabetWithMeasureOnly:(BOOL)aOnly
{
	_oneCharSize = [@"X" sizeWithAttributes:_fontAttrDictionary];
	_spacingY = (float)_oneCharSize.height * 0.4f * _fontScale;
	_spacingX = (float)_oneCharSize.width * 0.2f * _fontScale;
	_maxHeight = 0.0f;

	int x = 0;
	int y = 0;
	int rowHeight = 0;
	float rowHeightF = 0.0f;
	for (int c = SMK_GL_FONT_FIRST_CHAR; c < 0xff; c++) {
		unsigned char ch = (unsigned char)c;
		NSString *string = [[NSString alloc] initWithData:[NSData dataWithBytesNoCopy:&ch length:1 freeWhenDone:NO]
			encoding:NSMacOSRomanStringEncoding];
		NSSize size = [string sizeWithAttributes:_fontAttrDictionary];
		[string release];
		if (_maxHeight < (float)size.height) {
			_maxHeight = (float)size.height;
		}
		float height = (float)size.height * _fontScale;
		float width = (float)size.width * _fontScale;
		float left = (float)x;
		rowHeightF = (float)rowHeight;
		if ((double)ceilf(left + width + _spacingX + _spacingX) > (double)_textureWidth) {
			// next row
			y = (int)((float)y + rowHeightF + _spacingY + _spacingY);
			if (_textureHeight < y) {
				return NO;
			}
			rowHeight = 0;
			left = 0.0f;
			rowHeightF = 0.0f;
		}
		if (!aOnly) {
			int i = c - SMK_GL_FONT_FIRST_CHAR;
			SMK_GL_Vec2 *coords = _texturesCharactersCoordinates[i];
			_characterSizesIn2DMode[i] = NSMakeSize(width, height);
			float top = (float)y;
			coords[0] = (SMK_GL_Vec2){ left, top };
			coords[1] = (SMK_GL_Vec2){ left + width + _spacingX + _spacingX, top };
			coords[2] = (SMK_GL_Vec2){ left + width + _spacingX + _spacingX, top + height + _spacingY + _spacingY };
			coords[3] = (SMK_GL_Vec2){ left, top + height + _spacingY + _spacingY };
		}
		x = (int)(left + _spacingX + _spacingX + width);
		// the original tracks the row height with the character width
		if (rowHeightF < width) {
			rowHeight = (int)width;
			rowHeightF = (float)rowHeight;
		}
	}
	if (_textureHeight < (int)((float)y + _spacingY + _spacingY + rowHeightF)) {
		return NO;
	}
	if (aOnly) {
		return YES;
	}

	[_texture release];
	_texture = [[SMK_GL_2DTexture alloc] initWithContainer:nil flags:0 usage:0 width:_textureWidth
		height:_textureHeight dataFormat:GL_RGBA8];
	CGContextRef cg = [_texture lockAndCreateCGContextWithClear:YES];
	CGContextSetTextMatrix(cg, CGAffineTransformMakeScale(_fontScale, _fontScale));
	CGFontRef cgFont = CTFontCopyGraphicsFont((CTFontRef)_font, NULL);
	CGContextSetFont(cg, cgFont);
	CGContextSetFontSize(cg, [_font pointSize]);
	CGFontRelease(cgFont);
	float descender = (float)[_font descender] * _fontScale;
	CGContextSetTextDrawingMode(cg, kCGTextFill);
	CGContextSetRGBFillColor(cg, 1.0, 1.0, 1.0, 1.0);
	float sx = 1.0f / (float)_textureWidth;
	float sy = -(1.0f / (float)_textureHeight);
	for (int i = 0; i < SMK_GL_FONT_CHAR_COUNT; i++) {
		SMK_GL_Vec2 *coords = _texturesCharactersCoordinates[i];
		CGGlyph glyph = (CGGlyph)_glyphs[i];
		CGPoint origin = CGPointZero;
		CGContextSetTextPosition(cg, _spacingX + coords[0].x, (coords[0].y - descender) + _spacingY);
		CGContextShowGlyphsAtPositions(cg, &glyph, &origin, 1);
		// pull the corners in to the glyph and convert to texture space
		coords[0].x = (_spacingX * 0.8f + coords[0].x) * sx;
		coords[0].y = (_spacingY * 0.8f + coords[0].y) * sy + 1.0f;
		coords[1].x = (_spacingX * -0.8f + coords[1].x) * sx;
		coords[1].y = (_spacingY * 0.8f + coords[1].y) * sy + 1.0f;
		coords[2].x = (_spacingX * -0.8f + coords[2].x) * sx;
		coords[2].y = (_spacingY * -0.8f + coords[2].y) * sy + 1.0f;
		coords[3].x = (_spacingX * 0.8f + coords[3].x) * sx;
		coords[3].y = (_spacingY * -0.8f + coords[3].y) * sy + 1.0f;
	}
	[_texture unlock];
	return YES;
}

@end
