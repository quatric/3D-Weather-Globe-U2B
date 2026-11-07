#import "BaseAtlasScene.h"


// with little video memory the apple store markers get a hand made shadow
// instead of the font's background
static BOOL _sUseCustomAppleShadow = NO;
static const SMK_GL_Color _fontBackColor = { 0.0f, 0.0f, 0.0f, 1.0f };
static const SMK_GL_Color _captionBackColor = { 0.0f, 0.0f, 0.0f, 1.0f };
static const SMK_GL_Color _appleShadowColor = { 0.0f, 0.0f, 0.0f, 1.0f };

@implementation BaseAtlasScene

+ (void)initialize
{
	_sUseCustomAppleShadow = (unsigned)videoMemoryForScreen([NSScreen mainScreen]) < 0x4400;
}

- (id)textureForLod:(NSInteger)aLod xPos:(NSInteger)aPos yPos:(NSInteger)aPos2 translation:(struct WeatherGlobe_anon5 *)aTranslation scaling:(struct WeatherGlobe_anon5 *)aScaling
{
	NSString *path = [MapPartsLoader pathForMapTextureForLOD:aLod xPos:aPos yPos:aPos2];
	NSDictionary *entry = [_currentTextures objectForKey:path];
	if (entry == nil) {
		path = [[self _loader] nearestCachedLowResPathForLOD:aLod xPos:aPos yPos:aPos2 translation:aTranslation scaling:aScaling];
		entry = [_currentTextures objectForKey:path];
	} else {
		aTranslation->f0 = aTranslation->f1 = 0.0f;
		aScaling->f0 = aScaling->f1 = 1.0f;
	}
	return [entry objectForKey:k2DTextureKey];
}

- (struct WeatherGlobe_anon2)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint
{
	struct WeatherGlobe_anon2 result = { 0.0f, 0.0f, 0.0f };
	return result;
}

// a line list mesh of the paths' outlines
- (id)createGLMeshWidthBezierPaths:(id)aPaths
{
	NSMutableData *vertices = [[NSMutableData new] autorelease];
	NSMutableData *indices = [[NSMutableData new] autorelease];
	NSInteger pathsCount = [aPaths count];
	int vertexCount = 0, lineCount = 0, firstVertex = 0;
	for (NSInteger p = 0; p < pathsCount; p++) {
		NSBezierPath *path = [aPaths objectAtIndex:p];
		NSInteger elementsCount = [path elementCount];
		BOOL open = NO;
		for (NSInteger e = 0; e < elementsCount; e++) {
			NSPoint points[3];
			struct WeatherGlobe_anon2 vertex;
			int index;
			switch ([path elementAtIndex:e associatedPoints:points]) {
			case NSMoveToBezierPathElement:
				vertex = [self get3DCoordinatesFromGeoPoint:points[0]];
				firstVertex = vertexCount;
				[vertices appendBytes:&vertex length:sizeof(vertex)];
				vertexCount++;
				open = YES;
				break;
			case NSLineToBezierPathElement:
				if (!open) {
					firstVertex = vertexCount;
					open = YES;
				}
				vertex = [self get3DCoordinatesFromGeoPoint:points[0]];
				[vertices appendBytes:&vertex length:sizeof(vertex)];
				index = vertexCount - 1;
				[indices appendBytes:&index length:sizeof(index)];
				[indices appendBytes:&vertexCount length:sizeof(vertexCount)];
				vertexCount++;
				lineCount++;
				break;
			case NSCurveToBezierPathElement:
				NSAssert(NO, @"NSCurveToBezierPathElement not supported in _createMeshWidthBezierPath.");
				break;
			case NSClosePathBezierPathElement:
				if (open) {
					index = vertexCount - 1;
					[indices appendBytes:&index length:sizeof(index)];
					[indices appendBytes:&firstVertex length:sizeof(firstVertex)];
					lineCount++;
					open = NO;
				}
				break;
			default:
				break;
			}
		}
	}

	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:2 usage:0 verticesCount:vertexCount
	                                            primitivesCount:lineCount primitiveType:1] autorelease];
	if (mesh == nil)
		return nil;
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	[vertexBuffer setAutoUpdateBounds:YES];
	memcpy([vertexBuffer lock:0], [vertices bytes], vertexCount * sizeof(struct WeatherGlobe_anon2));
	[vertexBuffer unlock];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	const int *source = [indices bytes];
	if ([indexBuffer are32BitIndices]) {
		uint32_t *target = [indexBuffer lock:2];
		for (int i = 0; i < lineCount * 2; i++)
			target[i] = (uint32_t)source[i];
	} else {
		uint16_t *target = [indexBuffer lock:2];
		for (int i = 0; i < lineCount * 2; i++)
			target[i] = (uint16_t)source[i];
	}
	[indexBuffer unlock];
	return mesh;
}

