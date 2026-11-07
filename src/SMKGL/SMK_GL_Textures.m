// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Textures.m
#import "SMK_GL_Textures.h"

static const SMK_GL_TexFormat _SMK_GL_TexFormat_A8 =
	{ 8, 1, 8, 'mask', GL_ALPHA8, GL_ALPHA4, GL_ALPHA, GL_UNSIGNED_BYTE };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_L8 =
	{ 8, 1, 8, 'luma', GL_LUMINANCE8, GL_LUMINANCE4, GL_LUMINANCE, GL_UNSIGNED_BYTE };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_I8 =
	{ 8, 1, 8, 'gray', GL_INTENSITY8, GL_INTENSITY4, GL_INTENSITY, GL_UNSIGNED_BYTE };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGBA8 =
	{ 8, 4, 32, 'rgba', GL_RGBA8, GL_RGBA4, GL_RGBA, GL_UNSIGNED_BYTE };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGBA4 =
	{ 4, 4, 16, 'rgba', GL_RGBA4, GL_RGBA4, GL_RGBA, GL_UNSIGNED_SHORT_4_4_4_4 };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGB8 =
	{ 8, 3, 24, 'rgba', GL_RGB8, GL_RGB5, GL_RGB, GL_UNSIGNED_BYTE };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_ARGB8 =
	{ 8, 4, 32, 'argb', GL_RGBA8, GL_RGBA4, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGB16 =
	{ 16, 3, 48, 'rgba', GL_RGB16, GL_RGB8, GL_RGB, GL_UNSIGNED_SHORT };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGBA16 =
	{ 16, 4, 64, 'rgba', GL_RGBA16, GL_RGBA8, GL_RGBA, GL_UNSIGNED_SHORT };
static const SMK_GL_TexFormat _SMK_GL_TexFormat_RGB5A1 =
	{ 5, 3, 16, 'rgba', GL_RGB5_A1, GL_RGB5_A1, GL_BGRA, GL_UNSIGNED_SHORT_1_5_5_5_REV };

static NSDictionary *_supportedColorSpaces;
static NSDictionary *_supportedFormats;

// Current ImageIO pads 8-bit RGB to 32 bits per pixel, which none of the
// formats above describe; this packs such a bitmap back into tight 24-bit
// rows. Takes and returns an owned reference.
static NSBitmapImageRep *packedBitmap(NSBitmapImageRep *bitmap)
{
	NSInteger width, height, stride, rowBytes, y, x;
	NSBitmapImageRep *packed;
	const unsigned char *src;
	unsigned char *dst;

	if (bitmap == nil || [bitmap isPlanar] || [bitmap samplesPerPixel] != 3 || [bitmap bitsPerSample] != 8
			|| [bitmap bitsPerPixel] == 24)
		return bitmap;
	width = [bitmap pixelsWide];
	height = [bitmap pixelsHigh];
	packed = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height
		bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:[bitmap colorSpaceName]
		bytesPerRow:width * 3 bitsPerPixel:24];
	stride = [bitmap bitsPerPixel] >> 3;
	rowBytes = [bitmap bytesPerRow];
	src = [bitmap bitmapData];
	dst = [packed bitmapData];
	for (y = 0; y < height; y++) {
		const unsigned char *row = src + y * rowBytes;
		for (x = 0; x < width; x++, dst += 3) {
			dst[0] = row[x * stride];
			dst[1] = row[x * stride + 1];
			dst[2] = row[x * stride + 2];
		}
	}
	[bitmap release];
	return packed;
}

// Images are loaded through NSImage and re-read as a bitmap from its TIFF
// representation, like the original did.
static NSBitmapImageRep *bitmapFromFile(NSString *path)
{
	NSImage *image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	if (image == nil)
		return nil;
	return packedBitmap([[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]]);
}

@implementation SMK_GL_BaseTexture

