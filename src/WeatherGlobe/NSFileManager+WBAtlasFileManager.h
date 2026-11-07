#import "WeatherGlobePrefix.h"


@interface NSFileManager (WBAtlasFileManager)
- (id)securityFilePath;
- (id)serialNumberPath;
- (id)routesFolder;
- (double)lastUpdateTimeForFile:(id)aFile;
- (id)filePathForExpiredReport:(NSInteger)aReport entryID:(id)aID;
- (id)filePathForReport:(NSInteger)aReport entryID:(id)aID;
- (id)rootFolderForReport:(NSInteger)aReport;
- (id)reportsDownloadFolder;
- (id)updatesDownloadFolder;
- (id)cloudsDownloadFolder;
- (id)sortedEntriesCachePath;
- (id)entriesCachePath;
- (id)atlasSharedFolder;
- (id)_appSupportFolder;
- (id)_folderWithName:(id)aName inFolder:(id)aFolder;
- (BOOL)_runAuthorizedTasks:(id)aTasks;
@end