- (void)setNeedLayoutCaptions:(BOOL)aCaptions
{
	[_routeMarkersCaptionsLayouter setNeedLayout:aCaptions];
}

- (id)allCitiesPoints
{
	if (_allCitiesPoints == nil)
		[self _createAllCitiesPoints];
	return _allCitiesPoints;
}

- (id)routePathsMesh
{
	return nil;
}

- (id)routeMarkersMesh
{
	return nil;
}

- (id)allCitiesMesh
{
	return [[self allCitiesPoints] mesh];
}

- (void)drawInfoInContext:(id)aContext
{
	[_infoDrawer drawInfoInContext:aContext];
}

// "Authorizing..." or the clouds download count in the top right corner
- (void)drawOverlaysInContext:(id)aContext
{
	NSInteger cloudsCount = [CWManager cloudMapsCountInDownloadQueue];
	DownloadManager *manager = [DownloadManager downloadManager];
	NSString *text;
	if ([manager isAuthorizing]) {
		text = [[NSBundle mainBundle] localizedStringForKey:@"Authorizing..." value:@"" table:nil];
	} else {
		if ([manager authorizationFailed] || cloudsCount < 1)
			return;
		text = [NSString stringWithFormat:[[NSBundle mainBundle] localizedStringForKey:@"Clouds are downloading" value:@"" table:nil],
		                                  (int)cloudsCount];
	}
	if (text == nil)
		return;
	SMK_GL_Context *context = aContext;
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	SMK_GL_Color black = { 0.0f, 0.0f, 0.0f, 1.0f };
	[context setColor:&white];
	MainWindowController *windowController = [[self sceneController] windowController];
	SMK_GL_2DTexture *background = [windowController textBackground];
	float width = (float)[background width];
	float height = (float)[background height];
	NSSize size = [context size];
	NSRect rect = NSMakeRect(((-10.0f - width) * 2.0f) / (float)size.width + 1.0f,
	                         ((-10.0f - height) * 2.0f) / (float)size.height + 1.0f,
	                         (width + width) / (float)size.width, (height + height) / (float)size.height);
	BOOL was2D = [context isIn2DMode];
	if (!was2D)
		[context enter2DMode];
	[context drawTexture:background inRect:rect];
	[context setFont:[windowController normalFont]];
	[context drawString:text inRect:rect hAlignment:2 vAlignment:1 backColor:&black];
	if (!was2D)
		[context exit2DMode];
}

- (void)drawStatusLineInContext:(id)aContext
{
	if (_statusLine == nil)
		return;
	SMK_GL_Context *context = aContext;
	BOOL was2D = [context isIn2DMode];
	if (!was2D)
		[context enter2DMode];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	SMK_GL_Color black = { 0.0f, 0.0f, 0.0f, 1.0f };
	[context setColor:&white];
	[context setFont:[[[self sceneController] windowController] normalFont]];
	[context drawString:_statusLine inRect:NSMakeRect(-1.0, -1.0, 2.0, 2.0) hAlignment:2 vAlignment:2 backColor:&black];
	if (!was2D)
		[context exit2DMode];
}

- (void)drawAppleStoresInContext:(id)aContext
{
	NSArray *stores = [[AtlasDatabase database] appleStores];
	NSInteger count = [stores count];
	BOOL was2D = [aContext isIn2DMode];
	if (!was2D)
		[aContext enter2DMode];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[aContext setFont:_appleStoresGLFont];
	for (NSInteger i = 0; i < count; i++)
		[self _drawAppleStoreEntry:[stores objectAtIndex:i] inContext:aContext];
	glDisable(GL_BLEND);
	if (!was2D)
		[aContext exit2DMode];
}