+ (const SMK_GL_TexFormat *)_formatForBitmap:(id)aBitmap
{
	NSDictionary *formats = [self _supportedFormats];
	unsigned int components = [[[self _supportedColorSpaces] objectForKey:[aBitmap colorSpaceName]] intValue];
	id key = [self _formatKeyForBPS:[aBitmap bitsPerSample] SPP:[aBitmap samplesPerPixel]
		BPP:[aBitmap bitsPerPixel] components:components];
	return [[formats objectForKey:key] pointerValue];
}

+ (id)_supportedColorSpaces
{
	if (_supportedColorSpaces == nil) {
		NSNumber *gray = [NSNumber numberWithUnsignedInt:'gray'];
		NSNumber *rgba = [NSNumber numberWithUnsignedInt:'rgba'];
		_supportedColorSpaces = [[NSDictionary alloc] initWithObjectsAndKeys:
			gray, NSCalibratedWhiteColorSpace,
			gray, NSDeviceWhiteColorSpace,
			rgba, NSCalibratedRGBColorSpace,
			rgba, NSDeviceRGBColorSpace, nil];
	}
	return _supportedColorSpaces;
}

+ (id)_supportedFormats
{
	if (_supportedFormats == nil) {
		const SMK_GL_TexFormat *all[] = {
			&_SMK_GL_TexFormat_A8, &_SMK_GL_TexFormat_L8, &_SMK_GL_TexFormat_I8,
			&_SMK_GL_TexFormat_RGBA8, &_SMK_GL_TexFormat_RGBA4, &_SMK_GL_TexFormat_RGB8,
			&_SMK_GL_TexFormat_ARGB8, &_SMK_GL_TexFormat_RGB16, &_SMK_GL_TexFormat_RGBA16,
		};
		NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
		for (size_t i = 0; i < sizeof(all) / sizeof(all[0]); i++) {
			[d setObject:[NSValue valueWithPointer:all[i]] forKey:[self _formatKeyForFormat:all[i]]];
		}
		_supportedFormats = d;
	}
	return _supportedFormats;
}

+ (id)_formatKeyForFormat:(const SMK_GL_TexFormat *)aFormat
{
	return [self _formatKeyForBPS:aFormat->bitsPerSample SPP:aFormat->samplesPerPixel
		BPP:aFormat->bitsPerPixel components:aFormat->components];
}

// The tag goes in as its four bytes in memory order, as the original did.
+ (id)_formatKeyForBPS:(NSUInteger)aBPS SPP:(NSUInteger)aSPP BPP:(NSUInteger)aBPP components:(NSUInteger)aComponents
{
	uint32_t tag = (uint32_t)aComponents;
	return [NSString stringWithFormat:@"%u %u %u %4.4s", (unsigned)aBPP, (unsigned)aSPP, (unsigned)aBPS,
		(const char *)&tag];
}

- (void)unbindAtStage:(NSInteger)aStage
{
	[super unbindAtStage:aStage];
	if (_useFenceSynchr) {
		if (_context != nil && _fence == 0) {
			glGenFencesAPPLE(1, &_fence);
		}
		if (_fence != 0) {
			glSetFenceAPPLE(_fence);
		}
	}
	[_locker unlock];
}

- (void)bindAtStage:(NSInteger)aStage
{
	[_locker lock];
	[super bindAtStage:aStage];
}

- (BOOL)isDirty
{
	return _isDirty;
}

- (void)unlock
{
	[_locker unlock];
}

- (void)lock
{
	[_locker lock];
}

- (void)contextWillBeDetached
{
	if (_fence != 0) {
		glDeleteFencesAPPLE(1, &_fence);
	}
	_fence = 0;
	[self _deleteTexture];
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	_combineExt = [aAttached textureCombineARB];
	[super contextWasAttached:aAttached];
	[self _createTexture];
}

- (void)_deleteTexture
{
	if (_textureID != 0) {
		glIsTexture(_textureID);
		glDeleteTextures(1, &_textureID);
		_textureID = 0;
		_format = NULL;
	}
}

- (void)_createTexture
{
	_textureTarget = (unsigned int)[self textureTarget];
	glEnable(_textureTarget);
	glBindTexture(_textureTarget, _textureID);
	[self _createTextureImage];
	glDisable(_textureTarget);
}

