// Plain C functions of the original binary.
#import "WeatherGlobePrefix.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/network/IONetworkInterface.h>
#import <IOKit/network/IOEthernetController.h>


// binary search of a C array sorted by aComparator, which returns -1, 0 or 1
// comparing aKey with an element; NSNotFound for an empty array, otherwise
// the match or the index where the search ended
NSUInteger _indexOfObjectFromCArraySorted(void *aKey, void *aArray, NSUInteger aCount, NSUInteger aStride,
                                          int (*aComparator)(void *aKey, void *aElement))
{
	if (aCount == 0) {
		return NSNotFound;
	}
	unsigned int high = (unsigned int)aCount - 1;
	unsigned int low = 0;
	for (;;) {
		unsigned int start = low;
		if (high <= start) {
			return start;
		}
		unsigned int middle = (start + high) >> 1;
		int order = aComparator(aKey, (char *)aArray + aStride * middle);
		if (order == 0) {
			return middle;
		}
		if (order == 1) {
			low = middle;
			if (high - start == 1) {
				return start;
			}
		} else if (order == -1) {
			high = middle;
		}
	}
}

NSString *_atlasDBOriginalFilePath(void)
{
	return [[NSBundle mainBundle] pathForResource:kAtlasDBFileName ofType:@""];
}

NSString *_atlasDBWorkingFilePath(void)
{
	return [[[NSFileManager defaultManager] atlasSharedFolder] stringByAppendingPathComponent:kAtlasDBFileName];
}

// whether 1.1.1.1 is reachable without a connection being set up; posts
// kINetBecomeUnavailableNotification when it isn't
BOOL _isInternetAvailable(void)
{
	struct sockaddr_in address;
	memset(&address, 0, sizeof(address));
	address.sin_len = sizeof(address);
	address.sin_family = AF_INET;
	inet_aton("1.1.1.1", &address.sin_addr);
	SCNetworkReachabilityRef reachability =
	    SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (struct sockaddr *)&address);
	SCNetworkReachabilityFlags flags;
	Boolean valid = SCNetworkReachabilityGetFlags(reachability, &flags);
	CFRelease(reachability);
	if (!valid || !(flags & kSCNetworkReachabilityFlagsReachable) ||
	    ((flags & kSCNetworkReachabilityFlagsConnectionRequired) && !(flags & kSCNetworkReachabilityFlagsConnectionAutomatic))) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kINetBecomeUnavailableNotification object:nil];
		return NO;
	}
	return YES;
}

// the rotation from space (the sun on -x) to the Earth's frame for a time
// of day and of year, both fractions of a turn
void _spaceToEarthMatrix(float aDayFraction, float aYearFraction, SMK_GL_Matrix *aOut)
{
	SMK_GL_Matrix day, tilt, both;
	rotateMatrix(&day, (aYearFraction + aYearFraction) * 3.1415927f - (aDayFraction + aDayFraction) * 3.1415927f,
	             &kEarthRotationVector);
	rotateMatrix(&tilt, -kEarthAxisAngle, &kEarthAxisRotationVector);
	matrix_mul(&both, &tilt, &day);
	matrix_invert(aOut, &both);
}

SMK_GL_Vec3 _moonDirection_EarthSystem(float aDayFraction, float aYearFraction, float aMoonPhase)
{
	float angle = aMoonPhase * 3.1415927f + aMoonPhase * 3.1415927f;
	SMK_GL_Vec3 space = { sinf(angle), cosf(angle), 0.0f };
	SMK_GL_Matrix matrix;
	_spaceToEarthMatrix(aDayFraction, aYearFraction, &matrix);
	SMK_GL_Vec3 result;
	vec3_transfrom(&result, &matrix, &space);
	return result;
}

// the direction light comes from: towards the sun
SMK_GL_Vec3 _lightDirection_EarthSystem(float aDayFraction, float aYearFraction)
{
	float angle = (aDayFraction + aDayFraction) * 3.1415927f;
	SMK_GL_Vec3 space = { -cosf(angle), sinf(angle), 0.0f };
	SMK_GL_Matrix matrix;
	_spaceToEarthMatrix(aDayFraction, aYearFraction, &matrix);
	SMK_GL_Vec3 result;
	vec3_transfrom(&result, &matrix, &space);
	result.x = -result.x;
	result.y = -result.y;
	result.z = -result.z;
	return result;
}

float _celsiusFromFahrenheit(float aValue)
{
	return (aValue - 32.0f) * 0.5555556f;
}

float _fahrenheitFromCelsius(float aValue)
{
	return aValue * 1.8f + 32.0f;
}

float _milesFromKilometers(float aValue)
{
	return aValue / 1.609f;
}

float _inchesFromMiliBars(float aValue)
{
	return (aValue * 29.92f) / 1013.0f;
}

WGDegrees _degreesFromFloat(float aValue)
{
	WGDegrees result;
	result.degrees = floorf(fabsf(aValue));
	float minutes = (fabsf(aValue) - result.degrees) * 60.0f;
	result.minutes = floorf(minutes);
	result.negative = aValue < 0.0f;
	result.seconds = (minutes - result.minutes) * 60.0f;
	return result;
}