- (void)_drawAppleStoreEntry:(id)aEntry inContext:(id)aContext
{
	SMK_GL_Context *context = aContext;
	SMK_GL_Color color;
	if (_highlightedAppleStore == aEntry && aEntry != nil) {
		color = *(SMK_GL_Color *)&_colorHilitedAppleStore;
	} else {
		struct WeatherGlobe_anon7 marker = [(AppleStoreEntry *)aEntry markerColor];
		color.r = marker.f0;
		color.g = marker.f1;
		color.b = marker.f2;
		color.a = marker.f3;
	}
	NSArray *points = [[self sceneController] normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint([aEntry coordinates])];
	NSInteger count = [points count];
	for (NSInteger i = 0; i < count; i++) {
		NSPoint point = [[points objectAtIndex:i] pointValue];
		float x = (float)point.x, y = (float)point.y;
		if (x < 0.0f || x > 1.0f)
			continue;
		x = x + x - 1.0f;
		y = y + y - 1.0f;
		if (_sUseCustomAppleShadow) {
			[context setColor:&_appleShadowColor];
			[context drawString:[aEntry markerString] inRect:NSMakeRect(x - 0.0975f, y - 0.1025f, 0.2f, 0.2f)
			         hAlignment:2 vAlignment:1 backColor:NULL];
		}
		[context setColor:&color];
		[context drawString:[aEntry markerString] inRect:NSMakeRect(x - 0.1f, y - 0.1f, 0.2f, 0.2f)
		         hAlignment:2 vAlignment:1 backColor:_sUseCustomAppleShadow ? NULL : &_appleShadowColor];
	}
}

- (void)drawHighlightedCitiesInContext:(id)aContext
{
	if (_highlightedCity == nil && _highlightedCity2 == nil)
		return;
	BOOL was2D = [aContext isIn2DMode];
	if (!was2D)
		[aContext enter2DMode];
	struct WeatherGlobe_anon7 white = { 1.0f, 1.0f, 1.0f, 1.0f };
	[self _drawHighlightedCity:_highlightedCity color:white InContext:aContext];
	struct WeatherGlobe_anon7 color2 = { _colorHilitedCity2.r, _colorHilitedCity2.g, _colorHilitedCity2.b, _colorHilitedCity2.a };
	[self _drawHighlightedCity:_highlightedCity2 color:color2 InContext:aContext];
	if (!was2D)
		[aContext exit2DMode];
}

- (void)_drawHighlightedCity:(id)aCity color:(struct WeatherGlobe_anon7)aColor InContext:(id)aContext
{
	if (aCity == nil)
		return;
	SMK_GL_Context *context = aContext;
	NSArray *points = [[self sceneController] normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint([aCity coordinates])];
	NSInteger count = [points count];
	MainWindowController *windowController = [[self sceneController] windowController];
	BOOL marked = [windowController cityIsMarked:aCity];
	for (NSInteger i = 0; i < count; i++) {
		NSPoint point = [[points objectAtIndex:i] pointValue];
		float x = (float)point.x * 2.0f - 1.0f;
		float y = (float)point.y * 2.0f - 1.0f;
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		[context setColor:(SMK_GL_Color *)&aColor];
		NSRect frame = [[windowController glView] frame];
		float halfHeight = (float)[_flatCityMarkerTexture height] / (float)frame.size.height;
		float halfWidth = (float)[_flatCityMarkerTexture width] / (float)frame.size.width;
		[context drawTexture:_flatCityMarkerTexture inRect:NSMakeRect(x - halfWidth, y - halfHeight, halfWidth + halfWidth, halfHeight + halfHeight)];
		if (!marked) {
			[context setFont:[windowController normalFont]];
			[context drawString:[aCity shortCaption] atPosition:NSMakePoint(halfWidth * 1.1f + x, y - halfHeight) backColor:&_captionBackColor];
		}
	}
}

- (void)drawSelectionRectInContext:(id)aContext
{
	SMK_GL_Material *material = [(SMK_GL_Mesh *)[_planeMeshDrawable mesh] material];
	[material setTexture:nil atStage:0];
	SMK_GL_Color color = { 0.1f, 0.4f, 0.9f, 0.3f };
	[material setAmbient:color];
	[material setDiffuse:color];
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	matrix._11 = (float)_selectionRect.size.width * 2.0f;
	matrix._22 = (float)_selectionRect.size.height * 2.0f;
	matrix._14 = (float)_selectionRect.origin.x * 2.0f - 1.0f;
	matrix._24 = (float)_selectionRect.origin.y * 2.0f - 1.0f;
	[aContext enter2DMode];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[_planeMeshDrawable setMatrix:&matrix];
	[_planeMeshDrawable drawInContext:aContext];
	glDisable(GL_BLEND);
	[aContext exit2DMode];
}

- (void)fillVerticesWithAllCitiesInVB:(struct WeatherGlobe_anon4 *)aVB
{
}

- (void)dragConcludedWithAllEntries
{
}

- (void)dragExitedWithAllEntries
{
}

- (void)dragBringsEntries:(id)aEntries
{
}

- (void)distCalcSetChangedTo:(id)aTo
{
}

- (void)recalculateCountryHilite
{
}

- (void)highlightCountry:(id)aCountry state:(id)aState timeZone:(id)aZone
{
}

- (CGFloat)appleStoreMarkerSize
{
	return _appleStoreMarkerSize;
}

