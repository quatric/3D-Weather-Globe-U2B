#import "WeatherGlobePrefix.h"


@interface CWOnlineCityData : NSObject
{
    YACityEntry *_entry;
    NSTimer *_timer;
    NSString *_uniqueCityName;
    unsigned int _scheduledReports;
    unsigned int _scheduledReportsCount[30];
    BOOL _postedTasks[30];
    NSMutableDictionary *_downloadedReports;
}
- (id)dictionaryForReport:(NSInteger)aReport;
- (void)manualUpdateOfScheduledReports;
- (void)unscheduleReports:(NSUInteger)aReports;
- (void)scheduleReports:(NSUInteger)aReports;
- (void)singleUpdateTaskForReports:(NSUInteger)aReports;
- (NSUInteger)_decScheduledReportsCount:(NSUInteger)aCount;
- (void)_incScheduledReportsCount:(NSUInteger)aCount;
- (void)_timerProc:(id)aProc;
- (void)_singleUpdateTaskForReports:(NSUInteger)aReports manual:(BOOL)aManual notifyIfExists:(BOOL)aExists;
- (void)_cancelDownloadTaskForReport:(NSInteger)aReport;
- (void)_postDownloadTaskForReport:(NSInteger)aReport;
- (void)_downloadComplete:(id)aComplete;
- (void)_postReportWasExpiredNotificationForReport:(NSInteger)aReport;
- (void)_postReportIsReadyNotificationForReport:(NSInteger)aReport;
- (id)_dictionaryForReport:(NSInteger)aReport;
- (double)_lastUpdateTimeForExpiredReport:(NSInteger)aReport;
- (double)_lastUpdateTimeForReport:(NSInteger)aReport;
- (id)_filePathForExpiredReport:(NSInteger)aReport;
- (id)_filePathForReport:(NSInteger)aReport;
- (id)_keyForReport:(NSInteger)aReport;
- (void)dealloc;
- (void)invalidate;
- (id)initWithCityEntry:(id)aEntry;
@end