- (void)setTransformMatrix:(const SMK_GL_Matrix *)aMatrix
{
	if (aMatrix == NULL) {
		matrix_make_identity(&_transformMatrix);
	}
	else {
		_transformMatrix = *aMatrix;
	}
	_isDirty = YES;
}

- (void)dealloc
{
	// wait for anyone still using it
	[_locker lock];
	[_locker unlock];
	[_locker release];
	[self _deleteTexture];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		_locker = [NSRecursiveLock new];
		_flags = (unsigned int)aFlags;
		_usage = (int)aUsage;
		matrix_make_identity(&_transformMatrix);
	}
	return self;
}

- (void)_createTextureImage
{
}

@end

@implementation SMK_GL_VolumeTexture

- (void)bindAtStage:(NSInteger)aStage
{
	[super bindAtStage:aStage];
	if (_rWrapModeChanged) {
		glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_R, _rWrapMode);
		_rWrapModeChanged = NO;
	}
}

- (void)setWrapS:(NSUInteger)aS T:(NSUInteger)aT R:(NSUInteger)aR
{
	[super setWrapS:aS T:aT];
	_rWrapMode = (unsigned int)aR;
	_rWrapModeChanged = YES;
}

- (void)_createTextureImage
{
	NSUInteger depth = [_depthLayers count];
	if ((depth & (depth - 1)) != 0) {
		NSLog(@"Unable to create volume texture: number of depth layers must be power-of-two.");
		return;
	}
	NSMutableArray *layers = [NSMutableArray arrayWithCapacity:depth];
	const SMK_GL_TexFormat *format = NULL;
	NSInteger width = 0, height = 0, bytesPerPixel = 0;
	for (NSUInteger i = 0; i < depth; i++) {
		NSString *path = [_depthLayers objectAtIndex:i];
		NSBitmapImageRep *bitmap = [bitmapFromFile(path) autorelease];
		NSAssert1(bitmap != nil, @"Cannot load texture at path: %@", path);
		if (i == 0) {
			width = [bitmap pixelsWide];
			height = [bitmap pixelsHigh];
			format = [[self class] _formatForBitmap:bitmap];
			bytesPerPixel = [bitmap bitsPerPixel] >> 3;
			NSAssert(format != NULL, @"unknown source bitmap format during volume texture creation.");
		}
		else if (width != [bitmap pixelsWide] || height != [bitmap pixelsHigh] ||
				format != [[self class] _formatForBitmap:bitmap]) {
			NSLog(@"Unable to create volume texture: all depth layers must have the same internal format.");
			return;
		}
		[layers addObject:bitmap];
	}
	if ((width & (width - 1)) != 0 || (height & (height - 1)) != 0) {
		NSLog(@"Unable to create volume texture: width and height must be power-of-two.");
		return;
	}
	size_t layerSize = width * height * bytesPerPixel;
	NSMutableData *data = [NSMutableData dataWithLength:depth * layerSize];
	char *p = [data mutableBytes];
	for (NSUInteger i = 0; i < depth; i++) {
		memcpy(p, [[layers objectAtIndex:i] bitmapData], layerSize);
		p += layerSize;
	}
	if ([_context generateMipmapSGIS] && (_flags & kSMK_GL_TextureMipmaps)) {
		glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(_textureTarget, GL_GENERATE_MIPMAP_SGIS, GL_TRUE);
	}
	else {
		glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	}
	glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexImage3D(_textureTarget, 0, GL_RGB, (GLsizei)width, (GLsizei)height, (GLsizei)depth, 0, GL_RGB,
		format->type, [data mutableBytes]);
	glPopClientAttrib();
}

- (NSUInteger)textureTarget
{
	return GL_TEXTURE_3D;
}

