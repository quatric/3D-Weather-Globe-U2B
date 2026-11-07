#import "GlobeTextureLoader.h"

#include <pwd.h>

// Loads the saver's textures from its bundle: the 1024 and 3072 pixel
// day maps (the 3072 one as 18 tiles of 1024, preloaded on a thread), the
// night lights, moon, stars, flares and clouds. Clouds are taken from the
// app's download folder when it has today's, else the bundled defaults.
@implementation GlobeTextureLoader

/* i386 ivar offsets: _container=0x4, _nightEastTexture=0x8, _nightWestTexture=0xc, _moonTexture=0x10, _starsTexture=0x14, _flaresTexture=0x18, _normalsWestTexture=0x1c, _normalsEastTexture=0x20, _cloudsEastTexture=0x24, _cloudsWestTexture=0x28, _preloadedHiResolutionTextures=0x2c, _hiResolutionTexturesWasLoaded=0x30, _needToStopLoadingThread=0x31, _lock=0x34, _jpgLock=0x38 */

// the maps are stored top down; flip t
static void _setFlippedTransform(SMK_GL_BaseTexture *aTexture)
{
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	matrix._22 = -1.0f;
	matrix._24 = 1.0f;
	[aTexture setTransformMatrix:&matrix];
}

- (id)createTextureForMapPart
{
	[_container beginAccumulationBlock];
	SMK_GL_2DTexture *texture = [[[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:1
	                                                                    width:1024 height:1024
	                                                               dataFormat:GL_RGB5_A1] autorelease];
	[_container endAccumulationBlock];
	_setFlippedTransform(texture);
	[texture setEnvMode:GL_MODULATE];
	return texture;
}

- (BOOL)isHiResolutionTexturesWasLoaded
{
	return _hiResolutionTexturesWasLoaded;
}

- (void)waitForStopLoadingThread
{
	_needToStopLoadingThread = YES;
	while (!_hiResolutionTexturesWasLoaded) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
}

- (void)preloadHiResolutionTextures
{
	NSMutableDictionary *textures = [[NSMutableDictionary alloc] initWithCapacity:18];
	_hiResolutionTexturesWasLoaded = NO;
	_preloadedHiResolutionTextures = textures;
	[NSThread detachNewThreadSelector:@selector(_preloadingThreadEntrypoint:) toTarget:self withObject:nil];
}

- (id)_cloudsTextureIsEast:(BOOL)aEast
{
	SMK_GL_2DTexture *texture = nil;
	NSString *folder = [self _cloudsDownloadFolder];
	if (folder != nil) {
		NSCalendarDate *date = [NSCalendarDate calendarDate];
		NSString *name = [GlobeTextureLoader _cloudsFileNameForDate:date isEast:aEast forToday:YES];
		if (name == nil) {
			name = [GlobeTextureLoader _cloudsFileNameForDate:date isEast:aEast forToday:NO];
		}
		texture = [[self _createTextureWithContentsOfFile:[folder stringByAppendingPathComponent:name]
		                                         use32Bit:NO useGammaCorrection:YES] retain];
	}
	if (texture == nil) {
		NSString *path = [[NSBundle bundleForClass:[self class]]
		    pathForResource:aEast ? @"east_defaultClouds" : @"west_defaultClouds" ofType:@"jpg"
		        inDirectory:@"CloudsDefault"];
		texture = [[self _createTextureWithContentsOfFile:path use32Bit:NO useGammaCorrection:YES] retain];
	}
	_setFlippedTransform(texture);
	return texture;
}

- (id)cloudsWestTexture
{
	if (_cloudsWestTexture == nil) {
		_cloudsWestTexture = [self _cloudsTextureIsEast:NO];
	}
	return _cloudsWestTexture;
}

- (id)cloudsEastTexture
{
	if (_cloudsEastTexture == nil) {
		_cloudsEastTexture = [self _cloudsTextureIsEast:YES];
	}
	return _cloudsEastTexture;
}

- (id)_bundleTexture:(NSString *)aName flags:(NSUInteger)aFlags
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:aName ofType:@"tiff"];
	return [[SMK_GL_2DTexture textureForContainer:_container flags:aFlags usage:0 filePath:path] retain];
}

