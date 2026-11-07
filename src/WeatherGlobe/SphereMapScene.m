#import "SphereMapScene.h"

#include <OpenGL/glu.h>

static const SMK_GL_Color _bordersColor = { 1.0f, 1.0f, 1.0f, 1.0f };
static const SMK_GL_Color _captionColor = { 1.0f, 1.0f, 1.0f, 1.0f };
static const SMK_GL_Color _backCaptionColor = { 0.0f, 0.0f, 0.0f, 1.0f };
static const SMK_GL_Vec3 _northVector = { 0.0f, 0.0f, 1.0f };
static const NSRect _bounds2D = { { -1.0, -1.0 }, { 2.0, 2.0 } };

// lens flares: four rows of four, each with an offset along the line from
// the view center to the sun, a size and a colour
static const float _kFlarePositions[4][4] = {
	{ 1.7f, 1.5f, 1.3f, 1.01f },
	{ 1.0f, 1.0f, 0.55f, 0.5f },
	{ 0.45f, 0.3f, -0.2f, -0.3f },
	{ -0.35f, -0.45f, -0.7f, -0.85f },
};
static const float _kFlareSizes[4][4] = {
	{ 5.0f, 2.0f, 0.2f, 0.8f },
	{ 3.0f, 4.0f, 0.1f, 0.3f },
	{ 0.2f, 0.1f, 0.05f, 0.2f },
	{ 0.35f, 0.15f, 0.8f, 1.0f },
};
static const SMK_GL_Color _kFlareColors[4][4] = {
	{ { 0.2f, 0.15f, 0.15f, 1.0f }, { 0.25f, 0.2f, 0.1f, 1.0f }, { 0.3f, 0.3f, 0.1f, 1.0f }, { 0.2f, 0.1f, 0.0f, 1.0f } },
	{ { 0.8f, 0.9f, 1.0f, 1.0f }, { 1.0f, 0.9f, 0.8f, 1.0f }, { 0.1f, 0.25f, 0.4f, 1.0f }, { 0.1f, 0.25f, 0.4f, 1.0f } },
	{ { 0.1f, 0.2f, 0.4f, 1.0f }, { 0.2f, 0.3f, 0.1f, 1.0f }, { 0.6f, 0.4f, 0.2f, 1.0f }, { 0.35f, 0.25f, 0.1f, 1.0f } },
	{ { 0.35f, 0.25f, 0.2f, 1.0f }, { 0.25f, 0.25f, 0.3f, 1.0f }, { 0.1f, 0.2f, 0.3f, 1.0f }, { 0.1f, 0.15f, 0.05f, 1.0f } },
};

// a pin on the globe: its placement and colour; jumping pins keep their
// earth vector in the colour's rgb and their bounce phase in its alpha
typedef struct _PinMarker {
	SMK_GL_Matrix matrix;
	SMK_GL_Color color;
} _PinMarker;

// segments around the globe and rows of the globe parts at each LOD
static const int _partsSegments[4] = { 2, 6, 18, 36 };
static const int _partsRows[4] = { 1, 3, 9, 18 };

// the meridian slot a part column is drawn at
static int _partSlot(int aColumn, int aSegments)
{
	int half = aSegments / 2;
	return aColumn - half >= 0 ? aColumn - half : aColumn + half;
}

@implementation SphereMapScene

- (SMK_GL_Drawable **)_globePartsForLOD:(NSInteger)aLOD
{
	switch (aLOD) {
	case 0:
		return _globeParts0;
	case 1:
		return _globeParts1;
	case 2:
		return _globeParts2;
	default:
		return _globeParts3;
	}
}

- (void)drawObjectsInContext:(id)aContext
{
	glDisable(GL_DEPTH_TEST);
	[self _drawStarsInContext:aContext];
	struct WeatherGlobe_anon2 moonDirection = [(AtlasController *)[[_controller windowController] atlasController] moonDirection];
	_moonPosition.x = moonDirection.f0 * _moonOrbitRadius;
	_moonPosition.y = moonDirection.f1 * _moonOrbitRadius;
	_moonPosition.z = moonDirection.f2 * _moonOrbitRadius;
	float phase = (float)[(AtlasController *)[[_controller windowController] atlasController] moonPhase];
	_moonRotation = phase * 3.1415927f + phase * 3.1415927f + 0.37699112f;
	SMK_GL_Vec3 viewDirection;
	[(SMK_GL_Camera *)_camera getViewDirection:&viewDirection];
	BOOL moonIsBehind = _moonPosition.x * viewDirection.x + _moonPosition.y * viewDirection.y + _moonPosition.z * viewDirection.z > 0.0f;
	if ([Preferences moonEnabled] && moonIsBehind)
		[self _drawMoonInContext:aContext];
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	[self _drawGlobeInContext:aContext];
	if ([Preferences dayNightIsEnabled]) {
		// city lights on the night side, both hemispheres
		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_COLOR, GL_ONE);
		SMK_GL_Mesh *mesh = [_earthHemisphere mesh];
		SMK_GL_Material *savedMaterial = [[[mesh material] retain] autorelease];
		[(SMK_GL_Mesh *)[_earthHemisphere mesh] setMaterial:_cityGlowsMaterial];
		SMK_GL_Vec3 sunDirection = [_sunLight direction];
		SMK_GL_Vec3 reversed = { -sunDirection.x, -sunDirection.y, -sunDirection.z };
		[_sunLight setDirection:reversed];
		[_sunLight setupLightInContext:aContext];
		SMK_GL_Matrix matrix;
		matrix_make_identity(&matrix);
		[_earthHemisphere setMatrix:&matrix];
		SMK_GL_2DTexture *night = [[self _loader] nightTextureForContainer:_container isEast:YES];
		[night setCombinerMode:GL_MODULATE];
		[night setCombinerAlphaMode:GL_MODULATE];
		[night setCombinerRGBScale:1];
		[_cityGlowsMaterial setTexture:night atStage:0];
		[_earthHemisphere drawInContext:aContext];
		SMK_GL_Vec3 axis = { 0.0f, 0.0f, 1.0f };
		rotateMatrix(&matrix, 3.1415927f, &axis);
		[_earthHemisphere setMatrix:&matrix];
		night = [[self _loader] nightTextureForContainer:_container isEast:NO];
		[night setCombinerMode:GL_MODULATE];
		[night setCombinerAlphaMode:GL_MODULATE];
		[night setCombinerRGBScale:1];
		[_cityGlowsMaterial setTexture:night atStage:0];
		[_earthHemisphere drawInContext:aContext];
		[(SMK_GL_Mesh *)[_earthHemisphere mesh] setMaterial:savedMaterial];
		glDisable(GL_BLEND);
		[_sunLight setDirection:sunDirection];
		[_sunLight setupLightInContext:aContext];
	}
	if ([Preferences cloudsEnabled])
		[self _drawCloudsInContext:aContext];
	glDisable(GL_CULL_FACE);
	if ([Preferences doDrawAllCities]) {
		glEnable(GL_DEPTH_TEST);
		glDepthMask(GL_FALSE);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glEnable(GL_LINE_SMOOTH);
		glEnable(GL_POINT_SMOOTH);
		glPointSize(1.0f);
		glDisable(GL_POINT_SMOOTH);
		[[self allCitiesPoints] drawInContext:aContext];
		glPointSize(1.0f);
		glDisable(GL_POINT_SMOOTH);
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_BLEND);
		glDisable(GL_DEPTH_TEST);
		glDepthMask(GL_TRUE);
	}
	if ([Preferences showAllCountryBorders])
		[self _drawAllBordersInContext:aContext];
	if ([Preferences regionHighlightIsEnabled] || [Preferences showTimeZoneEnabled])
		[self _drawZoneHiliteInContext:aContext];
	[self drawRouteAndGvozdixinContext:aContext];
	if ([Preferences regionHighlightIsEnabled] || [Preferences showTimeZoneEnabled])
		[self _drawZoneHighliteCaptionsInContext:aContext];
	[self _drawGlowInContext:aContext];
	if ([Preferences earthTiltedMode]) {
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_LINE_SMOOTH);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE);
		glLineWidth(1.2f);
		[aContext turnOffLighting];
		[_OSDrawable drawInContext:aContext];
		[aContext turnOnLighting];
		glLineWidth(1.0f);
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_BLEND);
	}
	[self drawHighlightedCitiesInContext:aContext];
	if ([Preferences moonEnabled] && !moonIsBehind)
		[self _drawMoonInContext:aContext];
	if ([Preferences sunEnabled])
		[self _drawSunGlowAtPosition:(struct WeatherGlobe_anon2 *)&_sunScreenPos inContext:aContext];
	if (_selectionRectIsVisible)
		[self drawSelectionRectInContext:aContext];
	[self drawInfoInContext:aContext];
	if ([Preferences showLocationEnabled])
		[self drawStatusLineInContext:aContext];
	[self drawOverlaysInContext:aContext];
}

// clips everything behind the plane through the globe center facing the viewer
static void _enableFrontHalfClipping(SMK_GL_Camera *aCamera)
{
	SMK_GL_Vec3 viewDirection;
	[aCamera getViewDirection:&viewDirection];
	GLdouble equation[4] = { -viewDirection.x, -viewDirection.y, -viewDirection.z, 0.0 };
	glClipPlane(GL_CLIP_PLANE0, equation);
	glEnable(GL_CLIP_PLANE0);
}

