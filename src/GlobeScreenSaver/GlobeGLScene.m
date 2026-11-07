#import "GlobeGLScene.h"

// The screen saver's scene: the spinning globe with its atmosphere glow,
// clouds, city lights on the night side, the moon, stars and the sun's lens
// flares. Two points of view:
//   0  from a satellite in a low orbit that slowly rolls, with the 3072
//      pixel map in 6 x 3 parts, filled as they come into view;
//   1  the whole globe in an orthographic view, with the 1024 pixel map.
// Most of it is the app's SphereMapScene code.
@implementation GlobeGLScene

/* i386 ivar offsets: _container=0x18, _globeUtils=0x1c, _sceneGlobeViewObjectsWasInited=0x20, _sceneSateliteViewObjectsWasInited=0x21, _sceneCommonObjectsWasInited=0x22, _textureLoader=0x24, _earthRadius=0x28, _glowThickness=0x2c, _cameraOrbitRadius=0x30, _earthHemisphere=0x34, _atmosphereGlow=0x38, _cityGlowsMaterial=0x3c, _eastLowResMapMaterial=0x40, _westLowResMapMaterial=0x44, _starsDrawable=0x48, _starsTexture=0x4c, _starsRadius=0x50, _flaresDrawable=0x54, _flaresTexture=0x58, _sunScreenPos=0x5c, _wasVisible=0x68, _moonDrawable=0x6c, _moonOrbitRadius=0x70, _moonPosition=0x74, _moonRotation=0x80, _moonPhase=0x84, _sunLight=0x88, _fadeFactor=0x8c, _startFadeFactor=0x90, _fadeStartTime=0x94, _cameraPlaneAngle=0x9c, _earthSpeed=0xa0, _cameraSpeed=0xa4, _rollSpeed=0xa8, _cameraSpacePosition=0xac, _lookAtSpacePosition=0xb8, _cameraPlaneMatrix=0xc4, _glowMatrix=0x104, _mapPartDrawables=0x144, _wasFilled=0x18c, _frame=0x1a0, _previousFrameDate=0x1a4, _eastCloudsMaterial=0x1a8, _westCloudsMaterial=0x1ac, _partParams=0x1b0, _globeModeCamera=0x1cc, _sateliteModeCamera=0x1d0 */

static const SMK_GL_Vec3 _kZAxis = { 0.0f, 0.0f, 1.0f };
static const SMK_GL_Color _kWhite = { 1.0f, 1.0f, 1.0f, 1.0f };
static const SMK_GL_Color _kBlack = { 0.0f, 0.0f, 0.0f, 0.0f };

static float _random01(void)
{
	return (float)((double)random() / 2147483647.0);
}

- (void)waitForStopLoadingThread
{
	[_textureLoader waitForStopLoadingThread];
}

- (void)prepareToAnimateNextFrameForFPS:(CGFloat)aFPS
{
	[self _calculateNextPositionForFPS:aFPS];
	[self _refreshCameraSettings];
	[self _calculateGlowMatrix];
}

// advances the animation clock by the time since the last frame
- (void)_calculateNextPositionForFPS:(CGFloat)aFPS
{
	NSCalendarDate *now = [NSCalendarDate calendarDate];
	float rate;
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 0) {
		rate = 0.1f;
	} else {
		rate = 0.4f / (float)[GlobeScreenSaverDefaults zoom];
	}
	float step = 0.0f;
	if (_previousFrameDate != nil) {
		double elapsed = [now timeIntervalSinceDate:_previousFrameDate];
		step = (float)((double)rate * elapsed * (double)(float)[GlobeScreenSaverDefaults spinningSpeed]);
	}
	[_previousFrameDate release];
	_previousFrameDate = [now retain];
	_frame = step + _frame;
}

- (void)drawObjectsInContext:(id)aContext
{
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 0) {
		[self _initSateliteViewSceneObjectsIfNeededForContext:aContext];
	} else {
		[self _initGlobeViewSceneObjectsIfNeededForContext:aContext];
	}
	glDisable(GL_DEPTH_TEST);
	[self _drawStarsInContext:aContext];
	_moonPosition = [_globeUtils moonDirection];
	_moonPosition.x *= _moonOrbitRadius;
	_moonPosition.y *= _moonOrbitRadius;
	_moonPosition.z *= _moonOrbitRadius;
	float phase = (float)[_globeUtils moonPhase];
	_moonRotation = phase * 3.1415927f + phase * 3.1415927f + 0.37699112f;
	SMK_GL_Vec3 view;
	[(SMK_GL_Camera *)_camera getViewDirection:&view];
	float behind = _moonPosition.x * view.x + _moonPosition.y * view.y + _moonPosition.z * view.z;
	// a moon behind the globe is drawn first, one in front last
	if ([GlobeScreenSaverDefaults moonEnabled] && behind > 0.0f) {
		[self _drawMoonInContext:aContext];
	}
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	[self _drawGlobeInContext:aContext];
	if ([GlobeScreenSaverDefaults dayNightEnabled]) {
		[self _drawCityGlowsInContext:aContext];
	}
	if ([GlobeScreenSaverDefaults cloudsEnabled]) {
		[self _drawCloudsInContext:aContext];
	}
	glDisable(GL_CULL_FACE);
	[self _drawGlowInContext:aContext];
	if ([GlobeScreenSaverDefaults moonEnabled] && behind <= 0.0f) {
		[self _drawMoonInContext:aContext];
	}
	if ([GlobeScreenSaverDefaults sunEnabled]) {
		[self _drawSunGlowAtPosition:&_sunScreenPos inContext:aContext];
	}
	[super drawObjectsInContext:aContext];
}

- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize
{
	[self _createCameras];
	[self _refreshCameraSettings];
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 1) {
		[self setCamera:_globeModeCamera];
		float side = (float)(aSize.height <= aSize.width ? aSize.height : aSize.width);
		float scale = side * (float)[GlobeScreenSaverDefaults zoom];
		[_globeModeCamera setFrustumWidth:(float)(aSize.width + aSize.width) / scale];
		[_globeModeCamera setFrustumHeight:(float)(aSize.height + aSize.height) / scale];
	} else {
		[self setCamera:_sateliteModeCamera];
	}
	[self _setLightDirection:[_globeUtils lightDirection]];
	[super drawSceneInContext:aContext withFrameSize:aSize];
}

- (void)dealloc
{
	[self waitForStopLoadingThread];
	[_textureLoader release];
	[_atmosphereGlow release];
	[_earthHemisphere release];
	[_starsTexture release];
	[_starsDrawable release];
	[_flaresTexture release];
	[_flaresDrawable release];
	[_moonDrawable release];
	[_globeUtils release];
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 6; x++) {
			[_mapPartDrawables[y][x] release];
			_mapPartDrawables[y][x] = nil;
		}
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_eastCloudsMaterial release];
	[_westCloudsMaterial release];
	[_eastLowResMapMaterial release];
	[_westLowResMapMaterial release];
	[_globeModeCamera release];
	[_sateliteModeCamera release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
	self = [super init];
	if (self != nil) {
		_container = aContainer;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_defaultsChanged:)
		                                             name:kUserDefaultsDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_endConfigSheet:)
		                                             name:kEndConfigSheetNotification object:nil];
		_sceneGlobeViewObjectsWasInited = NO;
		_sceneSateliteViewObjectsWasInited = NO;
		_sceneCommonObjectsWasInited = NO;
		_textureLoader = [[GlobeTextureLoader alloc] initWithContainer:_container];
		_globeUtils = [[GlobeUtils alloc] init];
		_earthRadius = 0.8f;
		_starsRadius = 90.0f;
		_glowThickness = _earthRadius * 0.2f;
		_moonOrbitRadius = 4.0f;
		_cameraOrbitRadius = _earthRadius * 1.17f;
		// every run flies a different orbit
		_cameraSpeed = _random01() * 0.30000007f + 0.9f;
		_rollSpeed = _random01() * 0.20000002f + 0.1f;
		_earthSpeed = _random01() * 0.20000002f + 0.4f;
		_frame = _random01() * 1000.0f + 0.0f;
		_cameraPlaneAngle = _random01() * 2.0943952f - 1.0471976f;
		SMK_GL_Vec3 xAxis = { 1.0f, 0.0f, 0.0f };
		rotateMatrix(&_cameraPlaneMatrix, _cameraPlaneAngle, &xAxis);
		[self _createAndSetupLights];
		for (int y = 0; y < 3; y++) {
			for (int x = 0; x < 6; x++) {
				_mapPartDrawables[y][x] = nil;
				_wasFilled[y][x] = NO;
			}
		}
		_partParams.r = _earthRadius;
		_partParams.numSphereSegments = 60;
		_partParams.numSphereStacks = 60;
		_partParams.totalPartXCount = 6;
		_partParams.totalPartYCount = 3;
	}
	return self;
}

@end

@implementation GlobeGLScene (Private)