// the great circle distance in kilometers
float _distanceOnEarthFromEarthVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2)
{
	double x1 = aVec1->x, y1 = aVec1->y, z1 = aVec1->z;
	double x2 = aVec2->x, y2 = aVec2->y, z2 = aVec2->z;
	double n1 = 1.0 / sqrt(x1 * x1 + y1 * y1 + z1 * z1);
	double n2 = 1.0 / sqrt(x2 * x2 + y2 * y2 + z2 * z2);
	double cosine = x1 * n1 * x2 * n2 + y1 * n1 * y2 * n2 + z1 * n1 * z2 * n2;
	if (cosine > 1.0) {
		cosine = 1.0;
	} else if (cosine < -1.0) {
		cosine = -1.0;
	}
	return (float)(acos(cosine) * 6371.10009765625);
}

// the angle between two points given as radians (latitude, longitude)
float _distanceInRadians(float aLat1, float aLong1, float aLat2, float aLong2)
{
	double cosine = cos((double)(aLong2 - aLong1)) * cos((double)aLat1) * cos((double)aLat2) +
	                sin((double)aLat1) * sin((double)aLat2);
	if (cosine > 1.0) {
		cosine = 1.0;
	} else if (cosine < -1.0) {
		cosine = -1.0;
	}
	return (float)acos(cosine);
}

// The original passes the radians points as (x, y) pairs to
// _distanceInRadians, so x (the longitude) is used as the latitude.
float _distanceOnEarthFromGeoPoints(NSPoint aPoint1, NSPoint aPoint2)
{
	NSPoint from = _radiansFromDegreesPoint(aPoint1);
	NSPoint to = _radiansFromDegreesPoint(aPoint2);
	return _distanceInRadians(from.x, from.y, to.x, to.y) * 6371.1f;
}

// a cheap stand-in for distance, for sorting
float _distEstimationFromEarthVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2)
{
	return -(aVec1->x * aVec2->x + aVec1->y * aVec2->y + aVec1->z * aVec2->z);
}

float _deg2radf(float aDegrees)
{
	return aDegrees * 0.017453292f;
}

float _rad2degf(float aRadians)
{
	return aRadians * 57.295776f;
}

