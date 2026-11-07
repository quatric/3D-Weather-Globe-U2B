#import "CWOnlineCityData.h"

// refresh period in hours for each report; only the first five reports exist
static const float _kReportsRefreshTime[] = {0.25f, 6.0f, 6.0f, 24.0f, 0.25f};
#define kReportsCount 30

@implementation CWOnlineCityData

- (id)dictionaryForReport:(NSInteger)aReport
{
    return [self _dictionaryForReport:aReport];
}

- (void)manualUpdateOfScheduledReports
{
    [self _singleUpdateTaskForReports:_scheduledReports manual:YES notifyIfExists:YES];
}

- (void)unscheduleReports:(NSUInteger)aReports
{
    _scheduledReports &= ~(unsigned int)[self _decScheduledReportsCount:aReports];
    if (_scheduledReports == 0) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)scheduleReports:(NSUInteger)aReports
{
    [self _incScheduledReportsCount:aReports];
    unsigned int previous = _scheduledReports;
    _scheduledReports = previous | (unsigned int)aReports;
    if (_timer == nil && _scheduledReports != 0)
        _timer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(_timerProc:) userInfo:nil repeats:YES];
    if (aReports != (aReports & previous))
        [self singleUpdateTaskForReports:aReports];
}

- (void)singleUpdateTaskForReports:(NSUInteger)aReports
{
    [self _singleUpdateTaskForReports:_scheduledReports manual:NO notifyIfExists:YES];
}

- (NSUInteger)_decScheduledReportsCount:(NSUInteger)aCount
{
    for (int i = 0; i < kReportsCount; i++) {
        unsigned int bit = 1u << i;
        if (aCount & bit) {
            if (--_scheduledReportsCount[i] == 0) {
                [self _cancelDownloadTaskForReport:i];
                [_downloadedReports removeObjectForKey:[self _keyForReport:i]];
            } else {
                aCount &= ~bit;
            }
        }
    }
    return aCount;
}

- (void)_incScheduledReportsCount:(NSUInteger)aCount
{
    for (int i = 0; i < kReportsCount; i++) {
        if (aCount & (1u << i))
            _scheduledReportsCount[i]++;
    }
}

- (void)_timerProc:(id)aProc
{
    if (_scheduledReports == 0) {
        [_timer invalidate];
        _timer = nil;
    } else {
        [self _singleUpdateTaskForReports:_scheduledReports manual:NO notifyIfExists:NO];
    }
}

- (void)_singleUpdateTaskForReports:(NSUInteger)aReports manual:(BOOL)aManual notifyIfExists:(BOOL)aExists
{
    BOOL usesInternet = [Preferences usesInternet];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    int known = sizeof(_kReportsRefreshTime) / sizeof(_kReportsRefreshTime[0]);
    for (int i = 0; i < kReportsCount; i++) {
        if (!(aReports & (1u << i)))
            continue;
        float refreshTime = i < known ? _kReportsRefreshTime[i] : 24.0f;
        float age = (float)((now - [self _lastUpdateTimeForReport:i]) / 3600.0);
        if (age >= refreshTime || aManual) {
            NSFileManager *manager = [NSFileManager defaultManager];
            [manager moveItemAtPath:[self _filePathForReport:i] toPath:[self _filePathForExpiredReport:i] error:NULL];
            [[_downloadedReports objectForKey:[self _keyForReport:i]] setObject:@"1" forKey:@"DATA_EXPIRED"];
            [self _postReportWasExpiredNotificationForReport:i];
            if (usesInternet)
                [self _postDownloadTaskForReport:i];
        } else if (aExists) {
            [self _postReportIsReadyNotificationForReport:i];
        }
    }
}

- (void)_cancelDownloadTaskForReport:(NSInteger)aReport
{
    if (_postedTasks[aReport]) {
        _postedTasks[aReport] = NO;
        [CWManager cancelLoadTaskForCityEntry:_entry forReport:aReport];
    }
}

- (void)_postDownloadTaskForReport:(NSInteger)aReport
{
    if (!_postedTasks[aReport]) {
        _postedTasks[aReport] = YES;
        [CWManager postLoadTaskForCityEntry:_entry forReport:aReport completeTarget:self completeSelector:@selector(_downloadComplete:)];
    }
}