// Whether a map part may show: its bounds are in the view frustum and its
// vertices aren't all on the far side of the horizon. Each vertex normal is
// classified as facing away (-1), near the horizon (0) or facing the
// camera (1).
- (BOOL)_testVisibleGlobePartMesh:(id)aMesh inContext:(id)aContext
{
	SMK_GL_Frustum frustum;
	memcpy(&frustum, [(SMK_GL_Context *)aContext viewFrustum], sizeof(frustum));
	SMK_GL_VertexBuffer *vertexBuffer = [(SMK_GL_Mesh *)aMesh vertexBuffer];
	SMK_GL_Matrix identity;
	matrix_make_identity(&identity);
	if (!boxMatrixIntersectionTest([vertexBuffer minCorner], [vertexBuffer maxCorner], &identity, &frustum)) {
		return NO;
	}
	// 11 x 21 vertices (44 bytes each), the normal after the position
	NSUInteger stride = [vertexBuffer vertexSize];
	char *vertices = [vertexBuffer lock:1];
	BOOL away = NO, facing = NO;
	BOOL visible = NO;
	for (int column = 0; column < 11; column++) {
		for (int row = 0; row < 21; row++) {
			SMK_GL_Vec3 normal;
			memcpy(&normal, vertices + (row * 11 + column) * stride + 12, sizeof(normal));
			NSInteger side = [self _testVisibleSpacePointOnglobe:&normal];
			if (side == 0) {
				visible = YES;
				goto done;
			}
			if (side == 1) {
				if (away) {
					visible = YES;
					goto done;
				}
				facing = YES;
			} else if (side == -1) {
				if (facing) {
					visible = YES;
					goto done;
				}
				away = YES;
			}
		}
	}
done:
	[vertexBuffer unlock];
	return visible;
}

- (NSInteger)_testVisibleSpacePointOnglobe:(SMK_GL_Vec3 *)aOnglobe
{
	SMK_GL_Vec3 n = *aOnglobe;
	float r = -_earthRadius;
	SMK_GL_Vec3 toCamera = { n.x * r + _cameraSpacePosition.x, r * n.y + _cameraSpacePosition.y,
	                         r * n.z + _cameraSpacePosition.z };
	vec3_normalize(&toCamera);
	float dot = n.x * toCamera.x + n.y * toCamera.y + n.z * toCamera.z;
	if (dot < 0.05f) {
		return -1;
	}
	return dot > 0.4f ? 1 : 0;
}

// longitude and latitude in radians
- (NSPoint)_geoPointFromSpacePoint:(SMK_GL_Vec3)aPoint onSphereRadius:(CGFloat)aRadius
{
	float radius = (float)aRadius;
	float latitude;
	if (radius < aPoint.z || radius < -aPoint.z) {
		latitude = aPoint.z <= 0.0f ? -1.5707964f : 1.5707964f;
	} else {
		latitude = (float)asin((double)(aPoint.z / radius));
	}
	float c = aPoint.x / (radius * (float)cos((double)latitude));
	if (c < -1.0f) {
		c = -1.0f;
	} else if (c > 1.0f) {
		c = 1.0f;
	}
	float longitude = acosf(c);
	if (aPoint.y < 0.0f) {
		longitude = -longitude;
	}
	return NSMakePoint(longitude, latitude);
}

// the animation restarts its clock after the Options sheet
- (void)_endConfigSheet:(id)aSheet
{
	[_previousFrameDate release];
	_previousFrameDate = nil;
}

- (void)_defaultsChanged:(id)aChanged
{
}

// the globe's outline on screen, in normalized device coordinates
- (void)_getEarthProjectionCircleParameters:(float *)aParameters outCenter:(NSPoint *)aCenter
{
	SMK_GL_Matrix modelView, projection, transform;
	glGetFloatv(GL_MODELVIEW_MATRIX, (GLfloat *)&modelView);
	glGetFloatv(GL_PROJECTION_MATRIX, (GLfloat *)&projection);
	matrix_transpose(&modelView);
	matrix_transpose(&projection);
	matrix_mul(&transform, &projection, &modelView);
	SMK_GL_Vec3 origin = { 0.0f, 0.0f, 0.0f };
	SMK_GL_Vec3 center;
	vec3_transfrom(&center, &transform, &origin);
	if (aCenter != NULL) {
		aCenter->x = center.x;
		aCenter->y = center.y;
	}
	if (aParameters != NULL) {
		SMK_GL_Vec3 edge;
		vec3_transfrom(&edge, &transform, &_lookAtSpacePosition);
		*aParameters = sqrtf((edge.x - center.x) * (edge.x - center.x) + (edge.y - center.y) * (edge.y - center.y));
	}
}

- (SMK_GL_Vec3)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint
{
	SMK_GL_Vec3 vec = _earthVecFromGeoPoint(aPoint);
	vec.x *= _earthRadius;
	vec.y *= _earthRadius;
	vec.z *= _earthRadius;
	return vec;
}

- (void)_setLightDirection:(SMK_GL_Vec3)aDirection
{
	[_sunLight setDirection:aDirection];
}