- (void)dealloc
{
	[_depthLayers release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePaths:(id)aPaths
{
	self = [super initWithContainer:aContainer flags:aFlags usage:aUsage];
	if (self != nil) {
		_depthLayers = [[NSArray alloc] initWithArray:aPaths copyItems:YES];
	}
	return self;
}

@end

@implementation SMK_GL_CubeTexture

- (void)unbindAtStage:(NSInteger)aStage
{
	[super unbindAtStage:aStage];
	if (_flags & kSMK_GL_TextureReflectionMap) {
		glDisable(GL_TEXTURE_GEN_S);
		glDisable(GL_TEXTURE_GEN_T);
		glDisable(GL_TEXTURE_GEN_R);
	}
}

- (void)bindAtStage:(NSInteger)aStage
{
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	[super bindAtStage:aStage];
	if (_flags & kSMK_GL_TextureReflectionMap) {
		glEnable(GL_TEXTURE_GEN_S);
		glEnable(GL_TEXTURE_GEN_T);
		glEnable(GL_TEXTURE_GEN_R);
	}
}

- (void)_createTextureImage
{
	static const GLenum faces[6] = {
		GL_TEXTURE_CUBE_MAP_POSITIVE_X, GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
		GL_TEXTURE_CUBE_MAP_POSITIVE_Y, GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
		GL_TEXTURE_CUBE_MAP_POSITIVE_Z, GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
	};
	NSString *paths[6] = {
		_xPosFilePath, _xNegFilePath, _yPosFilePath, _yNegFilePath, _zPosFilePath, _zNegFilePath,
	};
	glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	if (_flags & kSMK_GL_TextureReflectionMap) {
		glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP);
		glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP);
		glTexGeni(GL_R, GL_TEXTURE_GEN_MODE, GL_REFLECTION_MAP);
	}
	for (int i = 0; i < 6; i++) {
		NSBitmapImageRep *bitmap = bitmapFromFile(paths[i]);
		NSAssert1(bitmap != nil, @"Cannot load texture at path: %@", paths[i]);
		const SMK_GL_TexFormat *format = [[self class] _formatForBitmap:bitmap];
		NSAssert(format != NULL, @"unknown source bitmap format during texture creation.");
		if (i == 0) {
			_format = format;
		}
		glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
		// the original used 3 (which GL rejects) for rows that are 3 mod 4
		NSInteger rowBytes = [bitmap bytesPerRow];
		glPixelStorei(GL_UNPACK_ALIGNMENT, (rowBytes & 3) == 3 ? 3 : (rowBytes & 2) ? 2 : 1);
		glTexImage2D(faces[i], 0, format->internalFormat, (GLsizei)[bitmap pixelsWide],
			(GLsizei)[bitmap pixelsHigh], 0, format->format, format->type, [bitmap bitmapData]);
		[bitmap release];
		glPopClientAttrib();
	}
}

- (NSUInteger)textureTarget
{
	return GL_TEXTURE_CUBE_MAP;
}