- (id)highlightedAppleStore
{
	return _highlightedAppleStore;
}

- (void)highlightAppleStore:(id)aStore hiliteColor:(struct WeatherGlobe_anon7 *)aColor
{
	if (aColor != NULL) {
		_colorHilitedAppleStore.r = aColor->f0;
		_colorHilitedAppleStore.g = aColor->f1;
		_colorHilitedAppleStore.b = aColor->f2;
		_colorHilitedAppleStore.a = aColor->f3;
	}
	[aStore retain];
	[_highlightedAppleStore release];
	_highlightedAppleStore = aStore;
	[[self sceneController] refreshView];
}

- (void)highlightCity2:(id)aCity2 hiliteColor:(struct WeatherGlobe_anon7 *)aColor
{
	if (aColor != NULL) {
		_colorHilitedCity2.r = aColor->f0;
		_colorHilitedCity2.g = aColor->f1;
		_colorHilitedCity2.b = aColor->f2;
		_colorHilitedCity2.a = aColor->f3;
	}
	[aCity2 retain];
	[_highlightedCity2 release];
	_highlightedCity2 = aCity2;
	[[self sceneController] refreshView];
}

- (void)highlightCity:(id)aCity
{
	id controller = [self sceneController];
	[aCity retain];
	[_highlightedCity release];
	_highlightedCity = aCity;
	[controller refreshView];
}

- (void)setStatusLine:(id)aLine
{
	[aLine retain];
	[_statusLine release];
	_statusLine = aLine;
}

- (void)setSelectionRect:(NSRect)aRect
{
	_selectionRect = aRect;
	[[self sceneController] refreshView];
}

- (BOOL)selectionVisible
{
	return _selectionRectIsVisible;
}

- (void)setSelectionVisible:(BOOL)aVisible
{
	_selectionRectIsVisible = aVisible;
	[[self sceneController] refreshView];
}

- (void)_mainDatabaseWasChanged
{
	[_allCitiesPoints release];
	_allCitiesPoints = nil;
}

- (id)routePointsContainer
{
	return nil;
}

- (id)sceneController
{
	return nil;
}

- (BOOL)requiresAnimation
{
	return NO;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_planeMeshDrawable release];
	[_flatCityMarkerTexture release];
	[_allCitiesPoints release];
	[_highlightedCity release];
	[_highlightedCity2 release];
	[_routeMarkersCaptions release];
	[_routeMarkersCaptionsLayouter release];
	[_zoneHiliter release];
	[_highlightCountryFillColor release];
	[_highlightStateFillColor release];
	[_highlightTimeZoneFillColor release];
	[_highlightCountryBorderColor release];
	[_highlightStateBorderColor release];
	[_highlightTimeZoneBorderColor release];
	[_highlightCaptionColor release];
	[_highlightCaptionTimeZoneColor release];
	[_appleStoresGLFont release];
	[_currentTextures release];
	[_recordedCaptionIDs release];
	[_infoDrawer release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
	self = [super init];
	if (self == nil)
		return nil;
	_currentTextures = [NSMutableDictionary new];
	_container = aContainer;
	_appleStoresGLFont = [[[self sceneController] windowController] normalFont];
	[_container beginAccumulationBlock];
	[self _createPlaneMesh];
	SMK_GL_Vec3 axis = { 1.0f, 0.0f, 0.0f };
	SMK_GL_Matrix matrix;
	rotateMatrix(&matrix, (float)M_PI_2, &axis);
	[_planeMeshDrawable setMatrix:&matrix];
	_nearestCityCaptionBackColor = *(const struct WeatherGlobe_anon6 *)&_fontBackColor;
	_countryCaptionBackColor = *(const struct WeatherGlobe_anon6 *)&_fontBackColor;
	_flatCityMarkerTexture = [[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:0
	                                                            filePath:[[NSBundle mainBundle] pathForResource:@"krujochek" ofType:@"tiff"]];
	_highlightCountryFillColor = [[NSColor colorWithDeviceRed:0.2 green:1.0 blue:0.2 alpha:0.4] retain];
	_highlightStateFillColor = [[NSColor colorWithDeviceRed:1.0 green:0.2 blue:0.2 alpha:0.4] retain];
	_highlightTimeZoneFillColor = [[NSColor colorWithDeviceRed:0.2 green:0.2 blue:1.0 alpha:0.4] retain];
	_highlightCountryBorderColor = [[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:1.0] retain];
	_highlightStateBorderColor = [[NSColor colorWithDeviceRed:1.0 green:0.8 blue:0.8 alpha:1.0] retain];
	_highlightTimeZoneBorderColor = [[NSColor colorWithDeviceRed:0.8 green:0.8 blue:1.0 alpha:1.0] retain];
	_highlightCaptionColor = [[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:1.0] retain];
	_highlightCaptionTimeZoneColor = [[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:1.0] retain];
	[_container endAccumulationBlock];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mainDatabaseWasChanged)
	                                             name:kMainDatabaseChangedNotification object:nil];
	return self;
}

