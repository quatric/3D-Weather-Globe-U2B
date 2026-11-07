// Constants and plain C functions of the screen saver. The astronomy and
// image helpers are the same code as the app's (WeatherGlobeFunctions.m).
#import "GlobeScreenSaverPrefix.h"

NSString *const kUserDefaultsDidChangeNotification = @"UserDefaultsDidChangeNotification";
NSString *const kGlobeScreenSaverDefaultsDidChangeNotification = @"GlobeScreenSaverDefaultsDidChangeNotification";
NSString *const kEndConfigSheetNotification = @"EndConfigSheetNotification";
NSString *const kPointOfView = @"PointOfView";
NSString *const kSpinDirection = @"SpinDirection";
NSString *const kStarsEnabled = @"StarsEnabled";
NSString *const kDayNightEnabled = @"DayNightEnabled";
NSString *const kSunEnabled = @"SunEnabled";
NSString *const kMoonEnabled = @"MoonEnabled";
NSString *const kCloudsEnabled = @"CloudsEnabled";
NSString *const kSpinningSpeed = @"SpinningSpeed";
NSString *const kZoom = @"Zoom";
NSString *const kAnimationFPSKey = @"AnimationFPS";
NSString *const kCloudsFolder = @"CloudsFolderName";
NSString *const kAtlasAppSuppFolder = @"AtlasApplicationSupportFolderName";
NSString *const kPathCompTable = @"PathComponents";

NSString *sAtlasSupportFolder = nil;
NSString *sCloudsFolder = nil;

const float kEarthAxisAngle = 0.410152f;
const SMK_GL_Vec3 kEarthAxisRotationVector = { 1.0f, 0.0f, 0.0f };
const SMK_GL_Vec3 kEarthRotationVector = { 0.0f, 0.0f, 1.0f };

const float kFlarePositions[4][4] = {
	{ 1.7f, 1.5f, 1.3f, 1.01f },
	{ 1.0f, 1.0f, 0.55f, 0.5f },
	{ 0.45f, 0.3f, -0.2f, -0.3f },
	{ -0.35f, -0.45f, -0.7f, -0.85f },
};
const float kFlareSizes[4][4] = {
	{ 5.0f, 2.0f, 0.2f, 0.8f },
	{ 3.0f, 4.0f, 0.1f, 0.3f },
	{ 0.2f, 0.1f, 0.05f, 0.2f },
	{ 0.35f, 0.15f, 0.8f, 1.0f },
};
const SMK_GL_Color kFlareColors[4][4] = {
	{ { 0.2f, 0.15f, 0.15f, 1.0f }, { 0.25f, 0.2f, 0.1f, 1.0f }, { 0.3f, 0.3f, 0.1f, 1.0f }, { 0.2f, 0.1f, 0.0f, 1.0f } },
	{ { 0.8f, 0.9f, 1.0f, 1.0f }, { 1.0f, 0.9f, 0.8f, 1.0f }, { 0.1f, 0.25f, 0.4f, 1.0f }, { 0.1f, 0.25f, 0.4f, 1.0f } },
	{ { 0.1f, 0.2f, 0.4f, 1.0f }, { 0.2f, 0.3f, 0.1f, 1.0f }, { 0.6f, 0.4f, 0.2f, 1.0f }, { 0.35f, 0.25f, 0.1f, 1.0f } },
	{ { 0.35f, 0.25f, 0.2f, 1.0f }, { 0.25f, 0.25f, 0.3f, 1.0f }, { 0.1f, 0.2f, 0.3f, 1.0f }, { 0.1f, 0.15f, 0.05f, 1.0f } },
};

id _defaultSetCurrentDate(void)
{
	return [NSCalendarDate dateWithYear:2004 month:9 day:30 hour:1 minute:0 second:0 timeZone:nil];
}

// the rotation from space (the sun on -x) to the Earth's frame, for the
// fractions of the year and of the day
void _spaceToEarthMatrix(float aYearPhase, float aDayPhase, SMK_GL_Matrix *aOut)
{
	SMK_GL_Matrix day, tilt, both;
	rotateMatrix(&day, (aDayPhase + aDayPhase) * 3.1415927f - (aYearPhase + aYearPhase) * 3.1415927f,
	             &kEarthRotationVector);
	rotateMatrix(&tilt, -kEarthAxisAngle, &kEarthAxisRotationVector);
	matrix_mul(&both, &tilt, &day);
	matrix_invert(aOut, &both);
}