- (id)flaresTexture
{
	if (_flaresTexture == nil) {
		_flaresTexture = [self _bundleTexture:@"Flares" flags:0];
	}
	return _flaresTexture;
}

- (id)starsTexture
{
	if (_starsTexture == nil) {
		_starsTexture = [self _bundleTexture:@"Stars" flags:1];
	}
	return _starsTexture;
}

- (id)moonTexture
{
	if (_moonTexture == nil) {
		_moonTexture = [self _bundleTexture:@"moon" flags:0];
	}
	return _moonTexture;
}

- (id)_nightTexture:(NSString *)aName
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:aName ofType:@"jpo"
	                                                             inDirectory:@"Map/Night"];
	SMK_GL_2DTexture *texture = [[self _createTextureWithContentsOfFile:path use32Bit:NO useGammaCorrection:NO] retain];
	_setFlippedTransform(texture);
	return texture;
}

- (id)nightTextureForWest
{
	if (_nightWestTexture == nil) {
		_nightWestTexture = [self _nightTexture:@"earth_1024_west"];
	}
	return _nightWestTexture;
}

- (id)nightTextureForEast
{
	if (_nightEastTexture == nil) {
		_nightEastTexture = [self _nightTexture:@"earth_1024_east"];
	}
	return _nightEastTexture;
}

static void _copyPreloaded(SMK_GL_2DTexture *aTexture, NSData *aData)
{
	void *bitmap = [aTexture lock];
	memcpy(bitmap, [aData bytes], [aData length]);
	[aTexture unlock];
}

- (id)textureForLOD:(NSInteger)aLOD xPart:(NSInteger)aPart yPart:(NSInteger)aPart2
{
	[_lock lock];
	if (aLOD == 1 && _hiResolutionTexturesWasLoaded) {
		NSData *data = [_preloadedHiResolutionTextures objectForKey:[NSNumber numberWithInt:(int)(aPart + aPart2 * 6)]];
		if (data == nil) {
			[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
			    file:@"GlobeTextureLoader.m" lineNumber:0x16f description:@"Can not find preloaded bitmap data."];
		}
		SMK_GL_2DTexture *texture = [self createTextureForMapPart];
		_copyPreloaded(texture, data);
		[_lock unlock];
		return texture;
	}
	NSString *path = [self _pathForLOD:aLOD xPart:aPart yPart:aPart2];
	SMK_GL_2DTexture *texture = [self createTextureForMapPart];
	[self _fillTexture:texture withContentsOfFile:path];
	[_lock unlock];
	return texture;
}

// copies a preloaded tile into a texture and drops the tile
- (void)fillTexture:(id)aTexture lod:(NSInteger)aLod xPart:(NSInteger)aPart yPart:(NSInteger)aPart2
{
	if (aLod != 1) {
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
		    file:@"GlobeTextureLoader.m" lineNumber:0x150 description:@"Oonly data for lod=1 can be fill in texture"];
	}
	NSNumber *key = [NSNumber numberWithInt:(int)(aPart + aPart2 * 6)];
	NSData *data = [_preloadedHiResolutionTextures objectForKey:key];
	if (data == nil) {
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
		    file:@"GlobeTextureLoader.m" lineNumber:0x158 description:@"Can not find preloaded bitmap data."];
	}
	_copyPreloaded(aTexture, data);
	[_preloadedHiResolutionTextures removeObjectForKey:key];
}