- (void)_drawAllBordersInContext:(id)aContext
{
	[aContext turnOffLighting];
	_enableFrontHalfClipping((SMK_GL_Camera *)_camera);
	glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_LINE_SMOOTH);
	glPointSize(1.1f);
	glLineWidth(1.1f);
	[aContext setColor:&_bordersColor];
	NSArray *borders = [self _allBordersForLOD:[_controller countryBoundariesLOD]];
	NSInteger count = [borders count];
	for (NSInteger i = 0; i < count; i++)
		[[borders objectAtIndex:i] drawInContext:aContext];
	glDisable(GL_BLEND);
	glDisable(GL_LINE_SMOOTH);
	glPointSize(1.0f);
	glLineWidth(1.0f);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	[aContext turnOnLighting];
	glDisable(GL_CLIP_PLANE0);
}

// the grid, route lines, pins and their captions
- (void)drawRouteAndGvozdixinContext:(id)aContext
{
	NSInteger detalization = [Preferences gridDetalization];
	SMK_GL_Drawable *routes = [_routePointsContainer routeDrawable];
	BOOL showsApples = [[_controller windowController] showsApples];
	if (showsApples)
		_appleStoreMarkerSize = (float)[[[_controller windowController] normalFont] maxHeight] * 0.5f;
	if (![Preferences gridEnabled] && routes == nil && _routeMarkersCaptions == nil &&
	    [_cityMarkerMatricesAndColors length] == 0 && [_jumpingCityMarkers length] == 0 && !showsApples)
		return;
	[aContext turnOffLighting];
	glEnable(GL_LINE_SMOOTH);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	_enableFrontHalfClipping((SMK_GL_Camera *)_camera);
	if ([Preferences gridEnabled]) {
		SMK_GL_Drawable *grid;
		if (detalization == 1)
			grid = _gridMeshHigh;
		else if (detalization == 0) {
			if (_zoomFactor > 3.5f)
				grid = _gridMeshHigh;
			else if (_zoomFactor > 2.0f)
				grid = _gridMeshNorm;
			else
				grid = _gridMeshLow;
		} else if (detalization == 2)
			grid = _gridMeshNorm;
		else
			grid = _gridMeshLow;
		[grid drawInContext:aContext];
	}
	glDisable(GL_CLIP_PLANE0);
	glEnable(GL_DEPTH_TEST);
	if ([Preferences showRouteLines]) {
		glLineWidth(2.0f);
		[routes drawInContext:aContext];
		glLineWidth(1.0f);
	}
	glDisable(GL_BLEND);
	glDisable(GL_LINE_SMOOTH);
	[aContext turnOnLighting];
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	glEnable(GL_RESCALE_NORMAL);
	float pinScale = (float)[Preferences markersScale] / (float)[_controller zoomFactor];
	NSPoint position = [_controller position];
	NSSize size = [aContext size];
	if (!(_previousZoomFactor == _zoomFactor && NSEqualPoints(_previousPosition, position) &&
	      NSEqualSizes(size, _previousContextSize))) {
		// the view moved: re-project the route captions
		_previousZoomFactor = _zoomFactor;
		_previousPosition = position;
		_previousContextSize = size;
		[[[_controller windowController] entriesOnMap] count];
		struct WeatherGlobe_anon5 sizesScale = { 2.0f / (float)size.width, 2.0f / (float)size.height };
		[_routeMarkersCaptionsLayouter setSizesScale:&sizesScale];
		NSInteger count = [_recordedCaptionIDs count];
		for (NSInteger i = 0; i < count; i++) {
			id caption = [_recordedCaptionIDs objectAtIndex:i];
			BOOL visible;
			NSPoint point = [self get2DCoordinatesFromGeoPoint:[[caption attachedObject] coordinates] onViewedSide:&visible];
			SMK_GL_Vec2 captionPosition = { visible ? (float)point.x : -1000.0f, (float)point.y };
			[_routeMarkersCaptions setNewPosition:&captionPosition forCaption:caption];
		}
	}
	if (showsApples)
		[self drawAppleStoresInContext:aContext];
	NSUInteger count = [_cityMarkerMatricesAndColors length] / sizeof(_PinMarker);
	const _PinMarker *marker = [_cityMarkerMatricesAndColors bytes];
	SMK_GL_Material *material = [(SMK_GL_Mesh *)[_knopka mesh] material];
	SMK_GL_Color specular = { 2.0f, 2.0f, 2.0f, 1.0f };
	[material setSpecular:specular];
	[material setShininess:50.0];
	[_sunLight setSpecular:specular];
	[_sunLight setupLightInContext:aContext];
	SMK_GL_Matrix matrix;
	for (NSUInteger i = 0; i < count; i++, marker++) {
		[material setDiffuse:marker->color];
		SMK_GL_Color ambient = { marker->color.r * 0.5f, marker->color.g * 0.5f, marker->color.b * 0.5f, marker->color.a };
		[material setAmbient:ambient];
		matrix = marker->matrix;
		matrix._11 *= pinScale; matrix._12 *= pinScale; matrix._13 *= pinScale;
		matrix._21 *= pinScale; matrix._22 *= pinScale; matrix._23 *= pinScale;
		matrix._31 *= pinScale; matrix._32 *= pinScale; matrix._33 *= pinScale;
		[_knopka setMatrix:&matrix];
		[_knopka drawInContext:aContext];
	}
	if ([Preferences showLocationNamesEnabled])
		[_routeMarkersCaptions drawInContext:aContext foreColor:&_captionColor backColor:&_backCaptionColor];
	// pins of the cities dragged over the globe bounce in place
	double time = [NSDate timeIntervalSinceReferenceDate] * 0.3499999940395355;
	double timeBase = floor(time);
	count = [_jumpingCityMarkers length] / sizeof(_PinMarker);
	marker = [_jumpingCityMarkers bytes];
	SMK_GL_Color diffuse = { 0.5f, 0.5f, 0.5f, 1.0f };
	[material setDiffuse:diffuse];
	SMK_GL_Color ambient = { 0.2f, 0.2f, 0.2f, 1.0f };
	[material setAmbient:ambient];
	for (NSUInteger i = 0; i < count; i++, marker++) {
		matrix = marker->matrix;
		matrix._11 *= pinScale; matrix._12 *= pinScale; matrix._13 *= pinScale;
		matrix._21 *= pinScale; matrix._22 *= pinScale; matrix._23 *= pinScale;
		matrix._31 *= pinScale; matrix._32 *= pinScale; matrix._33 *= pinScale;
		float phase = (float)(time - timeBase) + marker->color.a;
		phase = phase - floorf(phase);
		float height = 1.0f - phase;
		height = height * 0.7f * height + 0.3f;
		float bounce = phase / (height * 0.4f);
		bounce = (bounce - floorf(bounce)) * 3.0f;
		if (bounce > 1.0f)
			bounce = (3.0f - bounce) * 0.5f;
		height = height * 1.3f;
		float amplitude;
		if (height <= 1.0f)
			amplitude = height * 0.035f;
		else {
			height = 1.0f;
			amplitude = 0.035f;
		}
		float offset = amplitude * height * (1.0f - (1.0f - bounce) * (1.0f - bounce));
		matrix._14 += offset * marker->color.r;
		matrix._24 += offset * marker->color.g;
		matrix._34 += offset * marker->color.b;
		[_knopka setMatrix:&matrix];
		[_knopka drawInContext:aContext];
	}
	glDisable(GL_RESCALE_NORMAL);
	glDisable(GL_CULL_FACE);
	SMK_GL_Color noSpecular = { 0.0f, 0.0f, 0.0f, 0.0f };
	[_sunLight setSpecular:noSpecular];
	[_sunLight setupLightInContext:aContext];
	glDisable(GL_DEPTH_TEST);
}

- (void)_setupMatrix:(struct WeatherGlobe_anon3 *)aMatrix toDisplayFlatMeshInRect:(NSRect)aRect
{
	NSSize size = [[_container context] size];
	float width = (float)size.width, height = (float)size.height;
	SMK_GL_Matrix *matrix = (SMK_GL_Matrix *)aMatrix;
	matrix_make_identity(matrix);
	matrix->_11 = (2.0f / width) * (float)aRect.size.width;
	matrix->_22 = (float)aRect.size.height * (2.0f / height);
	matrix->_14 = (width * -0.5f + (float)aRect.origin.x) * (2.0f / width);
	matrix->_24 = (height * -0.5f + (float)aRect.origin.y) * (2.0f / height);
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
		BOOL firstVisible = NO, secondVisible = NO;
		NSPoint first = [self get2DCoordinatesFromGeoPoint:rect.origin onViewedSide:&firstVisible];
		NSPoint second = [self get2DCoordinatesFromGeoPoint:NSMakePoint((float)rect.size.width + (float)rect.origin.x,
		                                                                (float)rect.size.height + (float)rect.origin.y)
		                                       onViewedSide:&secondVisible];
		if (!firstVisible && !secondVisible)
			continue;
		float x = (float)MIN(first.x, second.x), right = (float)MAX(first.x, second.x);
		float y = (float)MIN(first.y, second.y), top = (float)MAX(first.y, second.y);
		float width = right - x, height = top - y;
		if (!(x >= -1.0f))
			x = -0.95f;
		if (!(y >= -1.0f))
			y = -0.95f;
		if (x + width > 1.0f)
			x = 0.95f - width;
		if (y + height > 1.0f)
			y = 0.95f - height;
		[aContext setFont:[[_controller windowController] largeFont]];
		CGFloat r, g, b, a;
		[color getRed:&r green:&g blue:&b alpha:&a];
		SMK_GL_Color glColor = { (float)r, (float)g, (float)b, (float)a };
		[aContext setColor:&glColor];
		[aContext enter2DMode];
		[self _drawInContext:aContext countryCaption:name in2DRect:NSMakeRect(x, y, width, height)];
		[aContext exit2DMode];
	}
	[aContext popState];
}

