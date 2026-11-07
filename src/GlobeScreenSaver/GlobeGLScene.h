#import "GlobeScreenSaverPrefix.h"


@interface GlobeGLScene : SMK_GL_Scene
{
    SMK_GL_ObjectsContainer *_container;
    GlobeUtils *_globeUtils;
    BOOL _sceneGlobeViewObjectsWasInited;
    BOOL _sceneSateliteViewObjectsWasInited;
    BOOL _sceneCommonObjectsWasInited;
    GlobeTextureLoader *_textureLoader;
    float _earthRadius;
    float _glowThickness;
    float _cameraOrbitRadius;
    SMK_GL_Drawable *_earthHemisphere;
    SMK_GL_Drawable *_atmosphereGlow;
    SMK_GL_Material *_cityGlowsMaterial;
    SMK_GL_Material *_eastLowResMapMaterial;
    SMK_GL_Material *_westLowResMapMaterial;
    SMK_GL_Drawable *_starsDrawable;
    SMK_GL_2DTexture *_starsTexture;
    float _starsRadius;
    SMK_GL_Drawable *_flaresDrawable;
    SMK_GL_2DTexture *_flaresTexture;
    SMK_GL_Vec3 _sunScreenPos;
    BOOL _wasVisible;
    SMK_GL_Drawable *_moonDrawable;
    float _moonOrbitRadius;
    SMK_GL_Vec3 _moonPosition;
    float _moonRotation;
    float _moonPhase;
    SMK_GL_Light *_sunLight;
    float _fadeFactor;
    float _startFadeFactor;
    double _fadeStartTime;
    float _cameraPlaneAngle;
    float _earthSpeed;
    float _cameraSpeed;
    float _rollSpeed;
    SMK_GL_Vec3 _cameraSpacePosition;
    SMK_GL_Vec3 _lookAtSpacePosition;
    SMK_GL_Matrix _cameraPlaneMatrix;
    SMK_GL_Matrix _glowMatrix;
    SMK_GL_Drawable * _mapPartDrawables[3][6];
    BOOL _wasFilled[3][6];
    float _frame;
    NSCalendarDate *_previousFrameDate;
    SMK_GL_Material *_eastCloudsMaterial;
    SMK_GL_Material *_westCloudsMaterial;
    struct GlobeScreenSaver_anon1 _partParams;
    SMK_GL_OrthoCamera *_globeModeCamera;
    SMK_GL_Camera *_sateliteModeCamera;
}
- (void)waitForStopLoadingThread;
- (void)prepareToAnimateNextFrameForFPS:(CGFloat)aFPS;
- (void)_calculateNextPositionForFPS:(CGFloat)aFPS;
- (void)drawObjectsInContext:(id)aContext;
- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
@end

@interface GlobeGLScene (Private)
- (BOOL)_testVisibleGlobePartMesh:(id)aMesh inContext:(id)aContext;
- (NSInteger)_testVisibleSpacePointOnglobe:(SMK_GL_Vec3 *)aOnglobe;
- (NSPoint)_geoPointFromSpacePoint:(SMK_GL_Vec3)aPoint onSphereRadius:(CGFloat)aRadius;
- (void)_endConfigSheet:(id)aSheet;
- (void)_defaultsChanged:(id)aChanged;
- (void)_getEarthProjectionCircleParameters:(float *)aParameters outCenter:(NSPoint *)aCenter;
- (SMK_GL_Vec3)get3DCoordinatesFromGeoPoint:(NSPoint)aPoint;
- (void)_setLightDirection:(SMK_GL_Vec3)aDirection;
- (void)_drawCityGlowsInContext:(id)aContext;
- (void)_drawCloudsInContext:(id)aContext;
- (void)_drawGlowInContext:(id)aContext;
- (void)_calculateGlowMatrix;
- (void)_drawSunGlowAtPosition:(SMK_GL_Vec3 *)aPosition inContext:(id)aContext;
- (void)_drawGlobeInContext:(id)aContext;
- (void)_createMapPartDrawables;
- (void)_drawMoonInContext:(id)aContext;
- (void)_drawStarsInContext:(id)aContext;
- (void)_initGlobeViewSceneObjectsIfNeededForContext:(id)aContext;
- (void)_initSateliteViewSceneObjectsIfNeededForContext:(id)aContext;
- (void)_initCommonSceneObjectsIfNeededForContext:(id)aContext;
- (void)_createLowResMap;
- (void)_createCloudsMaterials;
- (void)_createStarsDrawable;
- (void)_createAndSetupLights;
- (void)_createMoon;
- (void)_createGlobeParts;
- (void)_createGlowWithSegments:(NSInteger)aSegments radius:(CGFloat)aRadius;
- (void)_createCameras;
- (void)_refreshCameraSettings;
- (void)_rotateVectors:(SMK_GL_Vec3 *)aVectors v2:(SMK_GL_Vec3 *)aV2 byAngle:(CGFloat)aAngle;
@end

