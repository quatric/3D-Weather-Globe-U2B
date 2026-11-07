#import "FlatMapScene.h"


static const SMK_GL_Color _bordersColor = { 1.0f, 1.0f, 1.0f, 1.0f };
static const NSRect _bounds2D = { { -1.0, -1.0 }, { 2.0, 2.0 } };

// absolute horizontal center of a 2D rect, truncated like the original
static float _centerDistance(NSRect aRect)
{
	return (float)abs((int)((float)aRect.size.width * 0.5f + (float)aRect.origin.x));
}

@implementation FlatMapScene

- (struct WeatherGlobe_anon2)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint
{
	NSPoint point = _mapPointFromGeoPoint(aPoint);
	struct WeatherGlobe_anon2 result = { (float)point.x, 1.0f - (float)point.y, 0.0f };
	return result;
}

- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize
{
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)_camera;
	[camera setFrustumWidth:(float)aSize.width / (float)aSize.height];
	[camera setFrustumHeight:2.0];
	[self setLightDirection:[(AtlasController *)[[_controller windowController] atlasController] lightDirection]];
	[super drawSceneInContext:aContext withFrameSize:aSize];
}

- (void)drawObjectsInContext:(id)aContext
{
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_CULL_FACE);
	if (![Preferences dayNightIsEnabled]) {
		[self _drawFlatMapInContext:aContext];
	} else {
		// the separator goes to the frame buffer first and modulates the map
		[self _predrawDayNightSeparatorInContext:aContext];
		glEnable(GL_BLEND);
		glBlendFunc(GL_DST_COLOR, GL_ZERO);
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_FALSE);
		[self _drawFlatMapInContext:aContext];
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
		glDisable(GL_BLEND);
		glEnable(GL_BLEND);
		glBlendFunc(GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA);
		glDisable(GL_BLEND);
	}
	[super drawObjectsInContext:aContext];
	if ([Preferences cloudsEnabled])
		[self _drawCloudsInContext:aContext];
	if ([Preferences gridEnabled])
		[self _drawGridInContext:aContext];
	if ([Preferences doDrawAllCities])
		[self _drawAllCitiesInContext:aContext];
	if ([Preferences showAllCountryBorders])
		[self _drawAllBordersInContext:aContext];
	if ([Preferences regionHighlightIsEnabled] || [Preferences showTimeZoneEnabled])
		[self _drawZoneHiliteInContext:aContext];
	[self _drawFlatOverlaysInContext:aContext];
	if ([Preferences regionHighlightIsEnabled] || [Preferences showTimeZoneEnabled])
		[self _drawZoneHighliteCaptionsInContext:aContext];
	[self drawHighlightedCitiesInContext:aContext];
	if (_selectionRectIsVisible)
		[self drawSelectionRectInContext:aContext];
	[self drawInfoInContext:aContext];
	if ([Preferences showLocationEnabled])
		[self drawStatusLineInContext:aContext];
	[self drawOverlaysInContext:aContext];
}

// draws the drawables at the map and at its copies one map width to each side
static void _drawThreeCopies(NSArray *aDrawables, const SMK_GL_Matrix *aMatrix, id aContext)
{
	SMK_GL_Matrix offset, left, right;
	SMK_GL_Vec3 shift = { -1.0f, 0.0f, 0.0f };
	translateMatrix(&offset, &shift);
	matrix_mul(&left, aMatrix, &offset);
	shift.x = 1.0f;
	translateMatrix(&offset, &shift);
	matrix_mul(&right, aMatrix, &offset);
	NSInteger count = [aDrawables count];
	for (NSInteger i = 0; i < count; i++) {
		SMK_GL_Drawable *drawable = [aDrawables objectAtIndex:i];
		[drawable setMatrix:aMatrix];
		[drawable drawInContext:aContext];
		[drawable setMatrix:&left];
		[drawable drawInContext:aContext];
		[drawable setMatrix:&right];
		[drawable drawInContext:aContext];
	}
}

- (void)_drawAllBordersInContext:(id)aContext
{
	[aContext turnOffLighting];
	SMK_GL_Matrix matrix;
	[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect(0.0, 0.0, 1.0, 1.0)];
	glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_LINE_SMOOTH);
	glPointSize(1.1f);
	glLineWidth(1.1f);
	[aContext setColor:&_bordersColor];
	_drawThreeCopies([self _allBordersForLOD:[[self sceneController] countryBoundariesLOD]], &matrix, aContext);
	glDisable(GL_BLEND);
	glDisable(GL_LINE_SMOOTH);
	glPointSize(1.0f);
	glLineWidth(1.0f);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	[aContext turnOnLighting];
}