- (void)_downloadComplete:(id)aComplete
{
    unsigned int report = [[aComplete objectForKey:kReportIDKey] unsignedIntValue];
    NSString *key = [self _keyForReport:report];
    NSDictionary *downloaded = [aComplete objectForKey:kReportDictionaryKey];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:downloaded];
    if (downloaded != nil) {
        [_downloadedReports setObject:dictionary forKey:key];
        NSString *path = [self _filePathForReport:report];
        BOOL written = [dictionary writeToFile:path atomically:YES];
        if (written) {
            NSFileManager *manager = [NSFileManager defaultManager];
            [manager setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777] forKey:NSFilePosixPermissions] ofItemAtPath:path error:NULL];
            [manager removeItemAtPath:[self _filePathForExpiredReport:report] error:NULL];
        }
        [dictionary setObject:@"0" forKey:@"DATA_EXPIRED"];
        [dictionary setObject:[NSNumber numberWithDouble:[self _lastUpdateTimeForReport:report]] forKey:@"DOWNLOAD_DATE"];
        [self _postReportIsReadyNotificationForReport:report];
        if (!written) {
            NSBundle *bundle = [NSBundle mainBundle];
            NSRunAlertPanel([bundle localizedStringForKey:@"No disk space title" value:@"" table:nil],
                            @"%@",
                            [bundle localizedStringForKey:@"Ok" value:@"" table:nil], nil, nil,
                            [bundle localizedStringForKey:@"No disk space message" value:@"" table:nil]);
        }
    }
    if (report < kReportsCount)
        _postedTasks[report] = NO;
}

- (void)_postReportWasExpiredNotificationForReport:(NSInteger)aReport
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(unsigned int)aReport], kReportIDKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kOnlineDataWasExpiredNotification object:self userInfo:info];
}

- (void)_postReportIsReadyNotificationForReport:(NSInteger)aReport
{
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(unsigned int)aReport], kReportIDKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kOnlineDataWasUpdatedNotification object:self userInfo:info];
}

- (id)_dictionaryForReport:(NSInteger)aReport
{
    NSString *key = [self _keyForReport:aReport];
    NSMutableDictionary *dictionary = [_downloadedReports objectForKey:key];
    if (dictionary != nil)
        return dictionary;
    dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[self _filePathForReport:aReport]];
    if (dictionary != nil) {
        [dictionary setObject:@"0" forKey:@"DATA_EXPIRED"];
        [dictionary setObject:[NSNumber numberWithDouble:[self _lastUpdateTimeForReport:aReport]] forKey:@"DOWNLOAD_DATE"];
        [_downloadedReports setObject:dictionary forKey:key];
    } else {
        dictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[self _filePathForExpiredReport:aReport]];
        if (dictionary != nil) {
            [dictionary setObject:@"1" forKey:@"DATA_EXPIRED"];
            [dictionary setObject:[NSNumber numberWithDouble:[self _lastUpdateTimeForExpiredReport:aReport]] forKey:@"DOWNLOAD_DATE"];
            [_downloadedReports setObject:dictionary forKey:key];
        }
    }
    return dictionary;
}

- (double)_lastUpdateTimeForExpiredReport:(NSInteger)aReport
{
    return [[NSFileManager defaultManager] lastUpdateTimeForFile:[self _filePathForExpiredReport:aReport]];
}

- (double)_lastUpdateTimeForReport:(NSInteger)aReport
{
    return [[NSFileManager defaultManager] lastUpdateTimeForFile:[self _filePathForReport:aReport]];
}

- (id)_filePathForExpiredReport:(NSInteger)aReport
{
    return [[NSFileManager defaultManager] filePathForExpiredReport:aReport entryID:_uniqueCityName];
}

- (id)_filePathForReport:(NSInteger)aReport
{
    return [[NSFileManager defaultManager] filePathForReport:aReport entryID:_uniqueCityName];
}

- (id)_keyForReport:(NSInteger)aReport
{
    return [NSString stringWithFormat:@"%d", (int)aReport];
}

- (void)dealloc
{
    [_downloadedReports release];
    [_uniqueCityName release];
    [super dealloc];
}

- (void)invalidate
{
    [_timer invalidate];
    [self release];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super init];
    if (self != nil) {
        _entry = aEntry;
        _downloadedReports = [NSMutableDictionary new];
        _uniqueCityName = [[NSString alloc] initWithFormat:@"%@(%@)", [_entry ownName], [_entry uid]];
    }
    return self;
}

@end