// draws the hemisphere at the origin and turned by pi about the pole
- (void)_drawHemispheresWithEastMaterial:(SMK_GL_Material *)aEast west:(SMK_GL_Material *)aWest inContext:(id)aContext
{
	SMK_GL_Mesh *mesh = [_earthHemisphere mesh];
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	[_earthHemisphere setMatrix:&matrix];
	[mesh setMaterial:aEast];
	[_earthHemisphere drawInContext:aContext];
	rotateMatrix(&matrix, 3.1415927f, &_kZAxis);
	[_earthHemisphere setMatrix:&matrix];
	[mesh setMaterial:aWest];
	[_earthHemisphere drawInContext:aContext];
}

// city lights, added on the night side: the sun is turned around so the
// night lights are lit where the day side is dark
- (void)_drawCityGlowsInContext:(id)aContext
{
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	SMK_GL_Mesh *mesh = [_earthHemisphere mesh];
	SMK_GL_Material *material = [[[mesh material] retain] autorelease];
	[mesh setMaterial:_cityGlowsMaterial];
	SMK_GL_Vec3 direction = [_sunLight direction];
	SMK_GL_Vec3 reversed = { -direction.x, -direction.y, -direction.z };
	[_sunLight setDirection:reversed];
	[_sunLight setupLightInContext:aContext];
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	[_earthHemisphere setMatrix:&matrix];
	SMK_GL_2DTexture *texture = [_textureLoader nightTextureForEast];
	[texture setCombinerMode:GL_MODULATE];
	[texture setCombinerAlphaMode:GL_MODULATE];
	[texture setCombinerRGBScale:1];
	[_cityGlowsMaterial setTexture:texture atStage:0];
	[_earthHemisphere drawInContext:aContext];
	rotateMatrix(&matrix, 3.1415927f, &_kZAxis);
	[_earthHemisphere setMatrix:&matrix];
	texture = [_textureLoader nightTextureForWest];
	[texture setCombinerMode:GL_MODULATE];
	[texture setCombinerAlphaMode:GL_MODULATE];
	[texture setCombinerRGBScale:1];
	[_cityGlowsMaterial setTexture:texture atStage:0];
	[_earthHemisphere drawInContext:aContext];
	[mesh setMaterial:material];
	glDisable(GL_BLEND);
	[_sunLight setDirection:direction];
	[_sunLight setupLightInContext:aContext];
}

- (void)_drawCloudsInContext:(id)aContext
{
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_COLOR, GL_ONE);
	SMK_GL_Mesh *mesh = [_earthHemisphere mesh];
	SMK_GL_Material *material = [[[mesh material] retain] autorelease];
	float diffuse;
	if (![GlobeScreenSaverDefaults dayNightEnabled]) {
		SMK_GL_Color ambient = { 1.1f, 1.1f, 1.1f, 1.0f };
		[_eastCloudsMaterial setAmbient:ambient];
		[_westCloudsMaterial setAmbient:ambient];
		diffuse = 0.0f;
	} else {
		SMK_GL_Color ambient = { 0.4f, 0.5f, 0.6f, 1.0f };
		[_eastCloudsMaterial setAmbient:ambient];
		[_westCloudsMaterial setAmbient:ambient];
		diffuse = 1.1f;
	}
	SMK_GL_Color color = { diffuse, diffuse, diffuse, 1.0f };
	[_eastCloudsMaterial setDiffuse:color];
	[_westCloudsMaterial setDiffuse:color];
	[self _drawHemispheresWithEastMaterial:_eastCloudsMaterial west:_westCloudsMaterial inContext:aContext];
	[mesh setMaterial:material];
	glDisable(GL_BLEND);
}

- (void)_drawGlowInContext:(id)aContext
{
	[_atmosphereGlow setMatrix:&_glowMatrix];
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[_atmosphereGlow drawInContext:aContext];
	glDisable(GL_BLEND);
}

// The glow ring is drawn in the plane through the globe's center facing the
// camera: in the satellite view it follows the orbit, scaled and moved
// towards the camera so it matches the horizon.
- (void)_calculateGlowMatrix
{
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 0) {
		SMK_GL_Matrix scale, orbit, step, plane, spin;
		matrix_make_identity(&scale);
		scale._22 = 0.5191209f;
		scale._33 = 0.5191209f;
		scale._14 = _earthRadius / 1.17f;
		rotateMatrix(&orbit, _frame * _cameraSpeed, &_kZAxis);
		matrix_mul(&step, &orbit, &scale);
		matrix_mul(&plane, &_cameraPlaneMatrix, &step);
		rotateMatrix(&spin, _earthSpeed * _frame, &_kZAxis);
		matrix_mul(&_glowMatrix, &spin, &plane);
		return;
	}
	rotateMatrix(&_glowMatrix, (float)[GlobeScreenSaverDefaults globeSpinningDirection] * _frame * _cameraSpeed, &_kZAxis);
}