SMK_GL_Vec3 _earthVecFromMapPoint(NSPoint aPoint)
{
	float latitude = ((float)aPoint.y - 0.5f) * 3.1415927f;
	double longitude = (double)((((float)aPoint.x - 0.5f) + ((float)aPoint.x - 0.5f)) * 3.1415927f);
	float c = cosf(latitude);
	SMK_GL_Vec3 result;
	result.z = sinf(latitude);
	result.y = (float)sin(longitude) * c;
	result.x = c * (float)cos(longitude);
	return result;
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

NSPoint _geoPointFromMapPoint(NSPoint aPoint)
{
	float longitude = ((float)aPoint.x - 0.5f) * 360.0f;
	if (longitude > 180.0f) {
		longitude -= 360.0f;
	} else if (longitude < -180.0f) {
		longitude += 360.0f;
	}
	return NSMakePoint(longitude, ((float)aPoint.y - 0.5f) * 180.0f);
}

NSPoint _mapPointFromGeoPoint(NSPoint aPoint)
{
	return NSMakePoint((float)aPoint.x * 0.0027777778f + 0.5f, (float)aPoint.y * 0.0055555557f + 0.5f);
}

NSPoint _mapPointFromEarthVec(const SMK_GL_Vec3 *aVec)
{
	float x = aVec->x;
	float y = aVec->y;
	double dy = (double)y;
	float longitude = (float)asin(dy / sqrt((double)x * (double)x + dy * dy));
	float latitude = asinf(aVec->z);
	if (x < 0.0f) {
		longitude = (y <= 0.0f ? -3.1415927f : 3.1415927f) - longitude;
	}
	return NSMakePoint(longitude * 0.5f * 0.31830987f + 0.5f, latitude * 0.31830987f + 0.5f);
}

BOOL _pointInRect(NSPoint aPoint, NSRect aRect)
{
	float x = aPoint.x, y = aPoint.y;
	return !(x < (float)aRect.origin.x || (float)aRect.origin.x + (float)aRect.size.width < x ||
	         y < (float)aRect.origin.y || (float)aRect.origin.y + (float)aRect.size.height < y);
}

SMK_GL_Plane _planeFromPointAndNormal(const SMK_GL_Vec3 *aPoint, const SMK_GL_Vec3 *aNormal)
{
	SMK_GL_Plane plane;
	plane.a = aNormal->x;
	plane.b = aNormal->y;
	plane.c = aNormal->z;
	plane.d = aPoint->x * aNormal->x + aPoint->y * aNormal->y + aPoint->z * aNormal->z;
	return plane;
}

NSSize _radiansFromDegreesSize(NSSize aSize)
{
	return NSMakeSize((float)aSize.width * 0.017453292f, (float)aSize.height * 0.017453292f);
}

NSPoint _radiansFromDegreesPoint(NSPoint aPoint)
{
	return NSMakePoint((float)aPoint.x * 0.017453292f, (float)aPoint.y * 0.017453292f);
}

NSPoint _degreesFromRadiansPoint(NSPoint aPoint)
{
	return NSMakePoint((float)aPoint.x * 57.295776f, (float)aPoint.y * 57.295776f);
}

NSRect _mapRectFromGeoRect(NSRect aRect)
{
	return NSMakeRect((float)aRect.origin.x * 0.0027777778f + 0.5f, (float)aRect.origin.y * 0.0055555557f + 0.5f,
	                  (float)aRect.size.width * 0.0027777778f, (float)aRect.size.height * 0.0055555557f);
}

NSRect _geoRectFromMapRect(NSRect aRect)
{
	float longitude = ((float)aRect.origin.x - 0.5f) * 360.0f;
	if (longitude > 180.0f) {
		longitude -= 360.0f;
	} else if (longitude < -180.0f) {
		longitude += 360.0f;
	}
	return NSMakeRect(longitude, ((float)aRect.origin.y - 0.5f) * 180.0f,
	                  (float)aRect.size.width * 360.0f, (float)aRect.size.height * 180.0f);
}


// The part of a shape's geo rect aRect inside aBounds, trying the bounds a
// turn east and west when they miss. A shape spanning the whole longitude
// range, or one wider than the bounds that wraps over them, counts whole.
static NSRect __actualRect(NSRect aRect, NSRect aBounds)
{
	NSRect result;
	if (fabsf((float)aRect.size.width - 360.0f) < 0.01f
	    || ((float)aRect.size.width < (float)aBounds.size.width && 360.0f < (float)aRect.size.width + (float)aBounds.size.width
	        && NSIntersectsRect(aRect, aBounds) && (float)aBounds.size.width < 360.0f)) {
		result = aRect;
	} else {
		result = NSIntersectionRect(aRect, aBounds);
	}
	if (result.size.width == 0.0) {
		result = NSIntersectionRect(NSOffsetRect(aBounds, -360.0, 0.0), aRect);
		if (result.size.width == 0.0) {
			result = NSIntersectionRect(NSOffsetRect(aBounds, 360.0, 0.0), aRect);
		}
	}
	return result;
}

// Where to center a caption of aWidth x aHeight for a shape (an entry of the
// database with enclosingRect and maxPathBounds) seen in aViewGeoRect: on its
// largest part in view, or on all of it when that part is under half of it.
// aActualRect gets the shape's part within aTexturesGeoRect.
NSRect _captionGeoRect(NSRect aViewGeoRect, NSRect aTexturesGeoRect, id aInfo, float aWidth, float aHeight, NSRect *aActualRect)
{
	NSRect enclosing = [aInfo enclosingRect];
	NSRect maxBounds = [aInfo maxPathBounds];
	NSRect visible = __actualRect(maxBounds, aViewGeoRect);
	if ((float)visible.size.width * (float)visible.size.height * 2.0f < (float)maxBounds.size.width * (float)maxBounds.size.height) {
		visible = __actualRect(enclosing, aViewGeoRect);
	}
	NSRect caption = NSZeroRect;
	if (visible.size.width > 0.0) {
		caption = NSMakeRect(((float)visible.size.width - aWidth) * 0.5f + (float)visible.origin.x,
		                     ((float)visible.size.height - aHeight) * 0.5f + (float)visible.origin.y, aWidth, aHeight);
	}
	NSRect actual = __actualRect(enclosing, aTexturesGeoRect);
	if (aActualRect != NULL) {
		*aActualRect = actual;
	}
	return caption;
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

// Weather labels: the size of a string in an SMK_GL_Font, scaled to
// normalized view units, and quads textured with one icon of a grid texture.
NSSize _StringSizeForFont(const char *aString, SMK_GL_Font *aFont, float aXScale, float aYScale)
{
	float width = (float)NSZeroSize.width;
	float height = (float)NSZeroSize.height;
	int length = (int)strlen(aString);
	for (int i = 0; i < length; i++) {
		NSSize *size = [aFont sizeOfCharacter:(unsigned char)aString[i]];
		width = (float)size->width + width;
		if ((float)size->height > height)
			height = (float)size->height;
	}
	return NSMakeSize(aXScale * width * 0.5f, height * aYScale * 0.3f);
}

// icons are numbered from 1, left to right and top to bottom; aCoords gets
// u0, v0, u1, v1
float *_TextureCoordsFromIconIndex(float *aCoords, int aIndex, unsigned int aColumns, unsigned int aRows, float aUOffset, float aUPadding)
{
	float width = 1.0f / (float)aColumns + aUPadding;
	int row = (int)((unsigned int)(aIndex - 1) / aColumns + 1);
	float u = (float)(int)((aColumns - (aColumns * row - aIndex)) - 1) * width + aUOffset;
	float v = 1.0f - (float)row * (1.0f / (float)aRows);
	aCoords[0] = u;
	aCoords[1] = v;
	aCoords[2] = width + u;
	aCoords[3] = 1.0f / (float)aRows + v;
	return aCoords;
}

// writes 4 vertices of x, y, z, u, v at *aVertices and advances it
void _FillVerticesForIcon(float **aVertices, int aIndex, float aX, float aY, float aWidth, float aHeight, float aUOffset, float aUPadding, unsigned int aColumns, unsigned int aRows)
{
	float *v = *aVertices;
	float uv[4];
	_TextureCoordsFromIconIndex(uv, aIndex, aColumns, aRows, aUOffset, aUPadding);
	v[0] = aX;           v[1] = aY;            v[2] = 0.0f;  v[3] = uv[0];  v[4] = uv[1];
	v[5] = aX + aWidth;  v[6] = aY;            v[7] = 0.0f;  v[8] = uv[2];  v[9] = uv[1];
	v[10] = aX;          v[11] = aY + aHeight; v[12] = 0.0f; v[13] = uv[0]; v[14] = uv[3];
	v[15] = aX + aWidth; v[16] = aY + aHeight; v[17] = 0.0f; v[18] = uv[2]; v[19] = uv[3];
	*aVertices = v + 20;
}

// normalized coordinates run from -1 to 1, screen ones from 0 to the size
void _ConvertNormalaizedCoordsToScreen(float *aPoint, float aWidth, float aHeight)
{
	aPoint[0] = (aPoint[0] * 0.5f + 0.5f) * aWidth;
	aPoint[1] = (aPoint[1] * 0.5f + 0.5f) * aHeight;
}

void _ConvertScreenCoordsToNormalized(float *aPoint, float aWidth, float aHeight)
{
	aPoint[0] = (aPoint[0] / aWidth + aPoint[0] / aWidth) - 1.0f;
	aPoint[1] = (aPoint[1] / aHeight + aPoint[1] / aHeight) - 1.0f;
}

void _ConvertNormalaizedRectToScreen(float *aRect, float aWidth, float aHeight)
{
	aRect[3] = aHeight * aRect[3];
	aRect[2] = aWidth * aRect[2];
	aRect[1] = (aRect[1] * 0.5f + 0.5f) * aHeight;
	aRect[0] = aWidth * (aRect[0] * 0.5f + 0.5f);
}

void _ConvertScreenRectToNormalized(float *aRect, float aWidth, float aHeight)
{
	aRect[3] = aRect[3] / aHeight;
	aRect[2] = aRect[2] / aWidth;
	aRect[1] = (aRect[1] / aHeight + aRect[1] / aHeight) - 1.0f;
	aRect[0] = (aRect[0] / aWidth + aRect[0] / aWidth) - 1.0f;
}

// The label layout manager. Labels are rectangles attached to base points
// (the places they describe). Both are rasterised into a byte grid of
// cells; a label that overlaps something is moved to the free spot nearest
// the top right of its base point's square.

typedef struct LayoutGrid {
	unsigned char *cells;
	float x, y, width, height;
	float columns, rows;
} LayoutGrid;

typedef struct LayoutPoint {
	float x, y;
	float boundsX, boundsY, boundsWidth, boundsHeight;
	int cellIndex;          // top left cell of the point's square
	int cellsCount;         // side of the square in cells
} LayoutPoint;

typedef struct SLayoutRectangle {
	float x, y, width, height;
	int basePoint;
} SLayoutRectangle;

struct __opaqueLMContext {
	LayoutGrid *grid;
	int pointsCount;
	int pointsCapacity;
	LayoutPoint *points;
	int rectanglesCapacity;
	int rectanglesCount;
	SLayoutRectangle *rectangles;
	float scale;            // coordinates are scaled down by this, 0.25
	float xAnchor;          // where a point sits in its square, 0..1.7
	float yAnchor;
	float pointRadius;
	float markSize;         // side of the square marked around each point
	float cellSize;
	unsigned int flags;     // 1: stop calculating
};

void _MakeSLayoutRectangle(SLayoutRectangle *aRect, float aX, float aY, float aWidth, float aHeight, int aBasePoint)
{
	aRect->basePoint = aBasePoint;
	aRect->height = aHeight;
	aRect->width = aWidth;
	aRect->y = aY;
	aRect->x = aX;
}

void _MakeLayoutPoint(LayoutPoint *aPoint, float aX, float aY, int aUnused, float aBoundsX, float aBoundsY, float aBoundsWidth, float aBoundsHeight)
{
	aPoint->cellsCount = 0;
	aPoint->cellIndex = 0;
	aPoint->boundsHeight = aBoundsHeight;
	aPoint->boundsWidth = aBoundsWidth;
	aPoint->boundsY = aBoundsY;
	aPoint->boundsX = aBoundsX;
	aPoint->y = aY;
	aPoint->x = aX;
}

// the power of 10 that brings a coordinate to at least 20
float _CalculateScaleForCoordinates(float aX, float aY)
{
	float x = fabsf(aX);
	if (x == 0.0f && fabsf(aY) == 0.0f)
		return 1.0f;
	float scale;
	for (scale = 1.0f; (int)(scale * x) < 20; scale *= 10.0f)
		;
	return scale;
}

static void _LMFreeData(LMContext aContext)
{
	if (aContext->grid != NULL) {
		if (aContext->grid->cells != NULL)
			free(aContext->grid->cells);
		free(aContext->grid);
		aContext->grid = NULL;
	}
	if (aContext->points != NULL) {
		free(aContext->points);
		aContext->points = NULL;
	}
	if (aContext->rectangles != NULL) {
		free(aContext->rectangles);
		aContext->rectangles = NULL;
	}
}

void _LMDestroy(LMContext aContext)
{
	if (aContext == NULL)
		return;
	_LMFreeData(aContext);
	free(aContext);
}

int _LMBeginBlock(LMContext aContext)
{
	if (aContext != NULL)
		_LMFreeData(aContext);
	return 1;
}

int _LMAddBasePoint(LMContext aContext, float aX, float aY)
{
	if (aContext->points == NULL) {
		aContext->pointsCount = 0;
		aContext->pointsCapacity = 10;
		aContext->points = malloc(10 * sizeof(LayoutPoint));
	}
	if (aContext->scale < 0.0f) {
		aContext->scale = 0.25f;
		aContext->pointRadius = aContext->pointRadius * 0.25f;
	}
	float scale = aContext->scale;
	int index = aContext->pointsCount;
	if (index >= aContext->pointsCapacity) {
		aContext->pointsCapacity += 10;
		aContext->points = realloc(aContext->points, aContext->pointsCapacity * sizeof(LayoutPoint));
	}
	_MakeLayoutPoint(&aContext->points[index], scale * aX, aY * scale, 0,
	                 (float)NSZeroRect.origin.x, (float)NSZeroRect.origin.y, (float)NSZeroRect.size.width, (float)NSZeroRect.size.height);
	aContext->pointsCount++;
	return index;
}

// cell aIndex of the grid, cells outside it count as taken
static unsigned char _cell(const LayoutGrid *aGrid, int aColumns, int aRows, int aIndex)
{
	if (aIndex < 0 || aIndex >= aColumns * aRows)
		return 0xff;
	return aGrid->cells[aIndex];
}

// marks aLength cells from aIndex, clipped to the grid
static void _markCells(const LayoutGrid *aGrid, int aColumns, int aRows, int aIndex, int aValue, int aLength)
{
	int total = aColumns * aRows;
	if (aIndex < 0) {
		aLength += aIndex;
		aIndex = 0;
	}
	if (aIndex + aLength > total)
		aLength = total - aIndex;
	if (aLength > 0)
		memset(aGrid->cells + aIndex, aValue, aLength);
}

int _LMCalculateLayout(LMContext aContext)
{
	LayoutPoint *points = aContext->points;
	SLayoutRectangle *rect = aContext->rectangles;
	if (points == NULL || rect == NULL || aContext->grid == NULL)
		return 1;
	LayoutGrid *grid = aContext->grid;
	float gridX = grid->x, gridY = grid->y;
	int columns = (int)grid->columns, rows = (int)grid->rows;
	if (columns == 0 || rows == 0)
		return 1;
	float cellSize = aContext->cellSize;
	memset(grid->cells, 0, columns * rows);

	// a square around every base point, marked with the point's number
	int markSize = (int)((aContext->markSize / cellSize) * aContext->scale);
	int half = markSize / 2;
	int marker = aContext->pointsCount;
	for (int i = 0; i < aContext->pointsCount; ) {
		int column = (int)((points[i].x - gridX) / cellSize - (float)half);
		if (column < 0)
			column = 0;
		if (column > columns - 1)
			column = columns - 1;
		int row = (int)((points[i].y - gridY) / cellSize);
		if (row < 0)
			row = 0;
		if (row > rows - 1)
			row = rows - 1;
		i++;
		for (int r = row - half; r <= row + half; r++) {
			if (r > 0 && r < rows)
				_markCells(grid, columns, rows, columns * r + column, i, markSize);
		}
	}

	int rectanglesCount = aContext->rectanglesCount;
	unsigned int stop = aContext->flags & 1;
	for (int j = 0; j < rectanglesCount && !stop; j++, rect++) {
		marker++;
		stop = aContext->flags & 1;
		int width = (int)(rect->width / cellSize);
		int height = (int)(rect->height / cellSize);
		int row = (int)((rect->y - gridY) / cellSize);
		int column = (int)((rect->x - gridX) / cellSize);
		if (row > rows - 1)
			row = rows - 1;
		if (column > columns - 1)
			column = columns - 1;
		int rightSpace = columns - (width + column);
		int fitWidth = width;
		if (rightSpace < 0)
			fitWidth = (width - 1) + rightSpace;
		int bottom = height + row;
		int lastRow = bottom, fitHeight = height;
		if (rows - bottom < 0) {
			fitHeight = height - 1 + (rows - bottom);
			lastRow = row + fitHeight;
		}

		// samples 10 cells of the label, the middle one twice; it stays
		// where it is only if all of them and its centre are free
		int halfWidth = fitWidth / 2;
		int top = columns * row + column;
		int last = (lastRow - 1) * columns + column;
		int middle = (fitHeight / 2 + row) * columns;
		int freeCount = (_cell(grid, columns, rows, column + middle + (fitWidth / 3) * 2) == 0 ? 2 : 0)
		              + (_cell(grid, columns, rows, top) == 0)
		              + (_cell(grid, columns, rows, top + halfWidth) == 0)
		              + (_cell(grid, columns, rows, top + (fitWidth / 5) * 4) == 0)
		              + (_cell(grid, columns, rows, top + fitWidth - 1) == 0)
		              + (_cell(grid, columns, rows, last) == 0)
		              + (_cell(grid, columns, rows, last + halfWidth) == 0)
		              + (_cell(grid, columns, rows, last + fitWidth) == 0)
		              + (_cell(grid, columns, rows, last + fitWidth / 3) == 0)
		              + (_cell(grid, columns, rows, column + middle + (fitWidth / 5) * 3) == 0);
		BOOL moved = NO;
		if (freeCount < 11 || _cell(grid, columns, rows, halfWidth + middle + column) != 0) {
			// scan the base point's square row by row, right to left, for
			// the first spot where the label fits, else the freest one
			int step = ((float)width * 0.5f >= 2.0f) ? (int)((float)width * 0.5f) : 2;
			LayoutPoint *point = &points[rect->basePoint];
			int position = point->cellIndex;
			int firstColumn = position % columns;
			int rowStart = columns * (position / columns) + firstColumn;
			int lastColumn = firstColumn + point->cellsCount;
			int endRow = point->cellsCount + position / columns;
			int best = -1, bestRow = row, bestColumn = column;
			BOOL found = NO;
			for (; position < lastColumn + 1 + columns * endRow; position -= step) {
				if (stop)
					break;
				if (position <= rowStart)
					position = rowStart;
				row = position / columns;
				column = position % columns;
				if (column > firstColumn) {
					if (row >= endRow)
						break;
					if (_cell(grid, columns, rows, position) == 0) {
						int spotWidth = width;
						if (columns - column < width)
							spotWidth = columns - column;
						int w = spotWidth - 1;
						int spotHeight = rows - row;
						if (height <= spotHeight)
							spotHeight = height;
						int halfW = w / 2;
						int spotLast = column + (spotHeight - 1 + row) * columns;
						int spotMiddle = ((spotHeight - 1) / 2 + row) * columns + column;
						int count = (_cell(grid, columns, rows, spotLast + w / 4) == 0)
						          + (_cell(grid, columns, rows, position + halfW) == 0)
						          + (_cell(grid, columns, rows, position + w - 1) == 0)
						          + (_cell(grid, columns, rows, position + w / 3) == 0)
						          + (_cell(grid, columns, rows, position + (w / 3) * 2) == 0)
						          + (_cell(grid, columns, rows, spotLast) == 0)
						          + (_cell(grid, columns, rows, spotLast + halfW) == 0)
						          + (_cell(grid, columns, rows, spotLast + w - 1) == 0)
						          + (_cell(grid, columns, rows, spotMiddle + w) == 0);
						if (count > 8 && _cell(grid, columns, rows, spotMiddle + halfW) == 0) {
							bottom = height + row;
							rightSpace = columns - (width + column);
							found = YES;
							break;
						}
						if (count > best) {
							best = count;
							bestRow = row;
							bestColumn = column;
						}
						position -= halfW > 1 ? halfW : 2;
					}
				} else {
					// past the square's left edge: go to the next row's right end
					int nextRow = (row + 1) * columns;
					rowStart = firstColumn + nextRow;
					position = step + lastColumn - 1 + nextRow;
				}
			}
			if (!found) {
				bottom = height + bestRow;
				rightSpace = columns - (bestColumn + width);
				column = bestColumn;
				row = bestRow;
			}
			moved = YES;
		}
		if (rightSpace + 1 < 0)
			width = width + rightSpace;
		for (int r = row; r < bottom && r < rows; r++)
			_markCells(grid, columns, rows, r * columns + column, marker, width);
		if (moved) {
			rect->y = (float)row * cellSize + gridY;
			rect->x = (float)column * cellSize + gridX;
		}
	}
	return 1;
}

int _LMTerminateLayoutCalculation(LMContext aContext)
{
	aContext->flags |= 1;
	return 1;
}

// aRect gets x, y, width, height in the caller's coordinates
int _LMGetRectangle(LMContext aContext, int aIndex, float *aRect)
{
	SLayoutRectangle *rect = &aContext->rectangles[aIndex];
	float scale = aContext->scale;
	aRect[3] = rect->height / scale;
	aRect[2] = rect->width / scale;
	aRect[1] = rect->y / scale;
	aRect[0] = rect->x / scale;
	return 1;
}

LMContext _LMCreate(float aPointRadius, float aMarkSize, float aXAnchor, float aYAnchor)
{
	LMContext context = calloc(1, sizeof(struct __opaqueLMContext));
	context->pointRadius = aPointRadius;
	if (aXAnchor == 0.0f || aXAnchor > 1.7f || aXAnchor < -1.7f)
		aXAnchor = 1.0f;
	if (aYAnchor == 0.0f || aYAnchor > 1.7f || aYAnchor < -1.7f)
		aYAnchor = 1.0f;
	context->xAnchor = aXAnchor;
	context->yAnchor = aYAnchor;
	context->scale = -1.0f;
	context->markSize = aMarkSize;
	return context;
}

int _LMAddRectangle(LMContext aContext, float aX, float aY, float aWidth, float aHeight, int aBasePoint)
{
	if (aContext->rectangles == NULL) {
		aContext->rectanglesCount = 0;
		aContext->rectanglesCapacity = 10;
		aContext->rectangles = malloc(10 * sizeof(SLayoutRectangle));
	}
	float scale = aContext->scale;
	aHeight = aHeight * scale;
	// the first label's height sets the grid's cell size
	if (aContext->cellSize <= 0.0f) {
		float cellSize = ceilf(aHeight * 0.25f);
		if (cellSize < 1.0f)
			cellSize = 1.0f;
		aContext->cellSize = cellSize;
	}
	int index = aContext->rectanglesCount;
	if (index >= aContext->rectanglesCapacity) {
		aContext->rectanglesCapacity += 30;
		aContext->rectangles = realloc(aContext->rectangles, aContext->rectanglesCapacity * sizeof(SLayoutRectangle));
	}
	_MakeSLayoutRectangle(&aContext->rectangles[index], scale * aX, aY * scale, aWidth * scale, aHeight, aBasePoint);
	aContext->rectanglesCount++;
	LayoutPoint *point = &aContext->points[aBasePoint];
	NSRect bounds = NSUnionRect(NSMakeRect(point->boundsX, point->boundsY, point->boundsWidth, point->boundsHeight),
	                            NSMakeRect(scale * aX, aY * scale, aWidth * scale, aHeight));
	point->boundsX = (float)bounds.origin.x;
	point->boundsY = (float)bounds.origin.y;
	point->boundsWidth = (float)bounds.size.width;
	point->boundsHeight = (float)bounds.size.height;
	return index;
}

// sizes the grid to cover every base point's square
int _LMEndBlock(LMContext aContext)
{
	LayoutPoint *points = aContext->points;
	if (points == NULL)
		return 1;
	float radius = aContext->pointRadius;
	float cellSize = aContext->cellSize;
	int count = aContext->pointsCount;
	float side = radius + radius;
	float yOffset = radius * aContext->yAnchor;
	float xOffset = radius * aContext->xAnchor;
	NSRect bounds = NSZeroRect;
	for (int i = 0; i < count; i++) {
		bounds = NSUnionRect(bounds, NSMakeRect(points[i].x - xOffset, points[i].y - yOffset, side, side));
		points[i].cellsCount = (int)(side / cellSize);
	}
	LayoutGrid *grid = malloc(sizeof(LayoutGrid));
	aContext->grid = grid;
	grid->x = (float)bounds.origin.x;
	grid->y = (float)bounds.origin.y;
	grid->width = (float)bounds.size.width;
	grid->height = (float)bounds.size.height;
	int columns = (int)(grid->width / cellSize);
	int rows = (int)(grid->height / cellSize);
	grid->columns = (float)columns;
	grid->rows = (float)rows;
	grid->cells = malloc(columns * rows > 0 ? columns * rows : 1);
	for (int i = 0; i < count; i++) {
		int index = (int)(((points[i].x - xOffset) - grid->x) / cellSize) + (int)(((points[i].y - yOffset) - grid->y) / cellSize) * columns;
		points[i].cellIndex = index < 0 ? 0 : index;
	}
	return 1;
}

// download task callbacks for -[DownloadManager enumerateTasksWithCallback:context:]
// (returning 1 removes the task)
int _clearCloudsCB(NSDictionary *aParameters, void *aContext)
{
	return [[aParameters objectForKey:@"kRequestKind"] isEqual:@"MAP"];
}

int _clearReportTaskCB(NSDictionary *aParameters, void *aContext)
{
	WGReportTaskContext *context = aContext;
	if (context->entry == [aParameters objectForKey:@"kRequestEntry"] &&
	    context->reportID == [[aParameters objectForKey:@"kRequestedReportID"] intValue])
		return 1;
	return 0;
}

id _defaultSetCurrentDate(void)
{
	return [NSCalendarDate dateWithYear:2004 month:9 day:30 hour:1 minute:0 second:0 timeZone:nil];
}

// primary ethernet interface MAC address lookup
static kern_return_t _FindEthernetInterfaces(io_iterator_t *aMatchingServices)
{
	mach_port_t masterPort;
	kern_return_t result = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if (result != KERN_SUCCESS)
		return result;
	CFMutableDictionaryRef matching = IOServiceMatching(kIOEthernetInterfaceClass);
	if (matching != NULL) {
		CFMutableDictionaryRef property = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
		    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		if (property != NULL) {
			CFDictionarySetValue(property, CFSTR(kIOPrimaryInterface), kCFBooleanTrue);
			CFDictionarySetValue(matching, CFSTR(kIOPropertyMatchKey), property);
			CFRelease(property);
		}
	}
	return IOServiceGetMatchingServices(masterPort, matching, aMatchingServices);
}

static kern_return_t _GetMACAddress(io_iterator_t aIterator, UInt8 *aMACAddress)
{
	kern_return_t result = KERN_FAILURE;
	io_object_t interface;
	bzero(aMACAddress, 6);
	while ((interface = IOIteratorNext(aIterator)) != 0) {
		io_object_t controller;
		result = IORegistryEntryGetParentEntry(interface, kIOServicePlane, &controller);
		if (result == KERN_SUCCESS) {
			CFTypeRef data = IORegistryEntryCreateCFProperty(controller, CFSTR(kIOMACAddress), kCFAllocatorDefault, 0);
			if (data != NULL) {
				CFDataGetBytes(data, CFRangeMake(0, 6), aMACAddress);
				CFRelease(data);
			}
			IOObjectRelease(controller);
		}
		IOObjectRelease(interface);
	}
	return result;
}

kern_return_t _getMacAdInfoLong(UInt8 *aMACAddress)
{
	io_iterator_t iterator = 0;
	kern_return_t result = _FindEthernetInterfaces(&iterator);
	if (result == KERN_SUCCESS)
		result = _GetMACAddress(iterator, aMACAddress);
	IOObjectRelease(iterator);
	return result;
}

// the low four MAC address bytes, big endian
uint32_t _getMacAdInfo(void)
{
	UInt8 address[6];
	if (_getMacAdInfoLong(address) != KERN_SUCCESS)
		return 0xbadaddec;
	return ((uint32_t)address[2] << 24) | ((uint32_t)address[3] << 16) | ((uint32_t)address[4] << 8) | address[5];
}

// registration digits are hex nibbles, 0-9A-F or G-V
static int _digitValue(char aDigit)
{
	if (aDigit >= 'G')
		return aDigit - 'G';
	if (aDigit >= 'A')
		return aDigit - 'A' + 10;
	return aDigit - '0';
}

static char _getdigit(uint32_t aNibble)
{
	if (random() & 1)
		return (char)(aNibble + 'G');
	return (char)(aNibble < 10 ? aNibble + '0' : aNibble + 'A' - 10);
}

int _unstring(const char *aString, int aLength, uint32_t *aValue)
{
	uint32_t value = 0;
	int sum = 0;
	for (int i = 0; i < aLength; i++) {
		sum += aString[i];
		value = value * 16 + _digitValue(aString[i]);
	}
	*aValue = value;
	return sum;
}

// "WAxxxxxx-xxxxxxxx-xxxxxxxxcc": checks the checksum and extracts the kind and MAC part
BOOL _digest(const char *aCode, uint32_t *aKind, uint32_t *aMAC)
{
	if (aCode[0] != 'W' || aCode[1] != 'A' || aCode[8] != '-' || aCode[17] != '-')
		return NO;
	uint32_t a, b, c, check;
	int sum = _unstring(aCode + 2, 6, &a);
	sum += _unstring(aCode + 9, 8, &b);
	sum += _unstring(aCode + 18, 8, &c);
	_unstring(aCode + 26, 2, &check);
	if (check != (uint32_t)(sum & 0xff))
		return NO;
	*aKind = ((a << 8) ^ c) >> 24 & 0x3f;
	*aMAC = c ^ b;
	return YES;
}

static char *_putDigits(char *aOut, uint32_t aValue, int aCount, uint32_t *aSum)
{
	for (int i = 0; i < aCount; i++) {
		char digit = _getdigit(aValue >> 28);
		*aOut++ = digit;
		*aSum += (unsigned char)digit;
		aValue <<= 4;
	}
	return aOut;
}

// builds the 24 character request id from the MAC address; aOut needs 25 bytes
void _makeRegNo(const UInt8 *aMACAddress, int aKind, char *aOut)
{
	srandom((unsigned)time(NULL));
	uint32_t key = (uint32_t)random();
	uint32_t sum = 0;
	uint32_t high = ((uint32_t)aMACAddress[0] << 8) | aMACAddress[1];
	uint32_t low = ((uint32_t)aMACAddress[2] << 24) | ((uint32_t)aMACAddress[3] << 16) |
	               ((uint32_t)aMACAddress[4] << 8) | aMACAddress[5];
	aOut = _putDigits(aOut, ((uint32_t)(aKind + 0x13) ^ key) << 24, 2, &sum);
	aOut = _putDigits(aOut, ((high ^ (key & 0xffff)) << 16) ^ key, 4, &sum);
	aOut = _putDigits(aOut, low ^ key, 8, &sum);
	aOut = _putDigits(aOut, key, 8, &sum);
	*aOut++ = _getdigit((sum & 0xff) >> 4);
	*aOut++ = _getdigit(sum & 0xf);
	*aOut = '\0';
}

// The nibs' one-line labels were sized for Lucida Grande; the current system
// font is wider and clips them ("Spac"). Widens each one that doesn't fit,
// keeping its alignment.
void _fitClippedLabels(NSView *aView)
{
	for (NSView *view in [aView subviews]) {
		if ([view isKindOfClass:[NSTextField class]]) {
			NSTextField *field = (NSTextField *)view;
			NSRect frame = [field frame];
			CGFloat needed = ceil([[field cell] cellSize].width);
			if (![field isEditable] && ![field isBezeled] && ![field isBordered] && frame.size.height < 24.0 &&
			    [[field stringValue] length] != 0 && needed > frame.size.width) {
				CGFloat extra = needed - frame.size.width;
				NSTextAlignment alignment = [field alignment];
				if (alignment == NSTextAlignmentCenter)
					frame.origin.x -= floor(extra / 2.0);
				else if (alignment == NSTextAlignmentRight)
					frame.origin.x -= extra;
				frame.size.width = needed;
				[field setFrame:frame];
			}
		}
		_fitClippedLabels(view);
	}
}
