#import "GlobeScreenSaverPrefix.h"


@interface GlobeTextureLoader : NSObject
{
    SMK_GL_ObjectsContainer *_container;
    SMK_GL_2DTexture *_nightEastTexture;
    SMK_GL_2DTexture *_nightWestTexture;
    SMK_GL_2DTexture *_moonTexture;
    SMK_GL_2DTexture *_starsTexture;
    SMK_GL_2DTexture *_flaresTexture;
    SMK_GL_2DTexture *_normalsWestTexture;
    SMK_GL_2DTexture *_normalsEastTexture;
    SMK_GL_2DTexture *_cloudsEastTexture;
    SMK_GL_2DTexture *_cloudsWestTexture;
    NSMutableDictionary *_preloadedHiResolutionTextures;
    BOOL _hiResolutionTexturesWasLoaded;
    BOOL _needToStopLoadingThread;
    NSLock *_lock;
    NSLock *_jpgLock;
}
- (id)createTextureForMapPart;
- (BOOL)isHiResolutionTexturesWasLoaded;
- (void)waitForStopLoadingThread;
- (void)preloadHiResolutionTextures;
- (id)cloudsWestTexture;
- (id)cloudsEastTexture;
- (id)flaresTexture;
- (id)starsTexture;
- (id)moonTexture;
- (id)nightTextureForWest;
- (id)nightTextureForEast;
- (id)textureForLOD:(NSInteger)aLOD xPart:(NSInteger)aPart yPart:(NSInteger)aPart2;
- (void)fillTexture:(id)aTexture lod:(NSInteger)aLod xPart:(NSInteger)aPart yPart:(NSInteger)aPart2;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
@end

@interface GlobeTextureLoader (Private)
+ (id)_cloudsFileNameForDate:(id)aDate isEast:(BOOL)aEast forToday:(BOOL)aToday;
- (void)_preloadingThreadEntrypoint:(id)aEntrypoint;
- (id)_cloudsDownloadFolder;
- (id)_sharedAtlasFolder;
- (void)_fillBitmapRep:(id)aRep withContentsOfFile:(id)aFile;
- (void)_fillTexture:(id)aTexture withContentsOfFile:(id)aFile;
- (void)_loadDataBySMKJPGFromFile:(id)aFile width:(NSInteger)aWidth height:(NSInteger)aHeight bitDepth:(NSInteger)aDepth bitmap:(void *)aBitmap;
- (id)_createTextureWithContentsOfFile:(id)aFile use32Bit:(BOOL)aBit useGammaCorrection:(BOOL)aCorrection;
- (id)_pathForLOD:(NSInteger)aLOD xPart:(NSInteger)aPart yPart:(NSInteger)aPart2;
@end

