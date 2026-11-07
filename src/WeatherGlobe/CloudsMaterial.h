#import "WeatherGlobePrefix.h"


@interface CloudsMaterial : SMK_GL_Material
{
    CloudsManager *_manager;
    double _prevCloudsChangeTime;
    int _cloudsFrameCount;
    BOOL _cloudsWereChanged;
    SMK_GL_2DTexture *_textureEast;
    SMK_GL_2DTexture *_textureWest;
    SMK_GL_2DTexture *_textureEastNext;
    SMK_GL_2DTexture *_textureWestNext;
    BOOL _eastMode;
}
- (void)bind;
- (void)checkCloudsTextures;
- (BOOL)hasTexturesForWest;
- (BOOL)hasTexturesForEast;
- (void)setLightingEnabled:(BOOL)aEnabled;
- (void)setIsEastBinding:(BOOL)aBinding;
- (void)_cloudsTextureSizeWasChanged:(id)aChanged;
- (void)_cloudMapWasDecompressed:(id)aDecompressed;
- (void)restoreAfterCleanup;
- (void)cleanup;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer cloudsManager:(id)aManager;
@end