// the sun's lens flares, faded in and out as the sun leaves or goes
// behind the globe
- (void)_drawSunGlowAtPosition:(SMK_GL_Vec3 *)aPosition inContext:(id)aContext
{
	NSSize size = [(SMK_GL_Context *)aContext size];
	float radius;
	NSPoint center;
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 0) {
		[self _getEarthProjectionCircleParameters:&radius outCenter:&center];
	} else {
		radius = _earthRadius * (float)[GlobeScreenSaverDefaults zoom];
		center = NSZeroPoint;
	}
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
	SMK_GL_Matrix matrix;
	matrix_make_identity(&matrix);
	matrix._34 = 0.5f;
	float aspect = (float)(size.width / size.height);
	float x = aPosition->x, y = aPosition->y;
	float sunX = x;
	if ([GlobeScreenSaverDefaults pointOfViewMode] != 0) {
		sunX = x * aspect;
	}
	double dx = (double)sunX - center.x, dy = (double)y - center.y;
	BOOL hidden = (float)sqrt(dx * dx + dy * dy) <= radius;
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
	SMK_GL_Vec3 lightDirection = [_globeUtils lightDirection];
	SMK_GL_Vec3 viewDirection;
	[(SMK_GL_Camera *)_camera getViewDirection:&viewDirection];
	vec3_normalize(&lightDirection);
	vec3_normalize(&viewDirection);
	float facing = -(lightDirection.x * viewDirection.x + lightDirection.y * viewDirection.y + lightDirection.z * viewDirection.z);
	if (facing > 0.0f && (!hidden || target > 0.0f)) {
		double glare = (double)(float)pow((double)facing, 1.5);
		float intensity = target * (float)glare;
		for (int row = 0; row < 4; row++) {
			for (int column = 0; column < 4; column++) {
				textureMatrix._14 = (float)column * 0.25f;
				textureMatrix._24 = (float)row * -0.25f + 1.0f;
				[_flaresTexture setTransformMatrix:&textureMatrix];
				float flarePosition = kFlarePositions[row][column];
				matrix._14 = x * flarePosition;
				matrix._24 = y * flarePosition;
				float flareSize = kFlareSizes[row][column];
				matrix._11 = flareSize / aspect;
				matrix._22 = flareSize;
				if (flarePosition == 1.0f) {
					// the sun itself grows with the glare
					matrix._11 = (float)((double)matrix._11 * pow(glare, 3.0));
					matrix._22 = (float)((double)flareSize * pow(glare, 3.0));
				}
				[_flaresDrawable setMatrix:&matrix];
				const SMK_GL_Color *flareColor = &kFlareColors[row][column];
				float factor = flarePosition == 1.0f ? target : intensity;
				SMK_GL_Color color = { flareColor->r * factor, flareColor->g * factor, flareColor->b * factor, flareColor->a };
				[(SMK_GL_Material *)[(SMK_GL_Mesh *)[_flaresDrawable mesh] material] setAmbient:color];
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

// The 1024 pixel map until the 3072 one has loaded, and always in the
// globe view. The satellite view draws only the parts that may show, filling
// each part's texture the first time it does.
- (void)_drawGlobeInContext:(id)aContext
{
	glEnable(GL_DEPTH_TEST);
	SMK_GL_Color ambient;
	if (![GlobeScreenSaverDefaults dayNightEnabled]) {
		ambient = _kWhite;
	} else {
		ambient = (SMK_GL_Color){ 0.1f, 0.2f, 0.3f, 0.0f };
	}
	if (![_textureLoader isHiResolutionTexturesWasLoaded] || [GlobeScreenSaverDefaults pointOfViewMode] != 0) {
		[_eastLowResMapMaterial setAmbient:ambient];
		[_westLowResMapMaterial setAmbient:ambient];
		SMK_GL_Mesh *mesh = [_earthHemisphere mesh];
		SMK_GL_Material *material = [[[mesh material] retain] autorelease];
		[self _drawHemispheresWithEastMaterial:_eastLowResMapMaterial west:_westLowResMapMaterial inContext:aContext];
		[mesh setMaterial:material];
	} else {
		for (int y = 0; y < 3; y++) {
			for (int x = 0; x < 6; x++) {
				SMK_GL_Drawable *drawable = _mapPartDrawables[y][x];
				if (drawable == nil) {
					[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
					    file:@"GlobeGLScene.m" lineNumber:0x2c8 description:@"drawable for globe drawing incorrect"];
				}
				SMK_GL_Mesh *mesh = [drawable mesh];
				if (![self _testVisibleGlobePartMesh:mesh inContext:aContext])
					continue;
				if (!_wasFilled[y][x]) {
					[_textureLoader fillTexture:[(SMK_GL_Material *)[mesh material] textureAtStage:0] lod:1 xPart:x yPart:y];
					_wasFilled[y][x] = YES;
				}
				[(SMK_GL_Material *)[mesh material] setAmbient:ambient];
				[drawable drawInContext:aContext];
			}
		}
	}
	glDisable(GL_DEPTH_TEST);
}

- (void)_createMapPartDrawables
{
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 6; x++) {
			SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
			[material setDiffuse:_kWhite];
			[material setTexture:[_textureLoader createTextureForMapPart] atStage:0];
			_partParams.partXNumber = x;
			_partParams.partYNumber = y;
			[_container beginAccumulationBlock];
			SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSpherePartWithParams:(struct SMKGL_anon11 *)&_partParams
			                                                  container:_container fvf:0x252 usage:0];
			[_container endAccumulationBlock];
			[mesh setMaterial:material];
			_mapPartDrawables[y][x] = [[SMK_GL_Drawable alloc] initWithMesh:mesh];
		}
	}
}