- (void)dealloc
{
	[_xPosFilePath release];
	[_xNegFilePath release];
	[_yPosFilePath release];
	[_yNegFilePath release];
	[_zPosFilePath release];
	[_zNegFilePath release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage xPosPath:(id)aPath xNegPath:(id)aPath2 yPosPath:(id)aPath3 yNegPath:(id)aPath4 zPosPath:(id)aPath5 zNegPath:(id)aPath6
{
	self = [super initWithContainer:aContainer flags:aFlags usage:aUsage];
	if (self != nil) {
		_xPosFilePath = [aPath copy];
		_xNegFilePath = [aPath2 copy];
		_yPosFilePath = [aPath3 copy];
		_yNegFilePath = [aPath4 copy];
		_zPosFilePath = [aPath5 copy];
		_zNegFilePath = [aPath6 copy];
	}
	return self;
}

@end

// A 2D or rectangle texture, from a file or from pixels the caller writes
// between lock and unlock. Without the rectangle extension, sizes are
// rounded up to powers of two and the texture matrix scales the used part.
@implementation SMK_GL_2DTexture

+ (id)textureForContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePath:(id)aPath
{
	return [[[self alloc] initWithContainer:aContainer flags:aFlags usage:aUsage filePath:aPath] autorelease];
}

- (void)unlockFocus
{
	if (_lockedImage == nil) {
		return;
	}
	[_lockedImage unlockFocus];
	NSBitmapImageRep *bitmap = [packedBitmap([[NSBitmapImageRep alloc] initWithData:
		[_lockedImage TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:1.0f]]) autorelease];
	NSAssert(_bitsPerPixel == [bitmap bitsPerPixel], @"Texture format is not suitable for updating with cocoa");
	NSInteger rows = [bitmap pixelsHigh];
	NSInteger rowBytes = [bitmap bytesPerRow];
	memcpy([self lock], [bitmap bitmapData], rows * rowBytes);
	[_lockedImage release];
	_lockedImage = nil;
	[self unlock];
}

- (void)lockFocus
{
	if (_lockedImage != nil) {
		return;
	}
	NSRect rect = NSMakeRect(0, 0, _width, _height);
	if (_cocoaDrawingWindow == nil) {
		_cocoaDrawingWindow = [[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskBorderless
			backing:NSBackingStoreRetained defer:NO];
		[_cocoaDrawingWindow setOpaque:NO];
		[_cocoaDrawingWindow setAlphaValue:0.0f];
	}
	_lockedImage = [[[NSImage alloc] initWithSize:rect.size] autorelease];
	[_lockedImage addRepresentation:[[[NSCachedImageRep alloc] initWithWindow:_cocoaDrawingWindow rect:rect] autorelease]];
	[_lockedImage lockFocus];
}

- (void)unlock
{
	if (!_lockedNotFromTheMainThread && _imageData != NULL && _textureID != 0) {
		[self _updateTexture];
	}
	if (_lockedContext != NULL) {
		CFRelease(_lockedContext);
		_lockedContext = NULL;
	}
	_isDirty = YES;
	[super unlock];
}

- (struct CGContext *)lockAndCreateCGContextWithClear:(BOOL)aClear
{
	size_t rowBytes, bitsPerComponent;
	CGBitmapInfo info;
	if (_bitsPerPixel == 16) {
		rowBytes = _width * 2;
		info = (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
		bitsPerComponent = 5;
	}
	else if (_bitsPerPixel == 32) {
		rowBytes = _width * 4;
		info = (CGBitmapInfo)(_alphaFirst ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaPremultipliedLast);
		bitsPerComponent = 8;
	}
	else {
		return NULL;
	}
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	void *pixels = [self lock];
	if (aClear) {
		memset(pixels, 0, rowBytes * _height);
	}
	_lockedContext = CGBitmapContextCreate(pixels, _width, _height, bitsPerComponent, rowBytes, space, info);
	CFRelease(space);
	CGContextSetInterpolationQuality(_lockedContext, kCGInterpolationNone);
	return _lockedContext;
}

// Locking from a thread other than the context's goes to a separate buffer,
// copied in the next time the texture is bound.
- (void *)lock
{
	[super lock];
	_wasLockedOnce = YES;
	_lockedNotFromTheMainThread = ![[NSThread currentThread] isEqual:[_context creationThread]];
	if (_lockedNotFromTheMainThread) {
		if (_threadSafeLoockedData == nil) {
			_threadSafeLoockedData = [[NSMutableData alloc] initWithLength:_height * _width * (_bitsPerPixel >> 3)];
		}
		return [_threadSafeLoockedData mutableBytes];
	}
	if (_fence != 0) {
		glFinishFenceAPPLE(_fence);
	}
	return _imageData;
}

- (NSInteger)bytesPerRow
{
	return _bytesPerRow;
}

- (NSInteger)bitsPerPixel
{
	return _bitsPerPixel;
}

- (NSInteger)height
{
	return _height;
}

- (NSInteger)width
{
	return _width;
}

- (void)_createTextureImage
{
	void *pixels = _imageData;
	if (_filePath != nil && _fileRepresentation == nil) {
		_fileRepresentation = bitmapFromFile(_filePath);
	}
	if (_fileRepresentation != nil) {
		// flipped, since GL's rows go bottom-up
		NSMutableData *data = [NSMutableData dataWithLength:_bytesPerRow * _glTextureHeight];
		const char *src = (const char *)[_fileRepresentation bitmapData];
		NSInteger rows = [_fileRepresentation pixelsHigh];
		NSInteger srcRowBytes = [_fileRepresentation bytesPerRow];
		for (NSInteger i = 0; i < rows; i++) {
			memcpy((char *)[data mutableBytes] + (rows - 1 - i) * _bytesPerRow, src + srcRowBytes * i, srcRowBytes);
		}
		pixels = [data mutableBytes];
	}
	else if (_imageData != NULL) {
		switch (_imagePtrFormat) {
			case GL_RGB8:
				_format = &_SMK_GL_TexFormat_RGB8;
				break;
			case GL_RGB16: // as in the original
			case GL_RGBA16:
				_format = &_SMK_GL_TexFormat_RGBA16;
				break;
			case GL_RGB5_A1:
				_format = _alphaFirst ? NULL : &_SMK_GL_TexFormat_RGB5A1;
				break;
			case GL_RGBA8:
				_format = _alphaFirst ? &_SMK_GL_TexFormat_ARGB8 : &_SMK_GL_TexFormat_RGBA8;
				break;
		}
		if (_width < _glTextureWidth) {
			// widen the rows to the texture's width
			int bytesPerPixel = _bitsPerPixel >> 3;
			size_t stride = _glTextureWidth * bytesPerPixel;
			size_t rowBytes = _width * bytesPerPixel;
			char *padded = malloc(stride * _glTextureHeight);
			if (_wasLockedOnce) {
				const char *src = _imageData;
				for (int y = 0; y < _height; y++) {
					memcpy(padded + y * stride, src, rowBytes);
					src += rowBytes;
				}
			}
			free(_imageData);
			_imageData = padded;
			pixels = padded;
		}
	}
	NSAssert(_format != NULL, @"unknown source bitmap format during texture creation.");
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
	glTexParameteri(_textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_S, _sWrapMode);
	glTexParameteri(_textureTarget, GL_TEXTURE_WRAP_T, _tWrapMode);
	// pixels written through lock stay in our memory
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, _imageData != NULL);
	if (_textureTarget == GL_TEXTURE_RECTANGLE_EXT && [SMK_GL_Config textureRangeIsEnabled]) {
		glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE,
			(_usage & kSMK_GL_TextureUsageShared) ? GL_STORAGE_SHARED_APPLE : GL_STORAGE_CACHED_APPLE);
		glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, _height * _width * (_bitsPerPixel >> 3), pixels);
		_useFenceSynchr = YES;
	}
	if ([_context generateMipmapSGIS] && _textureTarget == GL_TEXTURE_2D && (_flags & kSMK_GL_TextureMipmaps)) {
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP_SGIS, GL_TRUE);
	}
	else {
		glTexParameteri(_textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	}
	glTexImage2D(_textureTarget, 0, _format->internalFormat, _glTextureWidth, _glTextureHeight, 0,
		_format->format, _format->type, pixels);
	[_fileRepresentation release];
	_fileRepresentation = nil;
	glPopClientAttrib();
}

- (void)contextWillBeDetached
{
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	_rectangleExt = [aAttached textureRectangleEXT];
	_glTextureWidth = _width;
	_glTextureHeight = _height;
	if (!_rectangleExt) {
		if ((_width & (_width - 1)) != 0) {
			_glTextureWidth = 2;
			for (int w = _width >> 1; w != 0; w >>= 1) {
				_glTextureWidth <<= 1;
			}
		}
		if ((_height & (_height - 1)) != 0) {
			_glTextureHeight = 2;
			for (int h = _height >> 1; h != 0; h >>= 1) {
				_glTextureHeight <<= 1;
			}
		}
	}
	_bytesPerRow = (_bitsPerPixel >> 3) * _glTextureWidth;
	[super contextWasAttached:aAttached];
}

- (void)unbindAtStage:(NSInteger)aStage
{
	[super unbindAtStage:aStage];
}

- (void)bindAtStage:(NSInteger)aStage
{
	if (_lockedNotFromTheMainThread && _imageData != NULL) {
		[_locker lock];
		memcpy(_imageData, [_threadSafeLoockedData bytes], [_threadSafeLoockedData length]);
		[self _updateTexture];
		[_locker unlock];
		_lockedNotFromTheMainThread = NO;
	}
	[super bindAtStage:aStage];
	// rectangle textures take pixel coordinates; padded ones use part of the texture
	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	if (_textureTarget == GL_TEXTURE_RECTANGLE_EXT) {
		glScalef(_width, _height, 1.0f);
	}
	else if (_width != _glTextureWidth || _height != _glTextureHeight) {
		glScalef((float)_width / (float)_glTextureWidth, (float)_height / (float)_glTextureHeight, 1.0f);
	}
	glMultTransposeMatrixfARB(&_transformMatrix._11);
	glMatrixMode(GL_MODELVIEW);
}

- (void)_updateTexture
{
	glBindTexture(_textureTarget, _textureID);
	if (_imageData != NULL) {
		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, _glTextureWidth);
		glTexSubImage2D(_textureTarget, 0, 0, 0, _width, _height, _format->format, _format->type, _imageData);
	}
}