- (void)_drawFlatOverlaysInContext:(id)aContext
{
	SMK_GL_Drawable *routes = [Preferences showRouteLines] ? [_routePointsContainer routeDrawable] : nil;
	BOOL showsApples = [[_controller windowController] showsApples];
	if (showsApples)
		_appleStoreMarkerSize = (float)[[[_controller windowController] normalFont] maxHeight] * 0.5f;
	if (routes == nil && _routeMarkers == nil && !showsApples)
		return;
	[aContext turnOffLighting];
	NSSize size = [aContext size];
	float aspect = (float)size.width / (float)size.height;
	float firstCopy = floorf(aspect * -0.25f + (float)[_controller xPosition]);
	float lastCopy = floorf(aspect * 0.25f + (float)[_controller xPosition]);
	float scale = (float)[_controller mapScaleValue];
	if (!(scale == _prevMapScaleVal && NSEqualSizes(size, _prevContextSize))) {
		_prevMapScaleVal = scale;
		_prevContextSize = size;
		SMK_GL_Vec2 textScale = { (scale + scale) / aspect, scale };
		[_routeMarkersCaptions setScale:&textScale];
		[_routeMarkersCaptionsLayouter setPositionsScale:(struct WeatherGlobe_anon5 *)&textScale];
		struct WeatherGlobe_anon5 sizesScale = { 2.0f / (float)size.width, 2.0f / (float)size.height };
		[_routeMarkersCaptionsLayouter setSizesScale:&sizesScale];
	}
	float scale2 = scale + scale;
	SMK_GL_Matrix matrix;
	for (int i = (int)firstCopy; (float)i <= lastCopy; i++) {
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_LINE_SMOOTH);
		[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect((float)i, 1.0, 1.0, -1.0)];
		glLineWidth((float)[_controller mapScaleValue] * 0.05f + 1.0f);
		[_rivers setMatrix:&matrix];
		[_rivers drawInContext:aContext];
		glLineWidth(1.0f);
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_BLEND);
	}
	if (showsApples)
		[self drawAppleStoresInContext:aContext];
	for (int i = (int)firstCopy; (float)i <= lastCopy; i++) {
		float x = (float)i;
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_LINE_SMOOTH);
		[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect(x, 1.0, 1.0, -1.0)];
		if (routes != nil) {
			glLineWidth(2.0f);
			[routes setMatrix:&matrix];
			[routes drawInContext:aContext];
			glLineWidth(1.0f);
		}
		if (_routeMarkers != nil) {
			int pointSize = (int)((float)[Preferences markersScale] * 4.0f * ((float)[_controller mapScaleValue] * 0.02f + 0.98f));
			glEnable(GL_POINT_SMOOTH);
			[_routeMarkers setMatrix:&matrix];
			glEnable(GL_LIGHTING);
			glPointSize((float)(pointSize + 4));
			[_routeMarkers drawInContext:aContext];
			glDisable(GL_LIGHTING);
			glPointSize((float)pointSize);
			[_routeMarkers drawInContext:aContext];
			glDisable(GL_POINT_SMOOTH);
			glPointSize(1.0f);
			if ([Preferences showLocationNamesEnabled]) {
				SMK_GL_Vec2 translation = { (scale * 4.0f * ((x + 0.5f) - (float)[_controller xPosition])) / aspect,
				                            ((float)[_controller yPosition] - 0.5f) * scale2 };
				[_routeMarkersCaptions setTranslation:&translation];
				SMK_GL_Color foreColor = { 1.0f, 1.0f, 1.0f, 1.0f };
				SMK_GL_Color backColor = { 0.0f, 0.0f, 0.0f, 1.0f };
				[_routeMarkersCaptions drawInContext:aContext foreColor:&foreColor backColor:&backColor];
			}
		}
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_BLEND);
	}
	[aContext turnOnLighting];
}

- (void)_drawAllCitiesInContext:(id)aContext
{
	[self allCitiesPoints];
	[aContext turnOffLighting];
	NSSize size = [aContext size];
	float aspect = (float)size.width / (float)size.height;
	float lastCopy = floorf((float)[_controller xPosition] + aspect * 0.25f);
	float firstCopy = floorf(aspect * -0.25f + (float)[_controller xPosition]);
	SMK_GL_Matrix matrix;
	for (int i = (int)firstCopy; (float)i <= lastCopy; i++) {
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_LINE_SMOOTH);
		[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect((float)i, 1.0, 1.0, -1.0)];
		glEnable(GL_POINT_SMOOTH);
		[_allCitiesPoints setMatrix:&matrix];
		int pointSize = (int)((float)[_controller mapScaleValue] / 3.0f + 0.667f);
		if (pointSize > 5)
			pointSize = 5;
		SMK_GL_Material *material = [(SMK_GL_Mesh *)[_allCitiesPoints mesh] material];
		SMK_GL_Color outline = { 0.0f, 0.0f, 0.0f, 1.0f };
		[material setAmbient:outline];
		glPointSize((float)(pointSize + 2));
		[_allCitiesPoints drawInContext:aContext];
		SMK_GL_Color fill = { 1.0f, 1.0f, 0.4f, 1.0f };
		[material setAmbient:fill];
		glPointSize((float)pointSize);
		if (pointSize < 2)
			glDisable(GL_POINT_SMOOTH);
		[_allCitiesPoints drawInContext:aContext];
		glPointSize(1.0f);
		glDisable(GL_POINT_SMOOTH);
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_BLEND);
	}
	[aContext turnOnLighting];
}