- (void)_drawZoneHiliteInContext:(id)aContext
{
	NSArray *drawables = [_zoneHiliter glDrawableObjects];
	if (drawables == nil)
		return;
	NSInteger count = [drawables count];
	if (count == 0)
		return;
	[aContext pushStateComponents:0xffff];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	[aContext setColor:&white];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	for (NSInteger i = 0; i < count; i++)
		[[drawables objectAtIndex:i] drawInContext:aContext];
	glDisable(GL_BLEND);
	[aContext setTexture:nil atStage:0];
	[aContext setTexture:nil atStage:1];
	[aContext popState];
}

// clamps a caption hanging over a view edge
- (BOOL)_drawInContext:(id)aContext countryCaption:(id)aCaption in2DRect:(NSRect)aRect
{
	NSInteger hAlignment, vAlignment;
	float x = (float)aRect.origin.x, width = (float)aRect.size.width;
	float y = (float)aRect.origin.y, height = (float)aRect.size.height;
	if (x < -1.0f && width + x > -1.0f) {
		hAlignment = 0;
		aRect.origin.x = -1.0;
	} else if (width + x > 1.0f && x < 1.0f) {
		hAlignment = 1;
		aRect.origin.x = 0.5;
		aRect.size.width = 0.5;
	} else {
		hAlignment = 2;
	}
	if (y < -1.0f && y + height > -1.0f) {
		vAlignment = 2;
		aRect.origin.y = -1.0;
	} else if (y + height > 1.0f && y < 1.0f) {
		vAlignment = 0;
		aRect.origin.y = 0.5;
		aRect.size.height = 0.5;
	} else {
		vAlignment = 1;
	}
	BOOL visible = NSIntersectsRect(aRect, _bounds2D);
	if (visible)
		[aContext drawString:aCaption inRect:aRect hAlignment:hAlignment vAlignment:vAlignment
		           backColor:(const SMK_GL_Color *)&_countryCaptionBackColor];
	return visible;
}

- (void)_drawMoonInContext:(id)aContext
{
	SMK_GL_Vec3 axis = { 0.0f, 0.0f, 1.0f };
	SMK_GL_Matrix translation, rotation, matrix;
	translateMatrix(&translation, (const SMK_GL_Vec3 *)&_moonPosition);
	rotateMatrix(&rotation, -_moonRotation, &axis);
	matrix_mul(&matrix, &translation, &rotation);
	[_moonDrawable setMatrix:&matrix];
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	[_moonDrawable drawInContext:aContext];
	glDisable(GL_CULL_FACE);
}

- (void)_drawCloudsInContext:(id)aContext
{
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	CloudsMaterial *clouds = [[_controller windowController] cloudsMaterial];
	SMK_GL_Material *savedMaterial = [[[(SMK_GL_Mesh *)[_earthHemisphere mesh] material] retain] autorelease];
	[(SMK_GL_Mesh *)[_earthHemisphere mesh] setMaterial:clouds];
	[clouds checkCloudsTextures];
	[clouds setLightingEnabled:[Preferences dayNightIsEnabled]];
	SMK_GL_Matrix matrix;
	if ([clouds hasTexturesForEast]) {
		matrix_make_identity(&matrix);
		[_earthHemisphere setMatrix:&matrix];
		[clouds setIsEastBinding:YES];
		[_earthHemisphere drawInContext:aContext];
	}
	if ([clouds hasTexturesForWest]) {
		SMK_GL_Vec3 axis = { 0.0f, 0.0f, 1.0f };
		rotateMatrix(&matrix, 3.1415927f, &axis);
		[_earthHemisphere setMatrix:&matrix];
		[clouds setIsEastBinding:NO];
		[_earthHemisphere drawInContext:aContext];
	}
	[(SMK_GL_Mesh *)[_earthHemisphere mesh] setMaterial:savedMaterial];
	glDisable(GL_BLEND);
}

// turns the atmosphere ring to face the viewer
- (void)_drawGlowInContext:(id)aContext
{
	SMK_GL_Vec3 up = { 0.0f, 1.0f, 0.0f };
	SMK_GL_Vec3 viewDirection;
	[(SMK_GL_Camera *)_camera getViewDirection:&viewDirection];
	vec3_normalize(&viewDirection);
	SMK_GL_Vec2 ground = { viewDirection.x, viewDirection.z };
	vec2_normalize(&ground);
	float heading = acosf(ground.y);
	if (ground.x < 0.0f)
		heading = 6.2831855f - heading;
	SMK_GL_Matrix turn, tilt, matrix;
	rotateMatrix(&turn, heading, &up);
	float pitch = asinf(viewDirection.y);
	SMK_GL_Vec3 axis = { up.y * viewDirection.z - viewDirection.y * up.z,
	                     up.z * viewDirection.x - viewDirection.z * up.x,
	                     viewDirection.y * up.x - up.y * viewDirection.x };
	rotateMatrix(&tilt, -pitch, &axis);
	matrix_mul(&matrix, &tilt, &turn);
	[_atmosphereGlow setMatrix:&matrix];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[_atmosphereGlow drawInContext:aContext];
	glDisable(GL_BLEND);
}

// the star sphere, drawn with its own wide perspective; also projects the
// sun onto the screen for the flares
- (void)_drawStarsInContext:(id)aContext
{
	NSSize size = [aContext size];
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	gluPerspective(60.0, (double)((float)size.width / (float)size.height), 0.5, 100.0);
	SMK_GL_Matrix matrix;
	if ([Preferences starsEnabled]) {
		matrix_make_identity(&matrix);
		[_starsDrawable setMatrix:&matrix];
		[_starsDrawable drawInContext:aContext];
		SMK_GL_Vec3 axis = { 0.0f, 0.0f, 1.0f };
		rotateMatrix(&matrix, 3.1415927f, &axis);
		[_starsDrawable setMatrix:&matrix];
		[_starsDrawable drawInContext:aContext];
	}
	SMK_GL_Matrix modelView, projection, transform;
	glGetFloatv(GL_MODELVIEW_MATRIX, (GLfloat *)&modelView);
	glGetFloatv(GL_PROJECTION_MATRIX, (GLfloat *)&projection);
	matrix_transpose(&modelView);
	matrix_transpose(&projection);
	matrix_mul(&transform, &projection, &modelView);
	struct WeatherGlobe_anon2 light = [(AtlasController *)[[_controller windowController] atlasController] lightDirection];
	SMK_GL_Vec3 sun = { _starsRadius * light.f0, _starsRadius * light.f1, _starsRadius * light.f2 };
	vec3_transfrom((SMK_GL_Vec3 *)&_sunScreenPos, &transform, &sun);
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
}

// the sun's lens flares, faded in and out as the sun leaves or goes
// behind the globe
- (void)_drawSunGlowAtPosition:(struct WeatherGlobe_anon2 *)aPosition inContext:(id)aContext
{
	NSSize size = [aContext size];
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	SMK_GL_Matrix textureMatrix;
	matrix_make_identity(&textureMatrix);
	textureMatrix._11 = 0.25f;
	textureMatrix._22 = -0.25f;
	float aspect = (float)size.width / (float)size.height;
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	matrix._34 = 0.5f;
	float x = aPosition->f0, y = aPosition->f1;
	float aspectX = aspect * x;
	BOOL hidden = sqrtf(aspectX * aspectX + y * y) <= _earthRadius * _zoomFactor;
	float target;
	if ((BOOL)!hidden != _wasVisible) {
		_wasVisible = !hidden;
		_fadeStartTime = [NSDate timeIntervalSinceReferenceDate];
		if (hidden) {
			_startFadeFactor = _fadeFactor >= 0.0f ? _fadeFactor : 1.0f;
			_fadeFactor = 1.0f;
			target = 0.0f;
		} else {
			_startFadeFactor = _fadeFactor >= 0.0f ? _fadeFactor : 0.0f;
			_fadeFactor = 0.0f;
			target = 1.0f;
		}
	} else {
		target = hidden ? 0.0f : 1.0f;
	}
	if (_fadeStartTime >= 0.0) {
		float progress = (float)(([NSDate timeIntervalSinceReferenceDate] - _fadeStartTime) * 9.0);
		float rest;
		if (progress > 1.0f) {
			_fadeStartTime = -1.0;
			progress = 1.0f;
			rest = 0.0f;
		} else {
			rest = 1.0f - progress;
		}
		target = rest * _startFadeFactor + progress * target;
		_fadeFactor = target;
	}
	struct WeatherGlobe_anon2 light = [(AtlasController *)[[_controller windowController] atlasController] lightDirection];
	SMK_GL_Vec3 lightDirection = { light.f0, light.f1, light.f2 };
	SMK_GL_Vec3 viewDirection;
	[(SMK_GL_Camera *)_camera getViewDirection:&viewDirection];
	vec3_normalize(&lightDirection);
	vec3_normalize(&viewDirection);
	float facing = -(lightDirection.x * viewDirection.x + lightDirection.y * viewDirection.y + lightDirection.z * viewDirection.z);
	if (facing > 0.0f && (!hidden || target > 0.0f)) {
		double glare = (double)(float)pow((double)facing, 1.5);
		float intensity = target * (float)glare;
		for (int row = 0; row < 4; row++) {
			textureMatrix._24 = (float)row * -0.25f + 1.0f;
			for (int column = 0; column < 4; column++) {
				textureMatrix._14 = (float)column * 0.25f;
				[_flaresTexture setTransformMatrix:&textureMatrix];
				float flarePosition = _kFlarePositions[row][column];
				matrix._14 = x * flarePosition;
				matrix._24 = y * flarePosition;
				float flareSize = _kFlareSizes[row][column];
				matrix._11 = flareSize / aspect;
				matrix._22 = flareSize;
				if (flarePosition == 1.0f) {
					// the sun itself grows with the glare
					matrix._11 = (float)((double)matrix._11 * pow(glare, 3.0));
					matrix._22 = (float)((double)flareSize * pow(glare, 3.0));
				}
				[_flaresDrawable setMatrix:&matrix];
				const SMK_GL_Color *flareColor = &_kFlareColors[row][column];
				float factor = flarePosition == 1.0f ? target : intensity;
				SMK_GL_Color color = { flareColor->r * factor, flareColor->g * factor, flareColor->b * factor, flareColor->a };
				[[(SMK_GL_Mesh *)[_flaresDrawable mesh] material] setAmbient:color];
				[_flaresDrawable drawInContext:aContext];
			}
		}
	}
	glDisable(GL_BLEND);
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
}