- (void)_drawMoonInContext:(id)aContext
{
	SMK_GL_Matrix translation, rotation, matrix;
	translateMatrix(&translation, &_moonPosition);
	rotateMatrix(&rotation, -_moonRotation, &_kZAxis);
	matrix_mul(&matrix, &translation, &rotation);
	[_moonDrawable setMatrix:&matrix];
	glEnable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	[_moonDrawable drawInContext:aContext];
	glDisable(GL_CULL_FACE);
}

// Draws the star sphere (its two halves) and works out where the sun is on
// screen. The globe view's orthographic camera gets a perspective
// projection for the stars.
- (void)_drawStarsInContext:(id)aContext
{
	BOOL globe = [GlobeScreenSaverDefaults pointOfViewMode] == 1;
	if (globe) {
		NSSize size = [(SMK_GL_Context *)aContext size];
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		gluPerspective(60.0, (double)(float)(size.width / size.height), 0.5, 100.0);
	}
	if ([GlobeScreenSaverDefaults starsEnabled]) {
		SMK_GL_Matrix matrix;
		matrix_make_identity(&matrix);
		[_starsDrawable setMatrix:&matrix];
		[_starsDrawable drawInContext:aContext];
		rotateMatrix(&matrix, 3.1415927f, &_kZAxis);
		[_starsDrawable setMatrix:&matrix];
		[_starsDrawable drawInContext:aContext];
	}
	SMK_GL_Matrix modelView, projection, transform;
	glGetFloatv(GL_MODELVIEW_MATRIX, (GLfloat *)&modelView);
	glGetFloatv(GL_PROJECTION_MATRIX, (GLfloat *)&projection);
	matrix_transpose(&modelView);
	matrix_transpose(&projection);
	matrix_mul(&transform, &projection, &modelView);
	SMK_GL_Vec3 light = [_globeUtils lightDirection];
	SMK_GL_Vec3 sun = { _starsRadius * light.x, _starsRadius * light.y, _starsRadius * light.z };
	vec3_transfrom(&_sunScreenPos, &transform, &sun);
	if (globe) {
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(GL_MODELVIEW);
	}
}

- (void)_initGlobeViewSceneObjectsIfNeededForContext:(id)aContext
{
	[self _initCommonSceneObjectsIfNeededForContext:aContext];
	if (!_sceneGlobeViewObjectsWasInited) {
		_sceneGlobeViewObjectsWasInited = YES;
	}
}

- (void)_initSateliteViewSceneObjectsIfNeededForContext:(id)aContext
{
	[self _initCommonSceneObjectsIfNeededForContext:aContext];
	if (!_sceneSateliteViewObjectsWasInited) {
		[_container beginAccumulationBlock];
		[self _createMapPartDrawables];
		[_container endAccumulationBlock];
		[_textureLoader preloadHiResolutionTextures];
		_sceneSateliteViewObjectsWasInited = YES;
	}
}

- (void)_initCommonSceneObjectsIfNeededForContext:(id)aContext
{
	if (!_sceneCommonObjectsWasInited) {
		[_container beginAccumulationBlock];
		[self _createGlobeParts];
		[self _createLowResMap];
		[self _createMoon];
		[self _createCloudsMaterials];
		[self _createStarsDrawable];
		[_container endAccumulationBlock];
		_sceneCommonObjectsWasInited = YES;
	}
}

- (void)_createLowResMap
{
	_eastLowResMapMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	[_eastLowResMapMaterial setTexture:[_textureLoader textureForLOD:0 xPart:0 yPart:0] atStage:0];
	[_eastLowResMapMaterial setDiffuse:_kWhite];
	_westLowResMapMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	[_westLowResMapMaterial setTexture:[_textureLoader textureForLOD:0 xPart:1 yPart:0] atStage:0];
	[_westLowResMapMaterial setDiffuse:_kWhite];
}