// caption of a geo rect at the copy of the map nearest to the view center
- (BOOL)_drawCaption:(NSString *)aName forGeoRect:(NSRect)aRect inContext:(id)aContext
{
	NSRect rect = [_controller rect2DFromWorldRect:_mapRectFromGeoRect(aRect)];
	NSRect shifted = aRect;
	shifted.origin.x = (float)aRect.origin.x - 360.0f;
	NSRect left = [_controller rect2DFromWorldRect:_mapRectFromGeoRect(shifted)];
	shifted.origin.x = (float)aRect.origin.x + 360.0f;
	NSRect right = [_controller rect2DFromWorldRect:_mapRectFromGeoRect(shifted)];
	float leftDistance = _centerDistance(left);
	float rightDistance = _centerDistance(right);
	float nearest = MIN(MIN(leftDistance, _centerDistance(rect)), rightDistance);
	BOOL drawn = [self _drawInContext:aContext countryCaption:aName in2DRect:rect];
	if (nearest == leftDistance)
		drawn |= [self _drawInContext:aContext countryCaption:aName in2DRect:left];
	else if (nearest == rightDistance)
		drawn |= [self _drawInContext:aContext countryCaption:aName in2DRect:right];
	return drawn;
}

- (void)_drawZoneHighliteCaptionsInContext:(id)aContext
{
	NSArray *drawables = [_zoneHiliter glDrawableObjects];
	if (drawables == nil || [drawables count] == 0)
		return;
	[aContext pushStateComponents:0xffff];
	NSArray *dictionaries = [_zoneHiliter countryDictionaries];
	NSArray *captionRects = [_zoneHiliter captionGeoRects];
	NSRect occupied = NSZeroRect;
	NSInteger count = [dictionaries count];
	for (NSInteger i = 0; i < count; i++) {
		id dictionary = [dictionaries objectAtIndex:i];
		NSColor *color = [dictionary captionColor];
		if (color == nil)
			continue;
		NSRect rect = [[captionRects objectAtIndex:i] rectValue];
		// stack overlapping captions upwards
		if (!NSEqualRects(occupied, NSZeroRect)) {
			while (NSIntersectsRect(rect, occupied))
				rect.origin.y = (float)rect.origin.y + (float)rect.size.height;
			occupied = NSUnionRect(occupied, rect);
		} else {
			occupied = rect;
		}
		if (!(rect.size.width > 0.0) || dictionary == nil)
			continue;
		NSString *name = [dictionary fullShapeName];
		[aContext setFont:[[_controller windowController] largeFont]];
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha:&a];
		SMK_GL_Color glColor = { (float)r, (float)g, (float)b, (float)a };
		[aContext setColor:&glColor];
		[aContext enter2DMode];
		if (![self _drawCaption:name forGeoRect:rect inContext:aContext])
			[self _drawCaption:name forGeoRect:[_zoneHiliter actualGeoRect] inContext:aContext];
		[aContext exit2DMode];
	}
	[aContext popState];
}

- (void)_drawZoneHiliteInContext:(id)aContext
{
	NSArray *drawables = [_zoneHiliter glDrawableObjects];
	if (drawables == nil || [drawables count] == 0)
		return;
	[aContext pushStateComponents:0xffff];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	SMK_GL_Matrix matrix;
	[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect(0.0, 0.0, 1.0, 1.0)];
	_drawThreeCopies(drawables, &matrix, aContext);
	glDisable(GL_BLEND);
	[aContext popState];
}

// clamps a caption hanging over the left or right view edge
- (BOOL)_drawInContext:(id)aContext countryCaption:(id)aCaption in2DRect:(NSRect)aRect
{
	NSInteger alignment;
	float x = (float)aRect.origin.x, width = (float)aRect.size.width;
	if (x < -1.0f && width + x > -1.0f) {
		alignment = 0;
		aRect.origin.x = -1.0;
	} else if (width + x > 1.0f && x < 1.0f) {
		alignment = 1;
		aRect.origin.x = 0.5;
		aRect.size.width = 0.5;
	} else {
		alignment = 2;
	}
	BOOL visible = NSIntersectsRect(aRect, _bounds2D);
	if (visible)
		[aContext drawString:aCaption inRect:aRect hAlignment:alignment vAlignment:1
		           backColor:(const SMK_GL_Color *)&_countryCaptionBackColor];
	return visible;
}

- (void)_drawGridInContext:(id)aContext
{
	[aContext turnOffLighting];
	NSSize size = [aContext size];
	float height = (float)size.height;
	float aspect = (float)size.width / height;
	float scale = (float)[_controller mapScaleValue];
	float xPosition = (float)[_controller xPosition];
	float yPosition = (float)[_controller yPosition];
	float firstCopy = floorf(aspect * -0.25f + xPosition);
	float lastCopy = floorf(xPosition + aspect * 0.25f);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	NSInteger step = [_controller degreesGridStep];
	SMK_GL_Drawable *grid;
	if (step == 5)
		grid = _gridMeshHigh;
	else if (step == 10)
		grid = _gridMeshNorm;
	else
		grid = _gridMeshLow;
	SMK_GL_Matrix matrix;
	for (int i = (int)firstCopy; (float)i <= lastCopy; i++) {
		[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect((float)i, 0.0, 1.0, 1.0)];
		[grid setMatrix:&matrix];
		[grid drawInContext:aContext];
	}
	[aContext turnOnLighting];
	SMK_GL_Color color = { 0.5f, 0.8f, 1.0f, 1.0f };
	[aContext setColor:&color];
	[aContext setFont:[[_controller windowController] smallFont]];
	[aContext enter2DMode];
	float labelOffset = (height - 35.0f) / height;
	for (int longitude = (int)(firstCopy * 360.0f - 180.0f); longitude < (int)((lastCopy + 1.0f) * 360.0f - 180.0f); longitude += (int)step) {
		float x = ((float)longitude / 180.0f + 1.0f + xPosition * -2.0f) * scale;
		x = (x + x) / aspect;
		if (x < -1.05f || x > 1.0f)
			continue;
		float turns = (float)longitude / 360.0f + 0.5f;
		int label = (int)round(((double)(turns - floorf(turns)) - 0.5) * 360.0);
		[aContext drawString:[NSString stringWithFormat:@"%d", label] atPosition:NSMakePoint(x, labelOffset)];
	}
	for (int latitude = -90; latitude < 90; latitude += (int)step) {
		float y = (((float)latitude / 90.0f - 1.0f) + yPosition + yPosition) * scale;
		if (y >= -1.0f && y <= 1.0f)
			[aContext drawString:[NSString stringWithFormat:@"%d", latitude] atPosition:NSMakePoint(labelOffset, y)];
	}
	[aContext exit2DMode];
	glDisable(GL_BLEND);
}