- (void)_createAllCitiesPoints
{
	[_container beginAccumulationBlock];
	NSUInteger count = [[[AtlasDatabase database] allCityPointsArray] length] >> 3;
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:2 usage:0 verticesCount:count
	                                            primitivesCount:count primitiveType:0] autorelease];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 1.1f, 1.0f, 0.3f, 1.0f };
	SMK_GL_Color diffuse = { 0.0f, 0.0f, 0.0f, 1.0f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	[self fillVerticesWithAllCitiesInVB:[vertexBuffer lock:2]];
	[vertexBuffer unlock];
	_allCitiesPoints = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	[_allCitiesPoints setPerformsVisibilityCheck:NO];
	[_container endAccumulationBlock];
}

- (void)_createPlaneMesh
{
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(0.0, 0.0, 1.0, 1.0) xSegments:4 ySegments:4
	                                              container:_container fvf:0x202 usage:0];
	[mesh setMaterial:[[[SMK_GL_Material alloc] initWithContainer:_container] autorelease]];
	_planeMeshDrawable = [[SMK_GL_Drawable alloc] initWithMesh:mesh];
	[_planeMeshDrawable setPerformsVisibilityCheck:NO];
}

@end

@implementation BaseAtlasScene (Protected)

- (id)_loader
{
	return [[[self sceneController] windowController] mapPartsLoader];
}

// drawables of all country borders of a LOD, created on first use
- (id)_allBordersForLOD:(NSInteger)aLOD
{
	if (_allBorders == nil) {
		_allBorders = [[NSMutableArray arrayWithCapacity:4] retain];
		for (int i = 0; i < 4; i++)
			[(NSMutableArray *)_allBorders addObject:[NSNull null]];
	}
	id borders = [_allBorders objectAtIndex:aLOD];
	if ([borders isEqualTo:[NSNull null]]) {
		NSArray *paths = [[AtlasDatabase database] allCountryBordersForLOD:aLOD];
		NSInteger count = [paths count];
		SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
		SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
		[material setAmbient:white];
		[material setEmission:white];
		[material setSpecular:white];
		[material setDiffuse:white];
		borders = [NSMutableArray arrayWithCapacity:count];
		[(NSMutableArray *)_allBorders replaceObjectAtIndex:aLOD withObject:borders];
		[_container beginAccumulationBlock];
		for (NSInteger i = 0; i < count; i++) {
			SMK_GL_Mesh *mesh = [self createGLMeshWidthBezierPaths:[paths objectAtIndex:i]];
			[mesh setMaterial:material];
			SMK_GL_Drawable *drawable = [SMK_GL_Drawable drawableWithMesh:mesh];
			[drawable setPerformsVisibilityCheck:YES];
			[borders addObject:drawable];
		}
		[_container endAccumulationBlock];
	}
	return borders;
}

- (id)_zoneInfoArrayWithCountry:(id)aCountry state:(id)aState timeZone:(id)aZone
{
	NSMutableArray *zones = [NSMutableArray arrayWithCapacity:4];
	if (aZone != nil)
		[zones addObject:[self _zoneDictionaryWithBoundary:aZone fillColor:_highlightTimeZoneFillColor
		                                       borderColor:_highlightTimeZoneBorderColor captionColor:_highlightCaptionTimeZoneColor]];
	if (aState != nil)
		[zones addObject:[self _zoneDictionaryWithBoundary:aState fillColor:_highlightStateFillColor
		                                       borderColor:_highlightStateBorderColor captionColor:_highlightCaptionColor]];
	if (aCountry != nil)
		[zones addObject:[self _zoneDictionaryWithBoundary:aCountry fillColor:_highlightCountryFillColor
		                                       borderColor:_highlightCountryBorderColor
		                                      captionColor:aState == nil ? _highlightCaptionColor : nil]];
	return zones;
}

- (id)_zoneDictionaryWithBoundary:(id)aBoundary fillColor:(id)aColor borderColor:(id)aColor2 captionColor:(id)aColor3
{
	NSMutableDictionary *zone = [NSMutableDictionary dictionaryWithDictionary:aBoundary];
	[zone addFillColor:aColor];
	[zone addBorderColor:aColor2];
	[zone addCaptionColor:aColor3];
	return zone;
}

@end