- (void)_drawGlobeInContext:(id)aContext
{
	[self _drawGlobeWithLowQualityMapInContext:aContext];
}

// the globe from the two hemisphere textures; a transparent globe draws its
// back faces first
- (void)_drawGlobeWithLowQualityMapInContext:(id)aContext
{
	glEnable(GL_DEPTH_TEST);
	[(SMK_GL_Mesh *)[_earthHemisphere mesh] vertexBuffer];
	SMK_GL_Material *material = [(SMK_GL_Mesh *)[_earthHemisphere mesh] material];
	SMK_GL_Color ambient;
	if ([Preferences dayNightIsEnabled]) {
		ambient.r = 0.1f;
		ambient.g = 0.2f;
		ambient.b = 0.3f;
		ambient.a = 0.0f;
	} else {
		ambient.r = ambient.g = ambient.b = ambient.a = 1.0f;
	}
	[material setAmbient:ambient];
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	if ([aContext textureDot3ARB])
		[Preferences dayNightIsEnabled];
	[_westNormalsTexture release];
	_westNormalsTexture = nil;
	[_eastNormalsTexture release];
	_eastNormalsTexture = nil;
	float transparency = (float)[Preferences globeTransparencyLevel];
	if (transparency < 0.02f) {
		[_earthHemisphere setMatrix:&matrix];
		[_eastTexture setEnvMode:GL_MODULATE];
		[material setTexture:_eastTexture atStage:0];
		[material setTexture:nil atStage:1];
		[_earthHemisphere drawInContext:aContext];
		matrix._22 = -1.0f;
		matrix._11 = -1.0f;
		[_earthHemisphere setMatrix:&matrix];
		[_westTexture setEnvMode:GL_MODULATE];
		[material setTexture:_westTexture atStage:0];
		[_earthHemisphere drawInContext:aContext];
		glDisable(GL_DEPTH_TEST);
		return;
	}
	glEnable(GL_CULL_FACE);
	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA);
	SMK_GL_Color constant = { transparency, transparency, transparency, transparency };
	SMK_GL_2DTexture *textures[2] = { _eastTexture, _westTexture };
	for (int i = 0; i < 2; i++) {
		[textures[i] setCombinerMode:GL_MODULATE];
		[textures[i] setCombinerRGBArg0:GL_TEXTURE arg1:GL_PRIMARY_COLOR arg2:GL_PRIMARY_COLOR];
		[textures[i] setCombinerAlphaMode:GL_MODULATE];
		[textures[i] setCombinerAlphaArg0:GL_TEXTURE arg1:GL_CONSTANT arg2:GL_PRIMARY_COLOR];
		[textures[i] setConstantColor:constant];
	}
	for (int pass = 0; pass < 2; pass++) {
		glCullFace(pass == 0 ? GL_FRONT : GL_BACK);
		matrix_make_identity(&matrix);
		[_earthHemisphere setMatrix:&matrix];
		[material setTexture:_eastTexture atStage:0];
		[material setTexture:nil atStage:1];
		[_earthHemisphere drawInContext:aContext];
		matrix._22 = -1.0f;
		matrix._11 = -1.0f;
		[_earthHemisphere setMatrix:&matrix];
		[material setTexture:_westTexture atStage:0];
		[_earthHemisphere drawInContext:aContext];
	}
	glDisable(GL_BLEND);
	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
}

// draws the high quality map parts; each part number packs its column in the
// low and its row in the high 16 bits
- (void)_drawGlobeParts:(id)aParts withLOD:(NSInteger)aLOD inContext:(id)aContext
{
	NSInteger count = [aParts count];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	int segments = _partsSegments[aLOD];
	SMK_GL_Drawable **parts = [self _globePartsForLOD:aLOD];
	for (NSInteger i = 0; i < count; i++) {
		unsigned int number = [[aParts objectAtIndex:i] unsignedIntValue];
		int column = number & 0xffff;
		int row = number >> 16;
		struct WeatherGlobe_anon5 translation, scaling;
		SMK_GL_2DTexture *texture = [self textureForLod:aLOD xPos:column yPos:row translation:&translation scaling:&scaling];
		int slot = _partSlot(column, segments);
		SMK_GL_Drawable *part = parts[row];
		SMK_GL_Matrix matrix;
		rotateMatrix(&matrix, (((float)slot + (float)slot) * 3.1415927f) / (float)segments, &_northVector);
		[part setMatrix:&matrix];
		SMK_GL_Material *material = [(SMK_GL_Mesh *)[part mesh] material];
		[material setTexture:texture atStage:0];
		[[(SMK_GL_Mesh *)[part mesh] material] setAmbient:white];
		SMK_GL_Vec3 textureScale = { 1.0f / scaling.f0, -1.0f / scaling.f1, 1.0f };
		SMK_GL_Matrix textureMatrix;
		scaleMatrix(&textureMatrix, &textureScale);
		textureMatrix._14 = translation.f0;
		textureMatrix._24 = translation.f1 + 1.0f;
		[texture setTransformMatrix:&textureMatrix];
		[part drawInContext:aContext];
		[[(SMK_GL_Mesh *)[part mesh] material] setTexture:nil atStage:0];
	}
}