- (void)_drawCloudsInContext:(id)aContext
{
	CloudsMaterial *clouds = [[_controller windowController] cloudsMaterial];
	[clouds checkCloudsTextures];
	if (![clouds hasTexturesForEast] || ![clouds hasTexturesForWest])
		return;
	[clouds setLightingEnabled:NO];
	SMK_GL_Mesh *mesh = [_planeMeshDrawable mesh];
	SMK_GL_Material *savedMaterial = [[[mesh material] retain] autorelease];
	[mesh setMaterial:clouds];
	NSSize size = [aContext size];
	float aspect = (float)size.width / (float)size.height;
	float last = (float)[_controller xPosition] + aspect * 0.25f;
	last = floorf(last + last);
	float first = (float)[_controller xPosition] + aspect * -0.25f;
	first = floorf(first + first);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	SMK_GL_Matrix matrix;
	for (int i = (int)first; (float)i <= last; i++) {
		[self _setupMatrix:(struct WeatherGlobe_anon3 *)&matrix toDisplayFlatMeshInRect:NSMakeRect((float)i * 0.5f, 1.0, 0.5, -1.0)];
		[_planeMeshDrawable setMatrix:&matrix];
		[clouds setIsEastBinding:(i % 2) != 0];
		[_planeMeshDrawable drawInContext:aContext];
	}
	glDisable(GL_BLEND);
	[mesh setMaterial:savedMaterial];
}

- (void)_drawFlatMapInContext:(id)aContext
{
	float xPosition = (float)[_controller xPosition] + 1.0f;
	float yPosition = (float)[_controller yPosition];
	float scale = (float)[_controller mapScaleValue];
	NSSize size = [aContext size];
	float pixels = scale * (float)size.height;
	int lod;
	float tiles;
	if (pixels < 2048.0f) {
		tiles = 1.0f;
		lod = 0;
	} else if (pixels < 6144.0f) {
		tiles = 3.0f;
		lod = 1;
	} else if (pixels < 12288.0f) {
		tiles = 9.0f;
		lod = 2;
	} else {
		tiles = 18.0f;
		lod = 3;
	}
	float tileScale = scale / tiles;
	static const float tileWidths[4] = { 0.5f, 0.16666667f, 0.055555556f, 0.027777778f };
	static const float tileHeights[4] = { 1.0f, 0.33333334f, 0.11111111f, 0.055555556f };
	float tileWidth = tileWidths[lod];
	float tileHeight = tileHeights[lod];
	float halfWidth = (((float)size.width / (float)size.height) * 0.5f) / scale;
	int firstX = (int)((halfWidth * -0.5f + xPosition + 1e-05f) / tileWidth);
	int lastX = (int)(((halfWidth * 0.5f + xPosition) - 1e-05f) / tileWidth);
	int firstY = (int)(((1.0f / scale) * -0.5f + yPosition + 1e-05f) / tileHeight);
	int lastY = (int)((((1.0f / scale) * 0.5f + yPosition) - 1e-05f) / tileHeight);
	[[self _loader] disable_cache_updates];
	[self _startFrameDrawingWithLOD:lod xStart:firstX xEnd:lastX yStart:firstY yEnd:lastY];
	SMK_GL_Vec3 axis = { 1.0f, 0.0f, 0.0f };
	SMK_GL_Matrix rotation;
	rotateMatrix(&rotation, -1.5707964f, &axis);
	SMK_GL_Material *material = [(SMK_GL_Mesh *)[_planeMeshDrawable mesh] material];
	for (int y = firstY; y <= lastY; y++) {
		float tileY = tileHeight * (float)y - yPosition;
		for (int x = firstX; x <= lastX; x++) {
			SMK_GL_Matrix placement, matrix;
			matrix_make_identity(&placement);
			float tileX = (float)x * tileWidth - xPosition;
			placement._14 = (tileX + tileX) * scale;
			placement._11 = tileScale;
			placement._22 = tileScale + tileScale;
			placement._24 = scale * (tileY + tileY);
			matrix_mul(&matrix, &rotation, &placement);
			[_planeMeshDrawable setMatrix:&matrix];
			struct WeatherGlobe_anon5 translation, scaling;
			SMK_GL_2DTexture *texture = [self textureForLod:lod xPos:x yPos:y translation:&translation scaling:&scaling];
			[material setTexture:texture atStage:0];
			SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
			[material setAmbient:white];
			SMK_GL_Vec3 textureScale = { 1.0f / scaling.f0, 1.0f / scaling.f1, 1.0f };
			SMK_GL_Matrix textureMatrix;
			scaleMatrix(&textureMatrix, &textureScale);
			textureMatrix._14 = translation.f0;
			textureMatrix._24 = translation.f1;
			[texture setTransformMatrix:&textureMatrix];
			[_planeMeshDrawable drawInContext:aContext];
		}
	}
	[[self _loader] enable_cache_updates];
}

