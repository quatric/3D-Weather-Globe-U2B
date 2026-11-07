#import "WeatherGlobePrefix.h"


@interface CloudsManager : NSObject
{
    NSMutableArray *_decompressedFramesSequence;
    BOOL _doUpdateFramesInfo;
    NSMutableDictionary *_decompressedFramesMap;
    NSRecursiveLock *_decompMapLocker;
    NSMutableArray *_queueForDecompression;
    NSRecursiveLock *_queueLocker;
    NSConditionLock *_schedulerLock;
    BOOL _threadTerminationRequested;
    BOOL _useDefaultClouds;
}
+ (id)cloudsFileNameForDate:(id)aDate isEast:(BOOL)aEast forToday:(BOOL)aToday;
- (void)setUseDefaultClouds:(BOOL)aClouds;
- (id)currentCloudsBitmapReps;
- (NSUInteger)frameTextureFormat;
- (NSSize)frameTextureSize;
- (void)updateTexture:(id)aTexture withContentsOfFrame:(NSInteger)aFrame forEast:(BOOL)aEast;
- (NSInteger)framesCount;
- (void)_updateFramesIfNeeded;
- (NSInteger)_decompressionThreadEnterFunc:(id)aFunc;
- (void)_decompressJPGWithPath:(id)aPath;
- (id)_24bitBitmapWithPath:(id)aPath;
- (void)_decompressionSubtaskFinished;
- (void)removeCacheFiles;
- (void)restoreAfterCleanup;
- (void)cleanup;
- (void)_cloudsFilesWereUpdated:(id)aUpdated;
- (id)_allCloudsFileNames;
- (id)lastDownloadedCloudsFileNames;
- (void)_scheduleJPGToDecompress:(id)aDecompress;
- (void)removeDataForFile:(id)aFile;
- (void)dealloc;
- (void)invalidate;
- (id)init;
@end