- (void)dealloc
{
	[self waitForStopLoadingThread];
	[_nightEastTexture release];
	[_nightWestTexture release];
	[_moonTexture release];
	[_starsTexture release];
	[_flaresTexture release];
	[_normalsWestTexture release];
	[_normalsEastTexture release];
	[_cloudsEastTexture release];
	[_cloudsWestTexture release];
	[_preloadedHiResolutionTextures release];
	[_lock release];
	[_jpgLock release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
	self = [super init];
	if (self != nil) {
		_container = aContainer;
		_lock = [[NSLock alloc] init];
		// no loading thread runs until preloadHiResolutionTextures
		_hiResolutionTexturesWasLoaded = YES;
		_needToStopLoadingThread = NO;
		_jpgLock = [[NSLock alloc] init];
	}
	return self;
}

@end

@implementation GlobeTextureLoader (Private)

// The app saves today's clouds as east_tooday.jpg / west_tooday.jpg (sic),
// and older frames as <east|west>_yy_mm_dd_<6-hour slot>.jpg.
+ (id)_cloudsFileNameForDate:(id)aDate isEast:(BOOL)aEast forToday:(BOOL)aToday
{
	NSString *side = aEast ? @"east" : @"west";
	if (aToday) {
		return [NSString stringWithFormat:@"%@_tooday.jpg", side];
	}
	return [NSString stringWithFormat:@"%@_%@_%d.jpg", side, [aDate descriptionWithCalendarFormat:@"%y_%m_%d"],
	                                  (int)[aDate hourOfDay] / 6];
}

// decodes the 18 tiles of the 3072 pixel map as 16-bit bitmaps
- (void)_preloadingThreadEntrypoint:(id)aEntrypoint
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 6; x++) {
			if (_needToStopLoadingThread)
				goto done;
			NSNumber *key = [NSNumber numberWithInt:x + y * 6];
			NSString *path = [self _pathForLOD:1 xPart:x yPart:y];
			NSMutableData *data = [NSMutableData dataWithLength:1024 * 1024 * 2];
			[self _loadDataBySMKJPGFromFile:path width:1024 height:1024 bitDepth:16 bitmap:[data mutableBytes]];
			[_preloadedHiResolutionTextures setObject:data forKey:key];
		}
	}
done:
	_hiResolutionTexturesWasLoaded = YES;
	[pool release];
}

- (id)_cloudsDownloadFolder
{
	if (sCloudsFolder == nil) {
		NSString *name = [[NSBundle bundleForClass:[self class]] localizedStringForKey:kCloudsFolder value:@""
		                                                                         table:kPathCompTable];
		sCloudsFolder = [[[self _sharedAtlasFolder] stringByAppendingPathComponent:name] retain];
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath:sCloudsFolder]) {
		[sCloudsFolder release];
		sCloudsFolder = nil;
	}
	return sCloudsFolder;
}

// The app's shared folder. The 2011 app kept it in /Library/Application
// Support; the port keeps it in the user's, which is where this looks first.
// The user's real home is used because legacyScreenSaver runs in a sandbox
// container with its own home folder.
- (id)_sharedAtlasFolder
{
	if (sAtlasSupportFolder != nil && [[NSFileManager defaultManager] fileExistsAtPath:sAtlasSupportFolder]) {
		return sAtlasSupportFolder;
	}
	[sAtlasSupportFolder release];
	sAtlasSupportFolder = nil;

	NSString *name = [[NSBundle bundleForClass:[self class]] localizedStringForKey:kAtlasAppSuppFolder value:@""
	                                                                         table:kPathCompTable];
	NSMutableArray *candidates = [NSMutableArray array];
	struct passwd *user = getpwuid(getuid());
	if (user != NULL && user->pw_dir != NULL) {
		[candidates addObject:[[NSFileManager defaultManager] stringWithFileSystemRepresentation:user->pw_dir
		                                                                                  length:strlen(user->pw_dir)]];
	}
	[candidates addObject:@"/"];
	for (NSString *root in candidates) {
		NSString *folder = [[root stringByAppendingPathComponent:@"Library/Application Support"]
		    stringByAppendingPathComponent:name];
		if ([[NSFileManager defaultManager] fileExistsAtPath:folder]) {
			sAtlasSupportFolder = [folder retain];
			return sAtlasSupportFolder;
		}
	}
	return nil;
}