// marks the textures this frame uses and loads the missing ones, reusing
// unused textures before creating new ones
- (void)_startFrameDrawingWithLOD:(NSInteger)aLOD globeParts:(id)aParts
{
	NSArray *entries = [_currentTextures allValues];
	NSInteger count = [entries count];
	for (NSInteger i = 0; i < count; i++)
		[[entries objectAtIndex:i] removeObjectForKey:kTextureWillBeUsedKey];
	NSMutableArray *missing = [NSMutableArray array];
	count = [aParts count];
	for (NSInteger i = 0; i < count; i++) {
		unsigned int number = [[aParts objectAtIndex:i] unsignedIntValue];
		int x = number & 0xffff;
		int y = number >> 16;
		NSString *path = [MapPartsLoader pathForMapTextureForLOD:aLOD xPos:x yPos:y];
		NSMutableDictionary *entry = [_currentTextures objectForKey:path];
		if (entry == nil) {
			path = [[self _loader] nearestCachedLowResPathForLOD:aLOD xPos:x yPos:y translation:NULL scaling:NULL];
			entry = [_currentTextures objectForKey:path];
			if (entry == nil) {
				[missing addObject:[NSNumber numberWithInt:x + y * 0x10000]];
				continue;
			}
		}
		[entry setObject:[NSNumber numberWithBool:YES] forKey:kTextureWillBeUsedKey];
	}
	count = [missing count];
	BOOL noUnusedTextures = NO;
	for (NSInteger i = 0; i < count; i++) {
		unsigned int number = [[missing objectAtIndex:i] unsignedIntValue];
		int x = number & 0xffff;
		int y = number >> 16;
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

// finds the globe parts in view by drawing them in GL selection mode
- (id)_getVisibleGlobePartsForLOD:(NSInteger)aLOD inContext:(id)aContext
{
	SMK_GL_Frustum frustum;
	memcpy(&frustum, [aContext viewFrustum], sizeof(frustum));
	SMK_GL_Vec3 normal = _earthVecFromMapPoint([_controller mapPointFromPositionPoint:[_controller position]]);
	SMK_GL_Vec3 point = normal;
	GLdouble equation[4] = { 0.0, 0.0, 1.0, 0.0 };
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)[self camera];
	float halfWidth = (float)[camera frustumWidth] * 0.5f;
	float halfHeight = (float)[camera frustumHeight] * 0.5f;
	double radius = sqrt((double)(halfWidth * halfWidth + halfHeight * halfHeight));
	double depth;
	if (radius >= 0.4000000059604645)
		depth = 0.0;
	else
		depth = sqrt((radius * radius) / -0.1600000113248825 + 1.0) * 0.4000000059604645;
	float depthF = (float)depth;
	point.x *= depthF;
	point.y *= depthF;
	point.z *= depthF;
	// nothing behind the visible cap of the globe can be seen
	frustum.planes[1] = _planeFromPointAndNormal(&point, &normal);
	equation[3] = 10.0 - depth;
	int segments = _partsSegments[aLOD];
	int rows = _partsRows[aLOD];
	SMK_GL_Drawable **parts = [self _globePartsForLOD:aLOD];
	GLuint buffer[0x400];
	glSelectBuffer(0x400, buffer);
	glRenderMode(GL_SELECT);
	glInitNames();
	glPushName(0);
	glClipPlane(GL_CLIP_PLANE0, equation);
	glEnable(GL_CLIP_PLANE0);
	NSMutableSet *visible = [NSMutableSet setWithCapacity:0x20];
	for (int row = 0; row < rows; row++) {
		SMK_GL_Drawable *part = parts[row];
		for (int column = 0; column < segments; column++) {
			int slot = _partSlot(column, segments);
			SMK_GL_Matrix matrix;
			rotateMatrix(&matrix, (((float)slot + (float)slot) * 3.1415927f) / (float)segments, &_northVector);
			SMK_GL_VertexBuffer *vertexBuffer = [(SMK_GL_Mesh *)[part mesh] vertexBuffer];
			if (boxMatrixIntersectionTest([vertexBuffer minCorner], [vertexBuffer maxCorner], &matrix, &frustum) == 0)
				continue;
			glLoadName((column & 0xffff) + row * 0x10000);
			[part setMatrix:&matrix];
			[[(SMK_GL_Mesh *)[part mesh] material] setTexture:nil atStage:0];
			[part drawInContext:aContext];
		}
	}
	glDisable(GL_CLIP_PLANE0);
	GLint hits = glRenderMode(GL_RENDER);
	const GLuint *record = buffer;
	for (GLint i = 0; i < hits; i++) {
		GLuint names = record[0];
		record += 3;
		for (GLuint j = 0; j < names; j++, record++)
			[visible addObject:[NSNumber numberWithInt:(int)*record]];
	}
	return [visible allObjects];
}

// lights each globe vertex by the sun in its own tangent space and stores the
// result as the primary colour
- (void)_updatePrimaryColorForBuffer:(id)aBuffer forSecondHemisphere:(BOOL)aHemisphere
{
	unsigned char *vertex = [aBuffer lock:0];
	NSInteger count = [(SMK_GL_Mesh *)[_earthHemisphere mesh] verticesCount];
	SMK_GL_Matrix basis;
	matrix_make_identity(&basis);
	SMK_GL_Vec3 light = [_sunLight direction];
	vec3_normalize(&light);
	light.z = -light.z;
	if (!aHemisphere) {
		light.x = -light.x;
		light.y = -light.y;
	}
	for (NSInteger i = 0; i < count; i++, vertex += 0x2c) {
		const float *normal = (const float *)(vertex + 0xc);
		float length = sqrtf(normal[0] * normal[0] + normal[1] * normal[1]) + 0.0001f;
		float inverse = 1.0f / length;
		basis._11 = -normal[1] * inverse;
		basis._12 = inverse * normal[0];
		basis._13 = 0.0f;
		basis._21 = -normal[0] * normal[2] * inverse;
		basis._22 = -normal[1] * normal[2] * inverse;
		basis._23 = length;
		basis._31 = normal[0];
		basis._32 = normal[1];
		basis._33 = normal[2];
		SMK_GL_Vec4 lit;
		vec3_matrix_mul(&lit, &light, &basis);
		lit.z = lit.z * 0.7f;
		vec3_normalize((SMK_GL_Vec3 *)&lit);
		float r = lit.x * 0.5f + 0.5f;
		float g = lit.y * 0.5f + 0.5f;
		float b = (lit.z + 0.2f) * 0.5f + 0.5f;
		r = r < 0.0f ? 0.0f : (r > 1.0f ? 1.0f : r);
		g = g < 0.0f ? 0.0f : (g > 1.0f ? 1.0f : g);
		b = b < 0.0f ? 0.0f : (b > 1.0f ? 1.0f : b);
		vertex[0x18] = (unsigned char)(int)(r * 255.0f);
		vertex[0x19] = (unsigned char)(int)(g * 255.0f);
		vertex[0x1a] = (unsigned char)(int)(b * 255.0f);
		vertex[0x1b] = 1;
	}
	[aBuffer unlock];
}

- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize
{
	float side = (float)(aSize.height <= aSize.width ? aSize.height : aSize.width);
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)_camera;
	[camera setFrustumWidth:(float)(aSize.width + aSize.width) / (side * _zoomFactor)];
	[camera setFrustumHeight:(float)(aSize.height + aSize.height) / (side * _zoomFactor)];
	[self _setLightDirection:[(AtlasController *)[[_controller windowController] atlasController] lightDirection]];
	[super drawSceneInContext:aContext withFrameSize:aSize];
}

- (void)_setLightDirection:(struct WeatherGlobe_anon2)aDirection
{
	SMK_GL_Vec3 direction = { aDirection.f0, aDirection.f1, aDirection.f2 };
	[_sunLight setDirection:direction];
}

- (void)setZoomFactor:(CGFloat)aFactor
{
	_zoomFactor = (float)aFactor;
}

// the hiliter's scale: screen pixels per degree of the globe
- (CGFloat)_hiliteScaleValue
{
	float diameter = _earthRadius + _earthRadius;
	float frustumHeight = (float)[(SMK_GL_OrthoCamera *)[self camera] frustumHeight];
	NSSize size = [[_container context] size];
	return ((float)size.height * (diameter / frustumHeight)) / 180.0f;
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
	NSRect viewRect = [self _evaluateGlobeViewRect];
	[(SphereCountryHiliter *)_zoneHiliter rebuildForCountryDictionaries:zones scaleValue:[self _hiliteScaleValue] flags:3
	                                             evaluateGlobeViewRect:viewRect];
}

- (void)recalculateCountryHilite
{
	if ([_zoneHiliter isDisabled])
		return;
	NSArray *dictionaries = [[_zoneHiliter countryDictionaries] retain];
	[_zoneHiliter disable];
	NSRect viewRect = [self _evaluateGlobeViewRect];
	[(SphereCountryHiliter *)_zoneHiliter rebuildForCountryDictionaries:dictionaries scaleValue:[self _hiliteScaleValue] flags:3
	                                             evaluateGlobeViewRect:viewRect];
	[dictionaries release];
}

- (void)dragConcludedWithAllEntries
{
	[self _removeJumpingStuff];
}

- (void)dragExitedWithAllEntries
{
	[self _removeJumpingStuff];
}

- (void)_removeJumpingStuff
{
	[_jumpingCityMarkers release];
	_jumpingCityMarkers = nil;
	[_controller refreshAnimationFlag];
	[_controller refreshView];
}

// bouncing pins for the cities dragged over the globe, which turns to face them
- (void)dragBringsEntries:(id)aEntries
{
	NSArray *entries = aEntries;
	if ([entries count] > 200)
		entries = [entries subarrayWithRange:NSMakeRange(0, 200)];
	NSInteger count = [entries count];
	[_jumpingCityMarkers release];
	_jumpingCityMarkers = [[NSMutableData alloc] initWithLength:count * sizeof(_PinMarker)];
	_PinMarker *marker = [_jumpingCityMarkers mutableBytes];
	SMK_GL_Vec3 center = { 0.0f, 0.0f, 0.0f };
	AtlasDatabase *database = [AtlasDatabase database];
	static struct WeatherGlobe_anon2 fallback = { 1.0f, 0.0f, 0.0f };
	for (NSInteger i = 0; i < count; i++, marker++) {
		id uid = [[entries objectAtIndex:i] objectForKey:kCityEntryUID];
		struct WeatherGlobe_anon2 *vector = [database earthVecForDBEntryWithUID:uid];
		if (vector == NULL) {
			NSLog(@"wrong entry UID");
			vector = &fallback;
		}
		marker->color.r = vector->f0;
		marker->color.g = vector->f1;
		marker->color.b = vector->f2;
		center.x += marker->color.r;
		center.y += marker->color.g;
		center.z += marker->color.b;
		[self _evaluateMatrix:(struct WeatherGlobe_anon3 *)&marker->matrix
		   forPinWithEarthVec:(struct WeatherGlobe_anon2 *)&marker->color];
		marker->color.a = (float)random() * 4.656613e-10f + 0.0f;
	}
	vec3_normalize(&center);
	[_controller slideToMapPoint:_mapPointFromEarthVec(&center)];
	[_controller refreshAnimationFlag];
}