- (void)_setupMatrix:(struct WeatherGlobe_anon3 *)aMatrix toDisplayFlatMeshInRect:(NSRect)aRect
{
	float xPosition = (float)[_controller xPosition];
	float yPosition = (float)[_controller yPosition];
	float scale = (float)[_controller mapScaleValue];
	NSRect rect = NSOffsetRect(aRect, -(xPosition - floorf(xPosition)), -yPosition);
	float scale2 = scale + scale;
	SMK_GL_Vec3 axis = { 1.0f, 0.0f, 0.0f };
	SMK_GL_Matrix rotation, placement;
	rotateMatrix(&rotation, -1.5707964f, &axis);
	matrix_make_identity(&placement);
	placement._11 = scale2 * (float)rect.size.width;
	placement._22 = scale2 * (float)rect.size.height;
	placement._14 = scale2 * (float)rect.origin.x;
	placement._24 = scale2 * (float)rect.origin.y;
	matrix_mul((SMK_GL_Matrix *)aMatrix, &rotation, &placement);
}

- (void)_predrawDayNightSeparatorInContext:(id)aContext
{
	[self _recalcSeparatorNormalsIfNeeded];
	[aContext turnOffLighting];
	glDisable(GL_LIGHTING);
	NSRect frame = [[[_controller windowController] glView] frame];
	SMK_GL_Vec3 axis = { 1.0f, 0.0f, 0.0f };
	SMK_GL_Matrix matrix;
	rotateMatrix(&matrix, 1.5707964f, &axis);
	matrix._11 = (((float)frame.size.width * 0.5f) / (float)frame.size.height) * matrix._11;
	[_dayNightSeparator setMatrix:&matrix];
	[_dayNightSeparator drawInContext:aContext];
	[aContext turnOnLighting];
}

// marks the textures this frame uses and loads the missing ones, reusing
// unused textures before creating new ones
- (void)_startFrameDrawingWithLOD:(NSInteger)aLOD xStart:(NSInteger)aStart xEnd:(NSInteger)aEnd yStart:(NSInteger)aStart2 yEnd:(NSInteger)aEnd2
{
	NSArray *entries = [_currentTextures allValues];
	NSInteger count = [entries count];
	for (NSInteger i = 0; i < count; i++)
		[[entries objectAtIndex:i] removeObjectForKey:kTextureWillBeUsedKey];
	NSMutableArray *missing = [NSMutableArray array];
	for (NSInteger y = aStart2; y <= aEnd2; y++) {
		for (NSInteger x = aStart; x <= aEnd; x++) {
			NSString *path = [MapPartsLoader pathForMapTextureForLOD:aLOD xPos:x yPos:y];
			NSMutableDictionary *entry = [_currentTextures objectForKey:path];
			if (entry == nil) {
				path = [[self _loader] nearestCachedLowResPathForLOD:aLOD xPos:x yPos:y translation:NULL scaling:NULL];
				entry = [_currentTextures objectForKey:path];
				if (entry == nil) {
					[missing addObject:[NSNumber numberWithInt:(int)((x & 0xffff) + y * 0x10000)]];
					continue;
				}
			}
			[entry setObject:[NSNumber numberWithBool:YES] forKey:kTextureWillBeUsedKey];
		}
	}
	count = [missing count];
	BOOL noUnusedTextures = NO;
	for (NSInteger i = 0; i < count; i++) {
		int packed = [[missing objectAtIndex:i] intValue];
		int x = packed & 0xffff;
		int y = (unsigned)packed >> 16;
		NSString *path = [[self _loader] nearestCachedLowResPathForLOD:aLOD xPos:x yPos:y translation:NULL scaling:NULL];
		if (path == nil)
			path = [MapPartsLoader pathForMapTextureForLOD:aLOD xPos:x yPos:y];
		if ([_currentTextures objectForKey:path] == nil) {
			BOOL reused = NO;
			if (!noUnusedTextures) {
				NSArray *values = [_currentTextures allValues];
				NSArray *keys = [_currentTextures allKeys];
				NSInteger valuesCount = [values count];
				for (NSInteger j = 0; j < valuesCount; j++) {
					NSMutableDictionary *entry = [values objectAtIndex:j];
					if ([[entry objectForKey:kTextureWillBeUsedKey] boolValue])
						continue;
					if (entry != nil) {
						[[entry retain] autorelease];
						[_currentTextures removeObjectForKey:[keys objectAtIndex:j]];
						[[self _loader] fillTexture:[entry objectForKey:k2DTextureKey] withContentsOfFile:path];
						[_currentTextures setObject:entry forKey:path];
						reused = YES;
					}
					break;
				}
				if (!reused)
					noUnusedTextures = YES;
			}
			if (!reused) {
				id texture = [[self _loader] createTextureWithContentsOfFile:path container:_container flags:0 usage:1 withMaxBitDepth:NO];
				if (texture != nil) {
					NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithObject:texture forKey:k2DTextureKey];
					if (entry != nil)
						[_currentTextures setObject:entry forKey:path];
				}
			}
		}
		[[_currentTextures objectForKey:path] setObject:[NSNumber numberWithBool:YES] forKey:kTextureWillBeUsedKey];
	}
}

