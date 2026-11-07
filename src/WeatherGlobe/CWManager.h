#import "WeatherGlobePrefix.h"


@interface CWManager : NSObject
{
    NSTimer *_updateTimer;
    NSMutableSet *_fetchingCloudsDates;
    CloudsManager *_cloudsManager;
    NSArray *_skyDescriptions;
    NSArray *_precipDescriptions;
    ImagesSequence *_weatherImages;
    ImagesSequence *_windImages;
    int _weatherInternetState;
}
+ (void)resetWeatherInternetState;
+ (BOOL)isWeatherInternetStateOK;
+ (id)windImagesForIconAtIndex:(NSInteger)aIndex;
+ (id)weatherImagesForIconAtIndex:(NSInteger)aIndex;
+ (id)cloudsManager;
+ (NSInteger)cloudMapsCountInDownloadQueue;
+ (void)scheduleCloudsReloadTask;
+ (void)unscheduleCloudsUpdateTask;
+ (void)scheduleCloudsUpdateTask;
+ (void)cancelLoadTaskForCityEntry:(id)aEntry forReport:(NSInteger)aReport;
+ (void)downloadForTask:(id)aTask finishedWithData:(id)aData error:(NSInteger)aError;
+ (void)postLoadTaskForCityEntry:(id)aEntry forReport:(NSInteger)aReport completeTarget:(id)aTarget completeSelector:(SEL)aSelector;
+ (id)sharedInstance;
- (void)_internetStateWasChanged:(id)aChanged;
- (NSInteger)_cloudMapsCountInDownloadQueue;
- (void)_mapLoadCompleteWithInfo:(id)aInfo data:(id)aData;
- (void)_stopCloudsUpdate;
- (void)_startCloudsUpdate;
- (void)downloadForTask:(id)aTask finishedWithData:(id)aData error:(NSInteger)aError;
- (void)_clearCloudsLoadingQueue;
- (void)_cloudsUpdateTimerProc:(id)aProc;
- (void)_postCloudsRequestForDate:(id)aDate isEast:(BOOL)aEast fileName:(id)aName;
- (id)parseXMLData:(id)aData forReportID:(id)aID entry:(id)aEntry;
- (void)_parseAstronomyReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary;
- (void)_parseExpandedReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary;
- (void)_parseExtendedReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary;
- (void)_parseCurrentReport:(struct __CFTree *)aReport forEntry:(id)aEntry toDictionary:(id)aDictionary;
- (void)_addAverageForEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary;
- (void)_addFirstNonZeroEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary;
- (void)_addFirstEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary;
- (void)_processWeatherDictionary:(id)aDictionary toDestination:(id)aDestination;
- (void)_addStringIfExistsInDictionary:(id)aDictionary forKey:(id)aKey toDictionary:(id)aDictionary2 withKey:(id)aKey2;
- (id)_headerForReport:(struct __CFXMLNode *)aReport;
- (struct __CFTree *)_copySubtreeWithDescriptor:(id)aDescriptor fromTree:(struct __CFTree *)aTree;
- (id)_allAttributesWithDescriptor:(id)aDescriptor fromTree:(struct __CFTree *)aTree;
- (id)_attributesForNode:(struct __CFXMLNode *)aNode;
- (void)dealloc;
- (void)_appWillTerminate:(id)aTerminate;
- (void)invalidate;
- (id)init;
- (void)_loadCSVs;
- (id)_parseSingleCSV:(id)aCSV;
@end

@interface NSDictionary (CWDownloadTaskComparision)
- (NSInteger)compareWithOtherTaskInfo:(id)aInfo;
@end

