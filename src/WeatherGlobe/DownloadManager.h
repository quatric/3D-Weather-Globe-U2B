#import "WeatherGlobePrefix.h"


@interface DownloadManager : NSObject
{
    BOOL _isAuthorized;
    BOOL _authorizationInProgress;
    BOOL _authorizationWasDone;
    BOOL _serverDeniedAuthorization;
    BOOL _authorizationFailedBecauseOfNoInternet;
    int _numRefreshAttempts;
    BOOL _postponedDBRefresh;
    BOOL _authorizationIsPostponed;
    NSMutableArray *_postponedNotifications;
    NSMutableArray *_updateFilesToDownload;
    NSObject *_updateDelegate;
    int _failedConnctions;
    NSMutableArray *_tasksQueue;
    int _maxDownloads;
    SEL _sortingSelector;
    NSMutableArray *_activeConnections;
}
+ (id)downloadManager;
- (void)enumerateTasksWithCallback:(void *)aCallback context:(void *)aContext;
- (void)postDownloadTaskWithParameters:(id)aParameters delegate:(id)aDelegate;
- (void)setTaskQueueSortSelector:(SEL)aSelector;
- (void)setMaxSimultaneousDownloads:(NSInteger)aDownloads;
- (void)enableReauthorizingOnNextDownload;
- (void)resumeAuthorization;
- (void)pauseAuthorization;
- (BOOL)isAuthorizing;
- (BOOL)authorizationFailedBecauseOfNoInternet;
- (BOOL)authorizationFailed;
- (BOOL)updateWithDelegate:(id)aDelegate;
- (BOOL)updatesAreAvailable;
- (void)_downloadNextUpdateFile;
- (void)_getObjectRequestCompleted:(id)aCompleted;
- (void)terminateUpdating;
- (void)_refreshRequestCompleted:(id)aCompleted;
- (void)_processUpdatesFromData:(id)aData;
- (void)_getObject:(id)aObject;
- (void)refreshDatabase;
- (void)_startAuthorization;
- (void)_authRequestCompleted:(id)aCompleted;
- (BOOL)_registrationIsValid;
- (id)_registrationCode;
- (id)_prepareRegistrationRequest;
- (void)_dylibLoadCompleted:(id)aCompleted;
- (BOOL)_runAlertWithRep:(id)aRep;
- (BOOL)_processActions:(id)aActions;
- (void)_taskWithInfo:(id)aInfo finishedWithData:(id)aData code:(NSInteger)aCode;
- (void)_connectionClosed:(id)aClosed;
- (void)_openNextConnection;
- (void)_iNetBecomeUnavailable;
- (void)_iNetBecomeAvailable;
- (void)_internetStateWasChanged:(id)aChanged;
- (void)_appWillTerminate;
- (void)dealloc;
- (void)invalidate;
- (id)init;
@end

