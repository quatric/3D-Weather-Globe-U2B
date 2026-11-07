#import "WeatherGlobePrefix.h"


@interface DynamicEnvironment : NSObject
{
    struct __CFBundle *_loadedBundle;
    void *_cloudsFuncPtr;
    void *_reportsFuncPtr;
    void *_reportsByIDFuncPtr;
    void *_xmlParserFuncPtr;
    void *_jpegParserFuncPtr;
    void *_getVerFuncPtr;
    void *_getReportUNFuncPtr;
    void *_getReportPFuncPtr;
    NSString *_dylibRootPath;
}
+ (void)replaceDYLIBWithNew:(id)aNew;
+ (id)jpegDataForCloudsData:(id)aData;
+ (id)xmlDataForReport:(NSInteger)aReport fromData:(id)aData;
+ (id)reportP;
+ (id)reportUN;
+ (id)URLForReportDownload:(NSInteger)aDownload cw_id:(NSInteger)aId;
+ (id)URLForReportDownload:(NSInteger)aDownload geoPoint:(NSPoint)aPoint;
+ (id)URLForCloudsWest:(BOOL)aWest date:(id)aDate size:(NSInteger)aSize;
+ (NSInteger)currentVersion;
+ (id)singleton;
- (id)jpegDataForCloudsData:(id)aData;
- (id)xmlDataForReport:(NSInteger)aReport fromData:(id)aData;
- (id)reportP;
- (id)reportUN;
- (id)URLForReportDownload:(NSInteger)aDownload cw_id:(NSInteger)aId;
- (id)URLForReportDownload:(NSInteger)aDownload geoPoint:(NSPoint)aPoint;
- (id)URLForCloudsWest:(BOOL)aWest date:(id)aDate size:(NSInteger)aSize;
- (NSInteger)currentVersion;
- (void)dealloc;
- (id)init;
- (void)replaceDYLIBWithNew:(id)aNew;
- (void)_unloadBundle;
- (void)_loadBundleIfNeeded;
- (id)_URLLibFullPath;
- (id)_tempURLLibRootPath;
- (id)_URLLibRootPath;
- (void)_createPluginBundleWithDYLIBBody:(id)aBody atPath:(id)aPath;
@end