- (void)distCalcSetChangedTo:(id)aTo
{
	[_recordedCaptionIDs release];
	_recordedCaptionIDs = nil;
	NSInteger count = [aTo count];
	if (count == 0) {
		[_routePointsContainer adjustToRoutePointsArray:nil];
		[_routeMarkersCaptions beginRecordBlockWithLayouterOptions:0];
		[_routeMarkersCaptions endRecordBlock];
		[_cityMarkerMatricesAndColors release];
		_cityMarkerMatricesAndColors = nil;
		return;
	}
	if (_routeMarkersCaptions == nil) {
		_routeMarkersCaptionsLayouter = [[CaptionsLayouter alloc] init];
		[_routeMarkersCaptionsLayouter setMarkerRadius:0.01];
		[_routeMarkersCaptionsLayouter setNeedLayout:YES];
		_routeMarkersCaptions = [[SMK_GL_StaticText alloc] initWithContainer:_container glFont:[[_controller windowController] normalFont]];
		[_routeMarkersCaptions setLayouter:_routeMarkersCaptionsLayouter];
	}
	[_routeMarkersCaptions beginRecordBlockWithLayouterOptions:1];
	NSMutableData *points = [NSMutableData dataWithLength:count * sizeof(struct WeatherGlobe_anon8)];
	struct WeatherGlobe_anon8 *point = [points mutableBytes];
	NSMutableSet *recorded = [NSMutableSet set];
	_recordedCaptionIDs = [NSMutableArray new];
	for (NSInteger i = 0; i < count; i++, point++) {
		id entry = [aTo objectAtIndex:i];
		point->f0 = *[entry vectorFromEarthCenter];
		point->f1 = *[entry cityMarkerColor];
		if ([recorded containsObject:entry])
			continue;
		[recorded addObject:entry];
		BOOL visible;
		NSPoint position = [self get2DCoordinatesFromGeoPoint:[entry coordinates] onViewedSide:&visible];
		SMK_GL_Vec2 captionPosition = { visible ? (float)position.x : -1000.0f, (float)position.y };
		id caption = [_routeMarkersCaptions recordCaption:[entry ownName] atPosition:&captionPosition];
		[caption attachObject:entry];
		[_recordedCaptionIDs addObject:caption];
	}
	[_routeMarkersCaptions endRecordBlock];
	if (_routePointsContainer == nil)
		_routePointsContainer = [[SphereRoutePointsContainer alloc] initWithGLContainer:_container radius:_earthRadius];
	[_routePointsContainer adjustToRoutePointsArray:points];
	point = [points mutableBytes];
	[_cityMarkerMatricesAndColors release];
	_cityMarkerMatricesAndColors = [[NSMutableData alloc] initWithLength:count * sizeof(_PinMarker)];
	_PinMarker *marker = [_cityMarkerMatricesAndColors mutableBytes];
	for (NSInteger i = 0; i < count; i++, point++, marker++) {
		[self _evaluateMatrix:(struct WeatherGlobe_anon3 *)&marker->matrix forPinWithEarthVec:&point->f0];
		marker->color.r = point->f1.f0 * 0.5f;
		marker->color.g = point->f1.f1 * 0.5f;
		marker->color.b = point->f1.f2 * 0.5f;
		marker->color.a = 1.0f;
	}
	[_controller refreshAnimationFlag];
}

// turns the pin model from its initial direction to the earth vector and
// puts it on the surface
- (void)_evaluateMatrix:(struct WeatherGlobe_anon3 *)aMatrix forPinWithEarthVec:(struct WeatherGlobe_anon2 *)aVec
{
	SMK_GL_Matrix *matrix = (SMK_GL_Matrix *)aMatrix;
	matrix_make_identity(matrix);
	float x = _initialPinVec.x, y = _initialPinVec.y, z = _initialPinVec.z;
	SMK_GL_Vec3 axis = { y * aVec->f2 - z * aVec->f1, z * aVec->f0 - x * aVec->f2, x * aVec->f1 - y * aVec->f0 };
	rotateMatrix(matrix, acosf(x * aVec->f0 + y * aVec->f1 + z * aVec->f2), &axis);
	matrix->_14 = aVec->f0 * _earthRadius * 1.02f;
	matrix->_24 = aVec->f1 * _earthRadius * 1.02f;
	matrix->_34 = aVec->f2 * _earthRadius * 1.02f;
}

- (id)routePathsMesh
{
	return [[_routePointsContainer routeDrawable] mesh];
}

- (CGFloat)earthRadius
{
	return _earthRadius;
}

// the map rect of the latitudes in view, all longitudes
- (NSRect)_evaluateGlobeViewRect
{
	NSPoint center = NSMakePoint(0.5, 0.5);
	NSPoint top = NSMakePoint(0.5, 1.0);
	NSPoint bottom = NSMakePoint(0.5, 0.0);
	[self geoPointFromNormalizedViewPoint:&center];
	if (![self geoPointFromNormalizedViewPoint:&top]) {
		float latitude = (float)center.y + 90.0f;
		top.y = latitude <= 90.0f ? latitude : 90.0f;
		top.x = center.x;
	}
	if (![self geoPointFromNormalizedViewPoint:&bottom]) {
		float latitude = (float)center.y - 90.0f;
		bottom.y = latitude >= -90.0f ? latitude : -90.0f;
		bottom.x = center.x;
	}
	float height = (float)top.y - (float)bottom.y;
	return _mapRectFromGeoRect(NSMakeRect(-180.0, (float)bottom.y, 360.0, height));
}

- (NSPoint)get2DCoordinatesFromGeoPoint:(NSPoint)aPoint onViewedSide:(BOOL *)aSide
{
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)[self camera];
	SMK_GL_Matrix view = *[camera viewMatrix];
	struct WeatherGlobe_anon2 point = [self get3DCoordinatesFromGeoPoint:aPoint];
	SMK_GL_Vec3 world = { point.f0, point.f1, point.f2 };
	SMK_GL_Vec3 eye;
	vec3_transfrom(&eye, &view, &world);
	if (aSide != NULL)
		*aSide = eye.z >= -10.0f;
	float frustumWidth = (float)[(SMK_GL_OrthoCamera *)[self camera] frustumWidth];
	float frustumHeight = (float)[(SMK_GL_OrthoCamera *)[self camera] frustumHeight];
	return NSMakePoint(eye.x / (frustumWidth * 0.5f), eye.y / (frustumHeight * 0.5f));
}

- (struct WeatherGlobe_anon2)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint
{
	SMK_GL_Vec3 vector = _earthVecFromGeoPoint(aPoint);
	struct WeatherGlobe_anon2 result = { _earthRadius * vector.x, vector.y * _earthRadius, _earthRadius * vector.z };
	return result;
}

// casts a ray through a point of the view (0..1 on both axes) and returns
// the geo point it hits the globe at
- (BOOL)geoPointFromNormalizedViewPoint:(NSPoint *)aPoint
{
	SMK_GL_Matrix modelView, inverse;
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)[self camera];
	// The original read GL_MODELVIEW_MATRIX here, i.e. whatever the last
	// draw left current; mouse events now arrive with another context or
	// matrix current. The camera's view matrix is what that read used to get,
	// and what get2DCoordinatesFromGeoPoint: uses the other way round.
	modelView = *[camera viewMatrix];
	matrix_invert(&inverse, &modelView);
	float frustumWidth = (float)[camera frustumWidth];
	float frustumHeight = (float)[(SMK_GL_OrthoCamera *)[self camera] frustumHeight];
	aPoint->x = aPoint->x - 0.5;
	aPoint->y = aPoint->y - 0.5;
	float x = frustumWidth * (float)aPoint->x;
	aPoint->x = x;
	float y = frustumHeight * (float)aPoint->y;
	aPoint->y = y;
	SMK_GL_Vec3 nearPoint = { x, y, 1.0f };
	SMK_GL_Vec3 farPoint = { x, y, -1.0f };
	SMK_GL_Vec3 origin, direction;
	vec3_transfrom(&origin, &inverse, &farPoint);
	vec3_transfrom(&direction, &inverse, &nearPoint);
	direction.x -= origin.x;
	direction.y -= origin.y;
	direction.z -= origin.z;
	float a = direction.x * direction.x + direction.y * direction.y + direction.z * direction.z;
	float b = origin.x * direction.x + origin.y * direction.y + origin.z * direction.z;
	b = b + b;
	float radius = _earthRadius;
	float discriminant = b * b + ((origin.x * origin.x + origin.y * origin.y + origin.z * origin.z) - radius * radius) * a * -4.0f;
	if (discriminant < 0.0f)
		return NO;
	float t = (-b + sqrtf(discriminant)) / (a + a);
	float t2 = (-b - sqrtf(discriminant)) / (a + a);
	if (t < t2)
		t = t2;
	float hitX = t * direction.x + origin.x;
	float hitY = origin.y + direction.y * t;
	float hitZ = direction.z * t + origin.z;
	float latitude;
	double latitudeD;
	if (hitZ > radius || -hitZ > radius) {
		latitude = hitZ <= 0.0f ? -1.5707964f : 1.5707964f;
		latitudeD = hitZ <= 0.0f ? -1.5707963705062866 : 1.5707963705062866;
	} else {
		latitude = (float)asin((double)(hitZ / radius));
		latitudeD = (double)latitude;
	}
	aPoint->y = latitude;
	float cosine = hitX / (_earthRadius * (float)cos(latitudeD));
	if (cosine < -1.0f)
		cosine = -1.0f;
	else if (cosine > 1.0f)
		cosine = 1.0f;
	float longitude = acosf(cosine);
	aPoint->x = longitude;
	if (hitY < 0.0f)
		aPoint->x = -longitude;
	*aPoint = _degreesFromRadiansPoint(*aPoint);
	return YES;
}

- (id)routePointsContainer
{
	return _routePointsContainer;
}

- (id)sceneController
{
	return _controller;
}

- (BOOL)requiresAnimation
{
	return [_jumpingCityMarkers length] != 0;
}