- (void)_fillBitmapRep:(id)aRep withContentsOfFile:(id)aFile
{
	CGImageRef image = _CreateCGImageFromFile(aFile);
	if (image == NULL)
		return;
	NSBitmapImageRep *rep = aRep;
	_DrawCGImageIntoBitmap(image, [rep bitmapData], [rep pixelsWide], [rep pixelsHigh], (int)[rep bitsPerPixel]);
	CFRelease(image);
}

- (void)_fillTexture:(id)aTexture withContentsOfFile:(id)aFile
{
	SMK_GL_2DTexture *texture = aTexture;
	void *bitmap = [texture lock];
	[self _loadDataBySMKJPGFromFile:aFile width:[texture width] height:[texture height]
	                       bitDepth:[texture bitsPerPixel] bitmap:bitmap];
	[texture unlock];
}

- (void)_loadDataBySMKJPGFromFile:(id)aFile width:(NSInteger)aWidth height:(NSInteger)aHeight bitDepth:(NSInteger)aDepth bitmap:(void *)aBitmap
{
	[_jpgLock lock];
	CGImageRef image = _CreateCGImageFromFile(aFile);
	if (image != NULL) {
		_DrawCGImageIntoBitmap(image, aBitmap, aWidth, aHeight, (int)aDepth);
		CFRelease(image);
	}
	[_jpgLock unlock];
}

// aCorrection is unused, as in the original
- (id)_createTextureWithContentsOfFile:(id)aFile use32Bit:(BOOL)aBit useGammaCorrection:(BOOL)aCorrection
{
	[_lock lock];
	CGImageRef image = _CreateCGImageFromFile(aFile);
	if (image == NULL) {
		[_lock unlock];
		return nil;
	}
	size_t width = CGImageGetWidth(image);
	size_t height = CGImageGetHeight(image);
	[_container beginAccumulationBlock];
	SMK_GL_2DTexture *texture = [[[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:0
	                                                                    width:width height:height
	                                                               dataFormat:aBit ? GL_RGBA8 : GL_RGB5_A1] autorelease];
	_DrawCGImageIntoBitmap(image, [texture lock], width, height, aBit ? 32 : 16);
	CFRelease(image);
	[texture unlock];
	[_container endAccumulationBlock];
	[texture setWrapS:GL_CLAMP_TO_EDGE T:GL_CLAMP_TO_EDGE];
	[_lock unlock];
	return texture;
}

// LOD 0: the 1024 pixel map, xPart 0 east and 1 west. LOD 1: the 3072 map
// in 6 x 3 tiles, xParts 0-2 east and 3-5 west, yPart 0 at the bottom.
- (id)_pathForLOD:(NSInteger)aLOD xPart:(NSInteger)aPart yPart:(NSInteger)aPart2
{
	BOOL east;
	BOOL valid;
	if (aLOD == 0) {
		east = aPart == 0;
		valid = aPart >= 0 && aPart < 2 && aPart2 == 0;
	} else {
		east = aPart < 3;
		valid = aLOD == 1 && aPart >= 0 && aPart2 >= 0 && aPart < 6 && aPart2 < 3;
	}
	if (!valid) {
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
		    file:@"GlobeTextureLoader.m" lineNumber:0x4a description:@"Incorrect LOD for globe texture."];
	}
	NSString *resources = [[NSBundle bundleForClass:[self class]] resourcePath];
	NSString *side = @"East";
	if (!east) {
		side = @"West";
		aPart -= 3;
	}
	if (aLOD != 0) {
		return [NSString stringWithFormat:@"%@/Map/%@/3/earth_3072_%02d.jpo", resources, side,
		                                  (int)(aPart + 1 + (2 - aPart2) * 3)];
	}
	return [NSString stringWithFormat:@"%@/Map/%@/1/earth_1024.jpo", resources, side];
}

@end