- (id)routePathsMesh
{
	return [[_routePointsContainer routeDrawable] mesh];
}

- (id)routeMarkersMesh
{
	return [_routeMarkers mesh];
}

- (void)recalculateCountryHilite
{
	if ([_zoneHiliter isDisabled])
		return;
	NSArray *dictionaries = [[_zoneHiliter countryDictionaries] retain];
	[_zoneHiliter disable];
	[(FlatMapCountryHiliter *)_zoneHiliter rebuildForCountryDictionaries:dictionaries mapXPosition:(float)[_controller xPosition]
	                                                       mapYPosition:(float)[_controller yPosition]
	                                                         scaleValue:(float)[_controller mapScaleValue] flags:3];
	[dictionaries release];
}

- (void)highlightCountry:(id)aCountry state:(id)aState timeZone:(id)aZone
{
	BOOL countries = [Preferences regionHighlightIsEnabled] &&
	                 ([Preferences regionHighLightMode] == 0 || [Preferences regionHighLightMode] == 1);
	BOOL states = [Preferences regionHighlightIsEnabled] &&
	              ([Preferences regionHighLightMode] == 0 || [Preferences regionHighLightMode] == 2);
	BOOL timeZones = [Preferences showTimeZoneEnabled];
	if (!countries)
		aCountry = nil;
	if (!states)
		aState = nil;
	if (!timeZones)
		aZone = nil;
	[super highlightCountry:aCountry state:aState timeZone:aZone];
	NSArray *zones = [self _zoneInfoArrayWithCountry:aCountry state:aState timeZone:aZone];
	[(FlatMapCountryHiliter *)_zoneHiliter rebuildForCountryDictionaries:zones mapXPosition:(float)[_controller xPosition]
	                                                       mapYPosition:(float)[_controller yPosition]
	                                                         scaleValue:(float)[_controller mapScaleValue] flags:3];
}

// shades the separator mesh's vertex colours by the sun's height
- (void)_recalcSeparatorNormalsIfNeeded
{
	if (_separatorNormalsAreOK)
		return;
	_separatorNormalsAreOK = YES;
	NSRect frame = [[[_controller windowController] glView] frame];
	float aspect = ((float)frame.size.width * 0.5f) / (float)frame.size.height;
	float inverseScale = 1.0f / (float)[_controller mapScaleValue];
	float viewWidth = aspect * inverseScale;
	float bottom = (float)[_controller yPosition] - inverseScale * 0.5f;
	float left = (float)[_controller xPosition] - aspect * inverseScale * 0.5f;
	SMK_GL_VertexBuffer *vertexBuffer = [(SMK_GL_Mesh *)[_dayNightSeparator mesh] vertexBuffer];
	float *vertex = [vertexBuffer lock:0];
	NSInteger count = [(SMK_GL_Mesh *)[_dayNightSeparator mesh] verticesCount];
	float factor = (float)[_controller mapScaleValue] * 0.5f + 3.0f;
	float lightX = -_lightDirection.x, lightY = -_lightDirection.y, lightZ = -_lightDirection.z;
	float cachedLatitude = -10.0f, cosLatitude = 0.0f, sinLatitude = 0.0f;
	// vertices are x, y, z and a packed colour; two per step
	for (NSInteger i = 0; i < count; i += 2, vertex += 8) {
		float latitude0 = (((vertex[1] * -0.5f + 0.5f) * inverseScale + bottom) - 0.5f) * 3.1415927f;
		float latitude1 = (((vertex[5] * -0.5f + 0.5f) * inverseScale + bottom) - 0.5f) * 3.1415927f;
		if (cachedLatitude != latitude0) {
			cosLatitude = cosf(latitude0);
			sinLatitude = sinf(latitude0);
			cachedLatitude = latitude0;
		}
		float cosLatitude1, sinLatitude1;
		if (cachedLatitude != latitude1) {
			cosLatitude1 = cosf(latitude1);
			sinLatitude1 = sinf(latitude1);
		} else {
			cosLatitude1 = cosLatitude;
			sinLatitude1 = sinLatitude;
		}
		double longitude0 = (double)((left + (vertex[0] * 0.5f + 0.5f) * viewWidth) * 6.2831855f);
		double longitude1 = (double)((left + (vertex[4] * 0.5f + 0.5f) * viewWidth) * 6.2831855f);
		float light0 = 0.25f - ((float)cos(longitude0) * cosLatitude * lightX + cosLatitude * (float)sin(longitude0) * lightY +
		                        sinLatitude * lightZ) * factor;
		float light1 = 0.25f - ((float)cos(longitude1) * cosLatitude1 * lightX + cosLatitude1 * (float)sin(longitude1) * lightY +
		                        sinLatitude1 * lightZ) * factor;
		light0 = light0 > 1.0f ? 255.0f : (light0 >= 0.25f ? light0 * 255.0f : 63.75f);
		light1 = light1 > 1.0f ? 255.0f : (light1 >= 0.25f ? light1 * 255.0f : 63.75f);
		uint32_t value0 = (uint32_t)(light0 <= 0.0f ? 0.0f : light0);
		uint32_t value1 = (uint32_t)(light1 <= 0.0f ? 0.0f : light1);
		((uint32_t *)vertex)[3] = value0 << 8 | value0 << 16 | value0 << 24 | value0;
		((uint32_t *)vertex)[7] = value1 << 8 | value1 << 16 | value1 << 24 | value1;
	}
	[vertexBuffer unlock];
}