- (void)_createCloudsMaterials
{
	_eastCloudsMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	[_eastCloudsMaterial setTexture:[_textureLoader cloudsEastTexture] atStage:0];
	_westCloudsMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	[_westCloudsMaterial setTexture:[_textureLoader cloudsWestTexture] atStage:0];
}

- (void)_createStarsDrawable
{
	struct SMKGL_anon11 params = { _starsRadius, 32, 16, 0, 2, 0, 1 };
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSpherePartWithParams:&params container:_container fvf:0x102 usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	[material setAmbient:_kWhite];
	[material setDiffuse:_kBlack];
	_starsTexture = [_textureLoader starsTexture];
	[_starsTexture setWrapS:GL_REPEAT T:GL_REPEAT];
	[_starsTexture retain];
	SMK_GL_Matrix textureMatrix;
	matrix_make_identity(&textureMatrix);
	textureMatrix._11 = 2.0f;
	textureMatrix._22 = 2.0f;
	[_starsTexture setTransformMatrix:&textureMatrix];
	[material setTexture:_starsTexture atStage:0];
	_starsDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	_flaresTexture = [_textureLoader flaresTexture];
	[_flaresTexture retain];
	mesh = [SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(-0.5, -0.5, 1.0, 1.0) xSegments:2 ySegments:2 container:_container
	                                      fvf:0x102 usage:0];
	material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[mesh setMaterial:material];
	[material setAmbient:_kWhite];
	[material setDiffuse:_kBlack];
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
	[material setAmbient:ambient];
	[material setDiffuse:_kWhite];
	[material setTexture:[_textureLoader moonTexture] atStage:0];
	_moonDrawable = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
}

- (void)_createGlobeParts
{
	struct SMKGL_anon11 params = { _earthRadius, 48, 48, 0, 2, 0, 1 };
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createSpherePartWithParams:&params container:_container fvf:0x252 usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	[material setDiffuse:_kWhite];
	[mesh setMaterial:material];
	_earthHemisphere = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	_cityGlowsMaterial = [[SMK_GL_Material alloc] initWithContainer:_container];
	[_cityGlowsMaterial setAmbient:_kBlack];
	[_cityGlowsMaterial setDiffuse:_kWhite];
	[self _createGlowWithSegments:params.f2 << 2 radius:_earthRadius];
}

// the atmosphere ring: three circles in the y-z plane from inside to outside
// the globe edge, textured with a fading blue
- (void)_createGlowWithSegments:(NSInteger)aSegments radius:(CGFloat)aRadius
{
	int segments = (int)aSegments;
	SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:0x102 usage:0 verticesCount:segments * 3 + 3
	                                            primitivesCount:segments << 2 primitiveType:4] autorelease];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	[vertexBuffer setAutoUpdateBounds:NO];
	float *vertex = [vertexBuffer lock:2];
	for (int ring = -1; ring != 2; ring++) {
		float level = (float)ring;
		float ringRadius = level * _glowThickness + (float)aRadius;
		for (int i = 0; i <= segments; i++) {
			float t = (float)i / (float)segments;
			double angle = (double)(t * 6.2831855f);
			float sine = (float)sin(angle);
			float cosine = (float)cos(angle);
			vertex[0] = 0.0f;
			vertex[1] = cosine * ringRadius;
			vertex[2] = sine * ringRadius;
			vertex[3] = t;
			vertex[4] = (level < 0.0f ? -level : level) * 0.98f + 0.01f;
			vertex += 5;
		}
	}
	[vertexBuffer unlock];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	if ([indexBuffer are32BitIndices])
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:@"GlobeGLScene.m"
		                                                lineNumber:0x148 description:@"Index buffer must be in 16-bit format"];
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
	[_atmosphereGlow setPerformsVisibilityCheck:NO];
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
	[material setAmbient:_kWhite];
	[material setDiffuse:_kWhite];
	[material setTexture:texture atStage:0];
}