- (NSUInteger)textureTarget
{
	if (!_rectangleExt || (_flags & (kSMK_GL_TextureMipmaps | kSMK_GL_TextureNo2DRectangle)) ||
			(_isSquare && !(_usage & kSMK_GL_TextureUsageShared) && (_width & (_width - 1)) == 0)) {
		return GL_TEXTURE_2D;
	}
	return GL_TEXTURE_RECTANGLE_EXT;
}

- (void)dealloc
{
	if (_imageData != NULL) {
		free(_imageData);
		_imageData = NULL;
	}
	[_fileRepresentation release];
	[_filePath release];
	[_lockedImage release];
	[_cocoaDrawingWindow release];
	[_threadSafeLoockedData release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage width:(NSInteger)aWidth height:(NSInteger)aHeight dataFormat:(NSUInteger)aFormat alphaFirst:(BOOL)aFirst
{
	self = [self initWithContainer:aContainer flags:aFlags usage:aUsage width:aWidth height:aHeight dataFormat:aFormat];
	if (self != nil) {
		_alphaFirst = aFirst;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage width:(NSInteger)aWidth height:(NSInteger)aHeight dataFormat:(NSUInteger)aFormat
{
	self = [super initWithContainer:aContainer flags:aFlags usage:aUsage];
	if (self == nil) {
		return nil;
	}
	_isDirty = YES;
	_width = (int)aWidth;
	_height = (int)aHeight;
	_imagePtrFormat = (unsigned int)aFormat;
	switch (aFormat) {
		case GL_RGB8:
			_bitsPerPixel = 24;
			break;
		case GL_RGB16:
			_bitsPerPixel = 48;
			break;
		case GL_RGBA4:
		case GL_RGB5_A1:
			_bitsPerPixel = 16;
			break;
		case GL_RGBA8:
			_bitsPerPixel = 32;
			break;
		case GL_RGBA16:
			_bitsPerPixel = 64;
			break;
	}
	_isSquare = _width == _height;
	_textureTarget = (unsigned int)[self textureTarget];
	_imageData = calloc(1, _height * _width * (_bitsPerPixel >> 3));
	return self;
}

- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePath:(id)aPath
{
	self = [super initWithContainer:aContainer flags:aFlags usage:aUsage];
	if (self == nil) {
		return nil;
	}
	_filePath = [[NSString stringWithString:aPath] retain];
	_isDirty = YES;
	if (_filePath != nil) {
		_fileRepresentation = bitmapFromFile(_filePath);
	}
	if (_fileRepresentation == nil) {
		[self release];
		return nil;
	}
	_width = (int)[_fileRepresentation pixelsWide];
	_height = (int)[_fileRepresentation pixelsHigh];
	_bitsPerPixel = (int)[_fileRepresentation bitsPerPixel];
	_format = [[self class] _formatForBitmap:_fileRepresentation];
	return self;
}

@end