- (void)dealloc
{
	[_westTexture release];
	[_eastTexture release];
	[_westNormalsTexture release];
	[_eastNormalsTexture release];
	[_earthHemisphere release];
	[_atmosphereGlow release];
	[_starsDrawable release];
	[_starsTexture release];
	[_flaresDrawable release];
	[_flaresTexture release];
	[_moonDrawable release];
	[_cityGlowsMaterial release];
	[_OSDrawable release];
	[_gridMeshLow release];
	[_gridMeshNorm release];
	[_gridMeshHigh release];
	[_routePointsContainer release];
	[_cityMarkerMatricesAndColors release];
	[_knopka release];
	[_appleMarkers release];
	[_jumpingCityMarkers release];
	for (int lod = 0; lod < 4; lod++) {
		SMK_GL_Drawable **parts = [self _globePartsForLOD:lod];
		for (int row = 0; row < _partsRows[lod]; row++) {
			[parts[row] release];
			parts[row] = nil;
		}
	}
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer controller:(id)aController
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		_controller = aController;
		_earthRadius = 0.4f;
		_starsRadius = 50.0f;
		_glowThickness = 0.080000006f;
		_zoomFactor = 1.0f;
		_fadeFactor = 0.0f;
		_fadeStartTime = -1.0;
		_moonOrbitRadius = 4.0f;
		[_container beginAccumulationBlock];
		[self _createAndSetupCamera];
		[self _createGlobeParts];
		[self _createHiQualityMapGlobeParts];
		[self _createAndSetupLights];
		[self _createStarsDrawable];
		[self _createMoon];
		[self _createCountryStateHiliters];
		[self _createCityMarker];
		[self _createAxisDrawable];
		[_container endAccumulationBlock];
	}
	return self;
}

- (void)fillVerticesWithAllCitiesInVB:(struct WeatherGlobe_anon4 *)aVB
{
	NSData *points = [[AtlasDatabase database] allCityPointsArray];
	NSUInteger count = [points length] >> 3;
	const float *point = [points bytes];
	for (NSUInteger i = 0; i < count; i++, point += 2, aVB++) {
		SMK_GL_Vec3 vector = _earthVecFromGeoPoint(NSMakePoint(point[0], point[1]));
		aVB->f0.f0 = vector.x * 0.4008f;
		aVB->f0.f1 = vector.y * 0.4008f;
		aVB->f0.f2 = vector.z * 0.4008f;
	}
}

- (void)_createCityMarker
{
	NSString *path = [[NSBundle mainBundle] pathForResource:@"knopka" ofType:@"plist"];
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh meshWithASEParsedFile:path container:_container usage:0 fvf:0x12 normalize:NO mergeParts:YES];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	SMK_GL_Color ambient = { 0.02f, 0.02f, 0.02f, 1.0f };
	SMK_GL_Color diffuse = { 0.1f, 0.1f, 0.1f, 1.0f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	[mesh setMaterial:material];
	_knopka = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	// the model comes in its own units: position and normal per vertex
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	float *vertex = [vertexBuffer lock:2];
	NSInteger count = [mesh verticesCount];
	for (NSInteger i = 0; i < count; i++, vertex += 6) {
		vertex[0] = vertex[0] * 0.0006f;
		vertex[1] = vertex[1] * 0.0006f;
		vertex[2] = vertex[2] * 0.0006f;
	}
	[vertexBuffer unlock];
	[_knopka setPerformsVisibilityCheck:NO];
	_initialPinVec.z = 0.0f;
	_initialPinVec.y = 0.0f;
	_initialPinVec.x = 1.0f;
}

- (void)_createCountryStateHiliters
{
	_zoneHiliter = [[SphereCountryHiliter alloc] initWithContainer:_container panelController:[self sceneController]
	                                                   captionFont:[NSFont boldSystemFontOfSize:16.0] storagePart:0
	                                                        radius:_earthRadius * 1.001f];
}

// the earth axis, shown in tilted mode: two line segments sticking out of the poles
- (void)_createAxisDrawable
{
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:2 usage:0 verticesCount:4 primitivesCount:2
	                                            primitiveType:1] autorelease];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	float *vertex = [vertexBuffer lock:0];
	vertex[0] = 0.0f;
	vertex[1] = 0.0f;
	vertex[2] = -_earthRadius * 1.2f;
	vertex[3] = 0.0f;
	vertex[4] = 0.0f;
	vertex[5] = -_earthRadius;
	vertex[6] = 0.0f;
	vertex[7] = 0.0f;
	vertex[8] = _earthRadius;
	vertex[9] = 0.0f;
	vertex[10] = 0.0f;
	vertex[11] = _earthRadius * 1.2f;
	[vertexBuffer unlock];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	if ([indexBuffer are32BitIndices]) {
		NSLog(@"Invalid index buffer was created");
		return;
	}
	unsigned short *index = [indexBuffer lock:0];
	index[0] = 0;
	index[1] = 1;
	index[2] = 2;
	index[3] = 3;
	[indexBuffer unlock];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 1.0f, 1.0f, 1.0f, 1.0f };
	SMK_GL_Color diffuse = { 0.0f, 0.0f, 0.0f, 0.0f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	_OSDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	[_OSDrawable setPerformsVisibilityCheck:NO];
}

- (void)_createStarsDrawable
{
	struct SMKGL_anon11 params = { _starsRadius, 32, 16, 0, 2, 0, 1 };
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSpherePartWithParams:&params container:_container fvf:0x102 usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	SMK_GL_Color black = { 0.0f, 0.0f, 0.0f, 0.0f };
	[material setAmbient:white];
	[material setDiffuse:black];
	NSString *path = [[NSBundle mainBundle] pathForResource:@"Stars" ofType:@"tiff"];
	_starsTexture = [SMK_GL_2DTexture textureForContainer:_container flags:1 usage:0 filePath:path];
	[_starsTexture setWrapS:GL_REPEAT T:GL_REPEAT];
	[_starsTexture retain];
	SMK_GL_Matrix textureMatrix;
	matrix_make_identity(&textureMatrix);
	textureMatrix._11 = 2.0f;
	textureMatrix._22 = 2.0f;
	[_starsTexture setTransformMatrix:&textureMatrix];
	[material setTexture:_starsTexture atStage:0];
	_starsDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	path = [[NSBundle mainBundle] pathForResource:@"Flares" ofType:@"tiff"];
	_flaresTexture = [SMK_GL_2DTexture textureForContainer:_container flags:0 usage:0 filePath:path];
	[_flaresTexture retain];
	mesh = [SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(-0.5, -0.5, 1.0, 1.0) xSegments:2 ySegments:2 container:_container
	                                      fvf:0x102 usage:0];
	material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	[material setAmbient:white];
	[material setDiffuse:black];
	[material setTexture:_flaresTexture atStage:0];
	_flaresDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	[_flaresDrawable setPerformsVisibilityCheck:NO];
}

- (void)_createAndSetupLights
{
	_sunLight = [[[SMK_GL_Light alloc] init] autorelease];
	SMK_GL_Color ambient = { 1.0f, 1.0f, 1.0f, 1.0f };
	SMK_GL_Color diffuse = { 4.0f, 4.0f, 4.0f, 1.0f };
	SMK_GL_Vec3 direction = { 1.0f, 0.3f, 1.0f };
	[_sunLight setAmbient:ambient];
	[_sunLight setDiffuse:diffuse];
	[_sunLight setDirection:direction];
	[self addLight:_sunLight];
}

- (void)_createMoon
{
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSphereWithRadius:_earthRadius * 0.2725f segments:32 stacks:16 container:_container
	                                                    fvf:0x212 usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 0.04f, 0.08f, 0.15f, 0.0f };
	SMK_GL_Color diffuse = { 1.0f, 1.0f, 1.0f, 1.0f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	NSString *path = [[NSBundle mainBundle] pathForResource:@"moon" ofType:@"tiff"];
	[material setTexture:[SMK_GL_2DTexture textureForContainer:_container flags:0 usage:0 filePath:path] atStage:0];
	_moonDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
}

// fills a hemisphere texture from its packed raw image
static void _fillTextureFromResource(SMK_GL_2DTexture *aTexture, NSString *aName)
{
	NSString *path = [[NSBundle mainBundle] pathForResource:aName ofType:@"raw"];
	NSData *data = [[NSData dataWithContentsOfFile:path] originalRepresentation];
	NSUInteger length = [data length];
	memcpy([aTexture lock], [data bytes], length);
	[aTexture unlock];
}