- (void)setLightDirection:(struct WeatherGlobe_anon2)aDirection
{
	_lightDirection.x = aDirection.f0;
	_lightDirection.y = aDirection.f1;
	_lightDirection.z = aDirection.f2;
	_separatorNormalsAreOK = NO;
}

- (void)invalidateDayNightSeparator
{
	_separatorNormalsAreOK = NO;
}

- (void)distCalcSetChangedTo:(id)aTo
{
	[_routeMarkers release];
	_routeMarkers = nil;
	[_recordedCaptionIDs release];
	_recordedCaptionIDs = nil;
	NSInteger count = [aTo count];
	if (count == 0) {
		[_routePointsContainer adjustToRoutePointsArray:nil];
		[_routeMarkersCaptions beginRecordBlockWithLayouterOptions:0];
		[_routeMarkersCaptions endRecordBlock];
		return;
	}
	if (_routeMarkersCaptions == nil) {
		_routeMarkersCaptionsLayouter = [[CaptionsLayouter alloc] init];
		[_routeMarkersCaptionsLayouter setMarkerRadius:0.01];
		[_routeMarkersCaptionsLayouter setSmartLayoutTime:0.05];
		[_routeMarkersCaptionsLayouter setNeedLayout:YES];
		_routeMarkersCaptions = [[SMK_GL_StaticText alloc] initWithContainer:_container glFont:[[_controller windowController] normalFont]];
		[_routeMarkersCaptions setLayouter:_routeMarkersCaptionsLayouter];
		[self _invalStaticTextsScaling];
	}
	[_routeMarkersCaptions beginRecordBlockWithLayouterOptions:2];
	NSMutableData *points = [NSMutableData dataWithLength:count * sizeof(struct WeatherGlobe_anon8)];
	struct WeatherGlobe_anon8 *point = [points mutableBytes];
	NSMutableSet *recorded = [NSMutableSet set];
	_recordedCaptionIDs = [NSMutableArray new];
	for (NSInteger i = 0; i < count; i++, point++) {
		id entry = [aTo objectAtIndex:i];
		struct WeatherGlobe_anon2 *vector = [entry vectorFromEarthCenter];
		point->f0 = *vector;
		point->f1 = *[entry cityMarkerColor];
		if ([recorded containsObject:entry])
			continue;
		[recorded addObject:entry];
		NSPoint mapPoint = _mapPointFromGeoPoint([entry coordinates]);
		SMK_GL_Vec2 position = { (float)mapPoint.x * 2.0f - 1.0f, (float)mapPoint.y * 2.0f - 1.0f };
		[(NSMutableArray *)_recordedCaptionIDs addObject:[_routeMarkersCaptions recordCaption:[entry ownName] atPosition:&position]];
	}
	[_routeMarkersCaptions endRecordBlock];
	if (_routePointsContainer == nil)
		_routePointsContainer = [[FlatRoutePointsContainer alloc] initWithGLContainer:_container];
	[_routePointsContainer adjustToRoutePointsArray:points];

	[_container beginAccumulationBlock];
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:0x42 usage:0 verticesCount:count
	                                            primitivesCount:count primitiveType:0] autorelease];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 0.3f, 0.3f, 0.3f, 1.0f };
	SMK_GL_Color diffuse = { 0.0f, 0.0f, 0.0f, 1.0f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	float *vertex = [vertexBuffer lock:0];
	point = [points mutableBytes];
	for (NSInteger i = 0; i < count; i++, point++, vertex += 4) {
		NSPoint mapPoint = _mapPointFromEarthVec((const SMK_GL_Vec3 *)&point->f0);
		vertex[0] = (float)mapPoint.x;
		vertex[1] = (float)mapPoint.y;
		vertex[2] = 0.0f;
		float r = point->f1.f0 * 255.0f, g = point->f1.f1 * 255.0f, b = point->f1.f2 * 255.0f;
		unsigned char *color = (unsigned char *)&vertex[3];
		color[0] = (unsigned char)(unsigned)(r <= 0.0f ? 0.0f : r);
		color[1] = (unsigned char)(unsigned)(g <= 0.0f ? 0.0f : g);
		color[2] = (unsigned char)(unsigned)(b <= 0.0f ? 0.0f : b);
		color[3] = 0xff;
	}
	[vertexBuffer unlock];
	_routeMarkers = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	[_routeMarkers setPerformsVisibilityCheck:NO];
	[_container endAccumulationBlock];
	[_controller refreshAnimationFlag];
}

