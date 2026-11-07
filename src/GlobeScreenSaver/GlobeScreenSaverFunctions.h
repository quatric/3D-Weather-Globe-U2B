// Constants and plain C functions of the screen saver.
#import <Foundation/Foundation.h>
#include "SMK_GL_math.h"

extern NSString *const kUserDefaultsDidChangeNotification;
extern NSString *const kGlobeScreenSaverDefaultsDidChangeNotification;
extern NSString *const kEndConfigSheetNotification;
extern NSString *const kPointOfView;
extern NSString *const kSpinDirection;
extern NSString *const kStarsEnabled;
extern NSString *const kDayNightEnabled;
extern NSString *const kSunEnabled;
extern NSString *const kMoonEnabled;
extern NSString *const kCloudsEnabled;
extern NSString *const kSpinningSpeed;
extern NSString *const kZoom;
extern NSString *const kAnimationFPSKey;
extern NSString *const kCloudsFolder;
extern NSString *const kAtlasAppSuppFolder;
extern NSString *const kPathCompTable;

extern const float kEarthAxisAngle;
extern const SMK_GL_Vec3 kEarthAxisRotationVector;
extern const SMK_GL_Vec3 kEarthRotationVector;

// lens flare: 4 x 4 spots along the line from the sun through the center
extern const float kFlarePositions[4][4];
extern const float kFlareSizes[4][4];
extern const SMK_GL_Color kFlareColors[4][4];

extern NSString *sAtlasSupportFolder;
extern NSString *sCloudsFolder;

id _defaultSetCurrentDate(void);
void _spaceToEarthMatrix(float aYearPhase, float aDayPhase, SMK_GL_Matrix *aOut);
float _deg2radf(float aDegrees);
float _rad2degf(float aRadians);
float _angleInterVectors(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2);
SMK_GL_Vec3 _earthVecFromGeoPoint(NSPoint aPoint);
float _distanceOnSphereFromVecs(const SMK_GL_Vec3 *aVec1, const SMK_GL_Vec3 *aVec2, float aRadius);
SMK_GL_Vec3 _lightDirection_EarthSystem(float aYearPhase, float aDayPhase);
SMK_GL_Vec3 _moonDirection_EarthSystem(float aYearPhase, float aDayPhase, float aMoonPhase);
CGImageRef _CreateCGImageWithData(NSData *aData);
CGImageRef _CreateCGImageFromFile(NSString *aPath);
void _DrawCGImageIntoBitmap(CGImageRef aImage, void *aBitmap, size_t aWidth, size_t aHeight, int aBitsPerPixel);