- (void)_createCameras
{
	if (_sateliteModeCamera == nil) {
		_sateliteModeCamera = [[SMK_GL_Camera alloc] init];
		[_sateliteModeCamera setMinZ:_earthRadius * 0.02f maxZ:100.0];
		SMK_GL_Vec3 position = { _cameraOrbitRadius, 0.0f, 0.0f };
		[_sateliteModeCamera setPosition:&position];
		SMK_GL_Vec3 viewDirection = { -1.0f, 0.0f, 0.0f };
		[_sateliteModeCamera setViewDirection:&viewDirection];
		SMK_GL_Vec3 upVector = { 0.0f, 0.0f, 1.0f };
		[_sateliteModeCamera setUpVector:&upVector];
		[_sateliteModeCamera setFov:45.0];
	}
	if (_globeModeCamera != nil) {
		return;
	}
	_globeModeCamera = [[SMK_GL_OrthoCamera alloc] init];
	[_globeModeCamera setMinZ:2.0 maxZ:20.0];
	SMK_GL_Vec3 position = { 10.0f, 0.0f, 0.0f };
	[_globeModeCamera setPosition:&position];
	SMK_GL_Vec3 viewDirection = { -1.0f, 0.0f, 0.0f };
	[_globeModeCamera setViewDirection:&viewDirection];
	SMK_GL_Vec3 upVector = { 0.0f, 0.0f, 1.0f };
	[_globeModeCamera setUpVector:&upVector];
}

// The satellite circles the globe in the tilted camera plane while the
// globe turns under it. It looks ahead and down at a point short of the
// horizon, and slowly rolls. In the globe view the camera circles the
// equator.
- (void)_refreshCameraSettings
{
	float angle = _frame * _cameraSpeed;
	if ([GlobeScreenSaverDefaults pointOfViewMode] == 0) {
		double a = (double)angle;
		float orbit = _cameraOrbitRadius;
		float s = (float)sin(a) * orbit;
		SMK_GL_Vec3 position = { orbit * (float)cos(a), s, 0.0f };
		SMK_GL_Vec3 ahead = { -s, position.x, 0.0f };
		vec3_normalize(&ahead);
		ahead.x *= _earthRadius;
		ahead.y *= _earthRadius;
		ahead.z *= _earthRadius;
		SMK_GL_Matrix spin, transform;
		rotateMatrix(&spin, _earthSpeed * _frame, &_kZAxis);
		matrix_mul(&transform, &spin, &_cameraPlaneMatrix);
		vec3_transfrom(&_cameraSpacePosition, &transform, &position);
		vec3_transfrom(&_lookAtSpacePosition, &transform, &ahead);
		SMK_GL_Vec3 view = _lookAtSpacePosition;
		vec3_normalize(&view);
		SMK_GL_Vec3 up = _cameraSpacePosition;
		vec3_normalize(&up);
		[self _rotateVectors:&up v2:&view byAngle:(float)atan(0.6073713302612305)];
		float distance = _earthRadius * 0.60737133f;
		_lookAtSpacePosition.x = distance * view.x + _cameraSpacePosition.x;
		_lookAtSpacePosition.y = distance * view.y + _cameraSpacePosition.y;
		_lookAtSpacePosition.z = distance * view.z + _cameraSpacePosition.z;
		[self _rotateVectors:&up v2:&view byAngle:0.07853982f];
		float roll = _frame * _rollSpeed;
		float rs = -sinf(roll);
		float rc = cosf(roll);
		SMK_GL_Vec3 side = { view.y * up.z - view.z * up.y, view.z * up.x - up.z * view.x,
		                     up.y * view.x - view.y * up.x };
		SMK_GL_Vec3 rolled = { side.x * rs + up.x * rc, side.y * rs + rc * up.y, side.z * rs + rc * up.z };
		[_sateliteModeCamera setPosition:&_cameraSpacePosition];
		[_sateliteModeCamera setViewDirection:&view];
		[_sateliteModeCamera setUpVector:&rolled];
		return;
	}
	float radius = _cameraOrbitRadius * 10.0f;
	double a = (double)((float)[GlobeScreenSaverDefaults globeSpinningDirection] * angle);
	float s = (float)sin(a) * radius;
	float c = radius * (float)cos(a);
	SMK_GL_Vec3 view = { -c, -s, 0.0f };
	vec3_normalize(&view);
	_cameraSpacePosition = (SMK_GL_Vec3){ c, s, 0.0f };
	SMK_GL_Vec3 up = { 0.0f, 0.0f, 1.0f };
	[_globeModeCamera setPosition:&_cameraSpacePosition];
	[_globeModeCamera setViewDirection:&view];
	[_globeModeCamera setUpVector:&up];
}

// turns two orthogonal unit vectors by an angle in their plane
- (void)_rotateVectors:(SMK_GL_Vec3 *)aVectors v2:(SMK_GL_Vec3 *)aV2 byAngle:(CGFloat)aAngle
{
	SMK_GL_Vec3 a = *aVectors, b = *aV2;
	float c = cosf((float)aAngle);
	float s = sinf((float)aAngle);
	aVectors->x = a.x * c + b.x * s;
	aVectors->y = b.y * s + a.y * c;
	aVectors->z = s * b.z + a.z * c;
	aV2->x = -s * a.x + b.x * c;
	aV2->y = b.y * c + a.y * -s;
	aV2->z = c * b.z + a.z * -s;
}

@end