- (void)_invalStaticTextsScaling
{
	_prevContextSize = NSZeroSize;
}

- (id)routePointsContainer
{
	return _routePointsContainer;
}

- (id)sceneController
{
	return _controller;
}

- (void)dealloc
{
	[_dayNightSeparator release];
	[_gridMeshLow release];
	[_gridMeshNorm release];
	[_gridMeshHigh release];
	[_rivers release];
	[_routePointsContainer release];
	[_routeMarkers release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer controller:(id)aController
{
	self = [super initWithContainer:aContainer];
	if (self == nil)
		return nil;
	_controller = aController;
	[self setCamera:[[[SMK_GL_OrthoCamera alloc] init] autorelease]];
	SMK_GL_Vec3 position = { 0.0f, -10.0f, 0.0f };
	[(SMK_GL_Camera *)_camera setPosition:&position];
	SMK_GL_Vec3 axis = { 1.0f, 0.0f, 0.0f };
	SMK_GL_Matrix matrix;
	rotateMatrix(&matrix, 1.5707964f, &axis);
	[_container beginAccumulationBlock];
	[self _createDayNightSeparator];
	[_dayNightSeparator setMatrix:&matrix];
	[self _createCountryHiliter];
	[self _createGridObjects];
	[self _createRivers];
	[_container endAccumulationBlock];
	return self;
}

- (void)fillVerticesWithAllCitiesInVB:(struct WeatherGlobe_anon4 *)aVB
{
	NSData *points = [[AtlasDatabase database] allCityPointsArray];
	NSUInteger count = [points length] >> 3;
	const float *point = [points bytes];
	for (NSUInteger i = 0; i < count; i++, point += 2, aVB++) {
		NSPoint mapPoint = _mapPointFromGeoPoint(NSMakePoint(point[0], point[1]));
		aVB->f0.f0 = (float)mapPoint.x;
		aVB->f0.f1 = (float)mapPoint.y;
		aVB->f0.f2 = 0.0f;
	}
}

- (void)_createRivers
{
}

- (void)_createCountryHiliter
{
	_zoneHiliter = [[FlatMapCountryHiliter alloc] initWithContainer:_container panelController:[self sceneController]
	                                                     captionFont:[NSFont boldSystemFontOfSize:16.0] storagePart:0];
}

- (void)_createGridObjects
{
	_gridMeshLow = [[SMK_GL_Drawable drawableWithMesh:[self _createFlatGridWithXSegs:18 ySegs:9]] retain];
	_gridMeshNorm = [[SMK_GL_Drawable drawableWithMesh:[self _createFlatGridWithXSegs:36 ySegs:18]] retain];
	_gridMeshHigh = [[SMK_GL_Drawable drawableWithMesh:[self _createFlatGridWithXSegs:72 ySegs:36]] retain];
}

// a line list of the unit square's meridians and parallels
- (id)_createFlatGridWithXSegs:(NSInteger)aSegs ySegs:(NSInteger)aSegs2
{
	NSInteger vertexCount = (aSegs + aSegs2) * 2 + 4;
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:2 usage:0 verticesCount:vertexCount
	                                            primitivesCount:aSegs + aSegs2 + 2 primitiveType:1] autorelease];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 0.2f, 0.3f, 0.5f, 0.2f };
	SMK_GL_Color diffuse = { 0.0f, 0.0f, 0.0f, 0.2f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	[vertexBuffer setAutoUpdateBounds:YES];
	float *vertex = [vertexBuffer lock:0];
	for (NSInteger i = 0; i <= aSegs; i++, vertex += 6) {
		float x = (float)i / (float)aSegs;
		vertex[0] = x; vertex[1] = 0.0f; vertex[2] = 0.0f;
		vertex[3] = x; vertex[4] = 1.0f; vertex[5] = 0.0f;
	}
	for (NSInteger i = 0; i <= aSegs2; i++, vertex += 6) {
		float y = (float)i / (float)aSegs2;
		vertex[0] = 0.0f; vertex[1] = y; vertex[2] = 0.0f;
		vertex[3] = 1.0f; vertex[4] = y; vertex[5] = 0.0f;
	}
	[vertexBuffer unlock];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	NSAssert(![indexBuffer are32BitIndices], @"Index buffer must be in 16-bit format");
	uint16_t *indices = [indexBuffer lock:0];
	for (NSInteger i = 0; i < vertexCount; i++)
		indices[i] = (uint16_t)i;
	[indexBuffer unlock];
	return mesh;
}

- (void)_createDayNightSeparator
{
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(-1.0, -1.0, 2.0, 2.0) xSegments:64 ySegments:32
	                                              container:_container fvf:0x42 usage:1];
	[mesh setMaterial:[[[SMK_GL_Material alloc] initWithContainer:_container] autorelease]];
	_dayNightSeparator = [[SMK_GL_Drawable alloc] initWithMesh:mesh];
	_lightDirection.x = 0.0f;
	_lightDirection.y = 0.3f;
	_lightDirection.z = 0.954f;
}

@end
