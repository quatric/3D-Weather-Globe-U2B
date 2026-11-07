#import "WeatherGlobePrefix.h"


@interface MapPartsLoader : NSObject
{
    NSMutableDictionary *_cachedDatas;
    NSMutableArray *_pathsForbiddenToRemove;
    NSRecursiveLock *_locker;
    NSConditionLock *_recacheLocker;
    BOOL _newRecacheParamsWereSpecified;
    BOOL _recacheTerminationRequested;
    BOOL _threadTerminationRequested;
    float _currXPos;
    float _currYPos;
    NSSize _currSize;
    int _currLOD;
    BOOL _cacheZoom;
    BOOL _use32BitsTextures;
    SMK_GL_2DTexture *_nightWestTexture;
    SMK_GL_2DTexture *_nightEastTexture;
}
+ (id)pathForMapTextureForLOD:(NSInteger)aLOD xPos:(NSInteger)aPos yPos:(NSInteger)aPos2;
- (NSInteger)_newThreadEnterFunc:(id)aFunc;
- (void)_textureWasCreated:(id)aCreated;
- (void)enable_cache_updates;
- (void)disable_cache_updates;
- (void)startBackgroundRecacheForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoomLevels:(BOOL)aLevels;
- (void)recacheMoveImagesForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD height:(CGFloat)aHeight;
- (void)_recacheZoomImagesForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoom:(BOOL)aZoom;
- (id)_imagesPathsForXPos:(CGFloat)aPos yPos:(CGFloat)aPos2 currentLOD:(NSInteger)aLOD size:(NSSize)aSize cacheZoom:(BOOL)aZoom;
- (id)nightTextureForContainer:(id)aContainer isEast:(BOOL)aEast;
- (void)fillBitmapRep:(id)aRep withContentsOfFile:(id)aFile;
- (void)fillTexture:(id)aTexture withContentsOfFile:(id)aFile;
- (id)createTextureWithContentsOfFile:(id)aFile container:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage withMaxBitDepth:(BOOL)aDepth;
- (void)_loadDataBySMKJPGFromFile:(id)aFile width:(NSInteger)aWidth height:(NSInteger)aHeight bitDepth:(NSInteger)aDepth bitmap:(void *)aBitmap;
- (id)nearestCachedLowResPathForLOD:(NSInteger)aLOD xPos:(NSInteger)aPos yPos:(NSInteger)aPos2 translation:(struct WeatherGlobe_anon5 *)aTranslation scaling:(struct WeatherGlobe_anon5 *)aScaling;
- (void)dealloc;
- (void)invalidate;
- (void)_stopCurrentRecache;
- (id)init;
@end

