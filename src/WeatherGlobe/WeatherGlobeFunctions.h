// Plain C functions of the original binary (WeatherGlobeFunctions.m).
// Earth vectors are unit vectors in the Earth's frame (x through 0,0, z
// through the north pole); geo points are (longitude, latitude) in degrees;
// map points are the unit square of the flat map, (0,0) at -180,-90.

// a value split into degrees, minutes and seconds
typedef struct WGDegrees {
	float degrees;
	float minutes;
	float seconds;
	BOOL negative;
} WGDegrees;

NSUInteger _indexOfObjectFromCArraySorted(void *aKey, void *aArray, NSUInteger aCount, NSUInteger aStride,
                                          int (*aComparator)(void *aKey, void *aElement));
NSString *_atlasDBOriginalFilePath(void);
NSString *_atlasDBWorkingFilePath(void);
BOOL _isInternetAvailable(void);
void _fitClippedLabels(NSView *aView);

void _spaceToEarthMatrix(float aDayFraction, float aYearFraction, SMK_GL_Matrix *aOut);
SMK_GL_Vec3 _moonDirection_EarthSystem(float aDayFraction, float aYearFraction, float aMoonPhase);
SMK_GL_Vec3 _lightDirection_EarthSystem(float aDayFraction, float aYearFraction);
float _celsiusFromFahrenheit(float aValue);
float _fahrenheitFromCelsius(float aValue);
float _milesFromKilometers(float aValue);
float _inchesFromMiliBars(float aValue);
WGDegrees _degreesFromFloat(float aValue);
float _distanceOnEarthFromEarthVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2);
float _distanceInRadians(float aLat1, float aLong1, float aLat2, float aLong2);
float _distanceOnEarthFromGeoPoints(NSPoint aPoint1, NSPoint aPoint2);
float _distEstimationFromEarthVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2);
float _deg2radf(float aDegrees);
float _rad2degf(float aRadians);
SMK_GL_Vec3 _earthVecFromMapPoint(NSPoint aPoint);
SMK_GL_Vec3 _earthVecFromGeoPoint(NSPoint aPoint);
NSPoint _geoPointFromMapPoint(NSPoint aPoint);
NSPoint _mapPointFromGeoPoint(NSPoint aPoint);
NSPoint _mapPointFromEarthVec(const SMK_GL_Vec3 *aVec);
BOOL _pointInRect(NSPoint aPoint, NSRect aRect);
SMK_GL_Plane _planeFromPointAndNormal(const SMK_GL_Vec3 *aPoint, const SMK_GL_Vec3 *aNormal);
NSSize _radiansFromDegreesSize(NSSize aSize);
NSPoint _radiansFromDegreesPoint(NSPoint aPoint);
NSPoint _degreesFromRadiansPoint(NSPoint aPoint);
NSRect _mapRectFromGeoRect(NSRect aRect);
NSRect _geoRectFromMapRect(NSRect aRect);
NSRect _captionGeoRect(NSRect aViewGeoRect, NSRect aTexturesGeoRect, id aInfo, float aWidth, float aHeight, NSRect *aActualRect);
CGImageRef _CreateCGImageWithData(NSData *aData);
CGImageRef _CreateCGImageFromFile(NSString *aPath);
void _DrawCGImageIntoBitmap(CGImageRef aImage, void *aBitmap, size_t aWidth, size_t aHeight, int aBitsPerPixel);

NSSize _StringSizeForFont(const char *aString, SMK_GL_Font *aFont, float aXScale, float aYScale);
float *_TextureCoordsFromIconIndex(float *aCoords, int aIndex, unsigned int aColumns, unsigned int aRows, float aUOffset, float aUPadding);
void _FillVerticesForIcon(float **aVertices, int aIndex, float aX, float aY, float aWidth, float aHeight, float aUOffset, float aUPadding, unsigned int aColumns, unsigned int aRows);
void _ConvertNormalaizedCoordsToScreen(float *aPoint, float aWidth, float aHeight);
void _ConvertScreenCoordsToNormalized(float *aPoint, float aWidth, float aHeight);
void _ConvertNormalaizedRectToScreen(float *aRect, float aWidth, float aHeight);
void _ConvertScreenRectToNormalized(float *aRect, float aWidth, float aHeight);
float _CalculateScaleForCoordinates(float aX, float aY);

// label layout manager
typedef struct __opaqueLMContext *LMContext;
LMContext _LMCreate(float aPointRadius, float aMarkSize, float aXAnchor, float aYAnchor);
void _LMDestroy(LMContext aContext);
int _LMBeginBlock(LMContext aContext);
int _LMAddBasePoint(LMContext aContext, float aX, float aY);
int _LMAddRectangle(LMContext aContext, float aX, float aY, float aWidth, float aHeight, int aBasePoint);
int _LMEndBlock(LMContext aContext);
int _LMCalculateLayout(LMContext aContext);
int _LMTerminateLayoutCalculation(LMContext aContext);
int _LMGetRectangle(LMContext aContext, int aIndex, float *aRect);

// download task callbacks; _clearReportTaskCB takes a WGReportTaskContext
typedef struct WGReportTaskContext {
	id entry;
	int reportID;
} WGReportTaskContext;
int _clearCloudsCB(NSDictionary *aParameters, void *aContext);
int _clearReportTaskCB(NSDictionary *aParameters, void *aContext);
id _defaultSetCurrentDate(void);

// registration helpers
kern_return_t _getMacAdInfoLong(UInt8 *aMACAddress);
uint32_t _getMacAdInfo(void);
int _unstring(const char *aString, int aLength, uint32_t *aValue);
BOOL _digest(const char *aCode, uint32_t *aKind, uint32_t *aMAC);
void _makeRegNo(const UInt8 *aMACAddress, int aKind, char *aOut);