- (void)_createGlobeParts
{
	struct SMKGL_anon11 params = { _earthRadius, 32, 32, 0, 2, 0, 1 };
	SMK_GL_Matrix textureMatrix;
	matrix_make_identity(&textureMatrix);
	textureMatrix._22 = -1.0f;
	textureMatrix._24 = 1.0f;
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSpherePartWithParams:&params container:_container fvf:0x252 usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	[material setDiffuse:white];
	[mesh setMaterial:material];
	_earthHemisphere = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	_eastTexture = [[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:0 width:0x400 height:0x400 dataFormat:GL_RGBA8];
	_fillTextureFromResource(_eastTexture, @"east");
	_westTexture = [[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:0 width:0x400 height:0x400 dataFormat:GL_RGBA8];
	_fillTextureFromResource(_westTexture, @"west");
	[_westTexture setTransformMatrix:&textureMatrix];
	[_eastTexture setTransformMatrix:&textureMatrix];
	_gridMeshLow = [[SMK_GL_Drawable drawableWithMesh:[self _createGridMeshWithR:_earthRadius numSegs:18 numStacks:9 linesPerSeg:4]] retain];
	_gridMeshNorm = [[SMK_GL_Drawable drawableWithMesh:[self _createGridMeshWithR:_earthRadius numSegs:36 numStacks:18 linesPerSeg:2]] retain];
	_gridMeshHigh = [[SMK_GL_Drawable drawableWithMesh:[self _createGridMeshWithR:_earthRadius numSegs:72 numStacks:36 linesPerSeg:1]] retain];
	_cityGlowsMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	SMK_GL_Color black = { 0.0f, 0.0f, 0.0f, 0.0f };
	[_cityGlowsMaterial setAmbient:black];
	[_cityGlowsMaterial setDiffuse:white];
	[self _createGlowWithSegments:params.f2 << 2 radius:_earthRadius];
}

// the high quality map parts: at each LOD the globe is cut into rows of
// meridian slices, one drawable per row
- (void)_createHiQualityMapGlobeParts
{
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	for (int lod = 0; lod < 4; lod++) {
		SMK_GL_Drawable **parts = [self _globePartsForLOD:lod];
		int rows = _partsRows[lod];
		for (int row = 0; row < rows; row++) {
			struct SMKGL_anon11 params = { _earthRadius, 72, 36, 0, (unsigned int)_partsSegments[lod], (unsigned int)row, (unsigned int)rows };
			SMK_GL_Mesh *mesh = [[SMK_GL_Mesh createSpherePartWithParams:&params container:_container fvf:0x252 usage:0] retain];
			SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
			[material setDiffuse:white];
			[mesh setMaterial:material];
			parts[row] = [[SMK_GL_Drawable alloc] initWithMesh:mesh];
		}
	}
}

// latitude and longitude lines; each segment holds its parallel's points
// and, between them, the points of its meridian
- (id)_createGridMeshWithR:(CGFloat)aR numSegs:(NSInteger)aSegs numStacks:(NSInteger)aStacks linesPerSeg:(NSInteger)aSeg
{
	float radius = (float)aR;
	int segs = (int)aSegs, stacks = (int)aStacks, linesPerSeg = (int)aSeg;
	float latitudeScale = -2.0f / (float)stacks + 1.0f;
	int lastRow = stacks - 2;
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:2 usage:0
	                                              verticesCount:(stacks - 1) * (segs * linesPerSeg + 1) + (lastRow * linesPerSeg + 1) * (segs + 1)
	                                            primitivesCount:(segs * 2 + 2) * (stacks - 1) * linesPerSeg
	                                              primitiveType:1] autorelease];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color ambient = { 0.2f, 0.3f, 0.5f, 0.6f };
	SMK_GL_Color diffuse = { 0.0f, 0.0f, 0.0f, 0.2f };
	[material setAmbient:ambient];
	[material setDiffuse:diffuse];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	float *vertex = [vertexBuffer lock:2];
	for (int row = 0; row <= lastRow; row++) {
		double latitude = (double)((((float)row / (float)lastRow) - 0.5f) * 3.1415927f * latitudeScale);
		for (int seg = 0; seg <= segs; seg++) {
			float meridian = ((float)seg / (float)segs) * 3.1415927f;
			double meridianLongitude = (double)(meridian + meridian);
			for (int k = 0; k < linesPerSeg; k++) {
				float sinLatitude = (float)sin(latitude);
				float cosLatitude = (float)cos(latitude);
				float angle = ((1.0f / (float)(segs * linesPerSeg)) * (float)k + (float)seg / (float)segs) * 3.1415927f;
				double longitude = (double)(angle + angle);
				vertex[0] = (float)cos(longitude) * cosLatitude * radius;
				vertex[1] = cosLatitude * radius * (float)sin(longitude);
				vertex[2] = sinLatitude * radius;
				vertex += 3;
				if (k != 0) {
					double pointLatitude = (double)(latitudeScale * ((((float)row / (float)lastRow) +
					                                                  (1.0f / (float)(lastRow * linesPerSeg)) * (float)k) - 0.5f) * 3.1415927f);
					float sinPoint = (float)sin(pointLatitude);
					float cosPoint = (float)cos(pointLatitude);
					vertex[0] = (float)cos(meridianLongitude) * cosPoint * radius;
					vertex[1] = cosPoint * radius * (float)sin(meridianLongitude);
					vertex[2] = sinPoint * radius;
					vertex += 3;
				}
			}
		}
	}
	[vertexBuffer unlock];
	short perSeg = (short)linesPerSeg * 2 - 1;
	short perRow = (short)(segs + 1) * perSeg;
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	if ([indexBuffer are32BitIndices])
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__]
		                                                lineNumber:__LINE__ description:@"Index buffer must be in 16-bit format"];
	short *index = [indexBuffer lock:2];
	for (int row = 0; row <= lastRow; row++) {
		for (int seg = 0; seg < segs; seg++) {
			short segStart = (short)seg * perSeg;
			short nextRow = perRow * (short)(row + 1) + segStart;
			short start = segStart + (short)row * perRow;
			for (int k = 0; k < linesPerSeg; k++, index += 4) {
				// along the parallel, then up the meridian
				short current = k == 0 ? start : (short)(segStart + (short)k * 2 + (short)row * perRow);
				index[0] = k == 0 ? current : current - 1;
				index[1] = current + 1;
				if (row < lastRow) {
					index[2] = current;
					index[3] = k + 1 < linesPerSeg ? current + 2 : nextRow;
				} else {
					index[2] = 0;
					index[3] = 0;
				}
			}
		}
	}
	[indexBuffer unlock];
	return mesh;
}

// the atmosphere ring: three circles from inside to outside the globe edge,
// textured with a fading blue
- (void)_createGlowWithSegments:(NSInteger)aSegments radius:(CGFloat)aRadius
{
	int segments = (int)aSegments;
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:0x102 usage:0 verticesCount:segments * 3 + 3
	                                            primitivesCount:segments << 2 primitiveType:4] autorelease];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	float *vertex = [vertexBuffer lock:2];
	for (int ring = -1; ring != 2; ring++) {
		float level = (float)ring;
		float ringRadius = level * _glowThickness + (float)aRadius;
		for (int i = 0; i <= segments; i++) {
			double angle = (double)(((float)i / (float)segments) * 6.2831855f);
			float cosine = (float)cos(angle);
			float sine = (float)sin(angle);
			vertex[0] = sine * ringRadius;
			vertex[1] = cosine * ringRadius;
			vertex[2] = 0.0f;
			vertex[3] = (float)i / (float)segments;
			vertex[4] = (level < 0.0f ? -level : level) * 0.98f + 0.01f;
			vertex += 5;
		}
	}
	[vertexBuffer unlock];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	if ([indexBuffer are32BitIndices])
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__]
		                                                lineNumber:__LINE__ description:@"Index buffer must be in 16-bit format"];
	unsigned short *index = [indexBuffer lock:2];
	short count = (short)segments;
	for (short i = 0; i < segments; i++, index += 12) {
		short inner = i, inner1 = i + 1;
		short middle = count + i + 1, middle1 = count + i + 2;
		short outer = count * 2 + i + 2, outer1 = count * 2 + i + 3;
		index[0] = inner;
		index[1] = middle1;
		index[2] = inner1;
		index[3] = inner;
		index[4] = middle;
		index[5] = middle1;
		index[6] = middle;
		index[7] = outer1;
		index[8] = middle1;
		index[9] = middle;
		index[10] = outer;
		index[11] = outer1;
	}
	[indexBuffer unlock];
	_atmosphereGlow = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	SMK_GL_2DTexture *texture = [[[SMK_GL_2DTexture alloc] initWithContainer:_container flags:1 usage:0 width:0x40 height:0x40
	                                                               dataFormat:GL_RGBA8] autorelease];
	[texture setWrapS:GL_REPEAT T:GL_REPEAT];
	unsigned char *pixel = [texture lock];
	for (int row = 0; row < 0x40; row++) {
		float fade = (float)pow((double)((float)row / -70.0f + 1.0f), 4.0);
		unsigned char alpha = (unsigned char)(unsigned int)(fade * 210.0f);
		for (int column = 0; column < 0x40; column++, pixel += 4) {
			pixel[0] = 0x40;
			pixel[1] = 0x70;
			pixel[2] = 0xa0;
			pixel[3] = alpha;
		}
	}
	[texture unlock];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	[material setAmbient:white];
	[material setDiffuse:white];
	[material setTexture:texture atStage:0];
}

- (void)_createAndSetupCamera
{
	[self setCamera:[[[SMK_GL_OrthoCamera alloc] init] autorelease]];
	SMK_GL_OrthoCamera *camera = (SMK_GL_OrthoCamera *)_camera;
	[camera setMinZ:1.9 maxZ:18.1];
	SMK_GL_Vec3 position = { 10.0f, 0.0f, 0.0f };
	[camera setPosition:&position];
	SMK_GL_Vec3 viewDirection = { -1.0f, 0.0f, 0.0f };
	[camera setViewDirection:&viewDirection];
	SMK_GL_Vec3 upVector = { 0.0f, 0.0f, 1.0f };
	[camera setUpVector:&upVector];
}

@end