float _deg2radf(float aDegrees)
{
	return aDegrees * 0.017453292f;
}

float _rad2degf(float aRadians)
{
	return aRadians * 57.295776f;
}

float _angleInterVectors(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2)
{
	float dot = aVec1->x * aVec2->x + aVec1->y * aVec2->y + aVec1->z * aVec2->z;
	if (dot >= 1.0f) {
		return 0.0f;
	}
	if (dot <= -1.0f) {
		return 3.1415927f;
	}
	return acosf(dot);
}

SMK_GL_Vec3 _earthVecFromGeoPoint(NSPoint aPoint)
{
	float c = cosf((float)aPoint.y * 0.017453292f);
	SMK_GL_Vec3 result;
	result.z = sinf((float)aPoint.y * 0.017453292f);
	result.y = (float)sin((double)((float)aPoint.x * 0.017453292f)) * c;
	result.x = c * (float)cos((double)((float)aPoint.x * 0.017453292f));
	return result;
}

float _distanceOnSphereFromVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2, float aRadius)
{
	float dot = aVec1->x * aVec2->x + aVec1->y * aVec2->y + aVec1->z * aVec2->z;
	if (dot >= 1.0f) {
		return 0.0f * aRadius;
	}
	if (dot <= -1.0f) {
		return 3.1415927f * aRadius;
	}
	return acosf(dot) * aRadius;
}

// the direction light comes from: towards the sun
SMK_GL_Vec3 _lightDirection_EarthSystem(float aYearPhase, float aDayPhase)
{
	float angle = (aYearPhase + aYearPhase) * 3.1415927f;
	SMK_GL_Vec3 space = { -cosf(angle), sinf(angle), 0.0f };
	SMK_GL_Matrix matrix;
	_spaceToEarthMatrix(aYearPhase, aDayPhase, &matrix);
	SMK_GL_Vec3 result;
	vec3_transfrom(&result, &matrix, &space);
	result.x = -result.x;
	result.y = -result.y;
	result.z = -result.z;
	return result;
}

SMK_GL_Vec3 _moonDirection_EarthSystem(float aYearPhase, float aDayPhase, float aMoonPhase)
{
	float angle = aMoonPhase * 3.1415927f + aMoonPhase * 3.1415927f;
	SMK_GL_Vec3 space = { sinf(angle), cosf(angle), 0.0f };
	SMK_GL_Matrix matrix;
	_spaceToEarthMatrix(aYearPhase, aDayPhase, &matrix);
	SMK_GL_Vec3 result;
	vec3_transfrom(&result, &matrix, &space);
	return result;
}

CGImageRef _CreateCGImageWithData(NSData *aData)
{
	// the provider keeps the data alive, the decoder reads it lazily
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)aData);
	if (provider == NULL) {
		return NULL;
	}
	CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
	CFRelease(provider);
	return image;
}

CGImageRef _CreateCGImageFromFile(NSString *aPath)
{
	NSData *data = [NSData dataWithContentsOfFile:aPath];
	if (data == nil) {
		return NULL;
	}
	return _CreateCGImageWithData(data);
}

// aBitsPerPixel is 16 (xRGB 1555, little endian) or 32 (RGBA)
void _DrawCGImageIntoBitmap(CGImageRef aImage, void *aBitmap, size_t aWidth, size_t aHeight, int aBitsPerPixel)
{
	size_t bytesPerRow;
	size_t bitsPerComponent;
	CGBitmapInfo info;
	if (aBitsPerPixel == 16) {
		bytesPerRow = aWidth * 2;
		info = kCGBitmapByteOrder16Little | (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
		bitsPerComponent = 5;
	} else if (aBitsPerPixel == 32) {
		bytesPerRow = aWidth * 4;
		info = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
		bitsPerComponent = 8;
	} else {
		return;
	}
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(aBitmap, aWidth, aHeight, bitsPerComponent, bytesPerRow, space, info);
	CFRelease(space);
	if (context == NULL) {
		return;
	}
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGRect rect = CGRectMake(0, 0, (float)aWidth, (float)aHeight);
	CGContextClearRect(context, rect);
	CGContextDrawImage(context, rect, aImage);
	CFRelease(context);
}
