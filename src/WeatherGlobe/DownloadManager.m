#import "DownloadManager.h"


typedef int (*DownloadTaskCallback)(NSDictionary *aParameters, void *aContext);

static DownloadManager *_sDownloadManager = nil;
static BOOL _sDownloadManagerWasDeallocated = NO;
static NSString *const _sUserName = @"YA198T13305T";
static NSString *const _sUserPassword = @"YA198T13305T";
static NSString *const _kTaskDelegateKey = @"kTaskDelegate";
static NSString *const _kPostponedNotificationKey = @"kPostponedNotificationKey";
static NSString *const _typeKey = @"type";
static NSString *const _valKey = @"value";

// HTTP codes of the server; 250 carries a plist of actions
enum {
	kDMCodeOK = 200,
	kDMCodeUpdates = 201,
	kDMCodeActions = 250
};

static NSString *_serverHost(void)
{
	return [[NSBundle mainBundle] localizedStringForKey:@"host" value:@"" table:@"PathComponents"];
}

static id _bundleVersion(void)
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

static id _actionsFromData(NSData *aData)
{
	NSString *string = [[[NSString alloc] initWithBytes:[aData bytes] length:[aData length]
	                                           encoding:NSMacOSRomanStringEncoding] autorelease];
	return [string propertyList];
}

static FourCharCode _actionType(NSString *aType)
{
	char bytes[5] = {0};
	NSData *data = [aType dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	[data getBytes:bytes length:MIN([data length], (NSUInteger)4)];
	return ((FourCharCode)(unsigned char)bytes[0] << 24) | ((FourCharCode)(unsigned char)bytes[1] << 16) |
	       ((FourCharCode)(unsigned char)bytes[2] << 8) | (unsigned char)bytes[3];
}

@implementation DownloadManager

+ (id)downloadManager
{
	if (_sDownloadManager == nil && !_sDownloadManagerWasDeallocated)
		_sDownloadManager = [self new];
	return _sDownloadManager;
}

- (void)enumerateTasksWithCallback:(void *)aCallback context:(void *)aContext
{
	DownloadTaskCallback callback = (DownloadTaskCallback)aCallback;
	NSInteger count = [_activeConnections count];
	for (NSInteger i = 0; i < count; i++) {
		YAConnection *connection = [_activeConnections objectAtIndex:i];
		if (callback([[connection userInfo] objectForKey:kTaskParametersDictionary], aContext) == 1) {
			[connection terminate];
			[_activeConnections removeObjectAtIndex:i];
			i--;
			count--;
		}
	}
	count = [_tasksQueue count];
	for (NSInteger i = 0; i < count; i++) {
		if (callback([[_tasksQueue objectAtIndex:i] objectForKey:kTaskParametersDictionary], aContext) == 1) {
			[_tasksQueue removeObjectAtIndex:i];
			i--;
			count--;
		}
	}
	if ([_tasksQueue count] != 0 && [_activeConnections count] < (NSUInteger)_maxDownloads)
		[self _openNextConnection];
}

- (void)postDownloadTaskWithParameters:(id)aParameters delegate:(id)aDelegate
{
	if (_tasksQueue == nil)
		_tasksQueue = [NSMutableArray new];
	[_tasksQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:aParameters, kTaskParametersDictionary,
	                                                                  aDelegate, _kTaskDelegateKey, nil]];
	if ([_activeConnections count] < (NSUInteger)_maxDownloads)
		[self _openNextConnection];
}

- (void)setTaskQueueSortSelector:(SEL)aSelector
{
	_sortingSelector = aSelector;
}

- (void)setMaxSimultaneousDownloads:(NSInteger)aDownloads
{
	int previous = _maxDownloads;
	_maxDownloads = (int)aDownloads;
	if (previous < aDownloads)
		[self _openNextConnection];
}

- (void)enableReauthorizingOnNextDownload
{
	if (!_serverDeniedAuthorization) {
		_isAuthorized = NO;
		_authorizationWasDone = NO;
	}
}

- (void)resumeAuthorization
{
	_authorizationIsPostponed = NO;
	NSInteger count = [_postponedNotifications count];
	for (NSInteger i = 0; i < count; i++) {
		id notification = [[[[_postponedNotifications objectAtIndex:0] objectForKey:_kPostponedNotificationKey] retain] autorelease];
		[_postponedNotifications removeObjectAtIndex:0];
		[self _authRequestCompleted:notification];
	}
}

- (void)pauseAuthorization
{
	_authorizationIsPostponed = YES;
}

- (BOOL)isAuthorizing
{
	return _authorizationInProgress;
}

- (BOOL)authorizationFailedBecauseOfNoInternet
{
	return [self authorizationFailed] && _authorizationFailedBecauseOfNoInternet;
}

- (BOOL)authorizationFailed
{
	return _serverDeniedAuthorization || (!_isAuthorized && _authorizationWasDone);
}

- (BOOL)updateWithDelegate:(id)aDelegate
{
	if (_updateDelegate != nil)
		return NO;
	_updateDelegate = [aDelegate retain];
	[(id)aDelegate updateWillStartWithFilesCount:[_updateFilesToDownload count]];
	[self _downloadNextUpdateFile];
	return YES;
}

- (BOOL)updatesAreAvailable
{
	return [_updateFilesToDownload count] != 0;
}

- (void)_downloadNextUpdateFile
{
	if ([_updateFilesToDownload count] != 0) {
		@try {
			NSString *name = [[_updateFilesToDownload objectAtIndex:0] substringFromIndex:3];
			[_updateFilesToDownload removeObjectAtIndex:0];
			[(id)_updateDelegate fileWillBeDownloadedWithName:name];
			[self _getObject:name];
			return;
		} @catch (NSException *exception) {
		}
	}
	[self terminateUpdating];
}

- (void)_getObjectRequestCompleted:(id)aCompleted
{
	YAConnection *connection = [aCompleted object];
	NSString *name = [[[connection userInfo] retain] autorelease];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
	[connection release];
	short code = (short)[[[aCompleted userInfo] objectForKey:kConnectionLastErrorKey] intValue];
	NSData *data = [[aCompleted userInfo] objectForKey:kConnectionDataKey];
	NSInteger answer;

	if (code == kDMCodeOK) {
		if ([name isEqualToString:kAppleStoresFileName]) {
			[[AtlasDatabase database] setNewAppleStoresData:[data originalRepresentation]];
			return;
		}
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *path = [[manager updatesDownloadFolder] stringByAppendingPathComponent:[@"upd" stringByAppendingString:name]];
		do {
			NSInteger error;
			if ([data writeToFile:path atomically:YES]) {
				[manager setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777] forKey:NSFilePosixPermissions]
				          ofItemAtPath:path error:NULL];
				error = kDMCodeOK;
			} else {
				error = -20;
			}
			if (_updateDelegate == nil)
				return;
			answer = [(id)_updateDelegate fileWasDownloadedWithName:name error:error];
		} while (answer == 1);
		if (answer == 2) {
			[self _downloadNextUpdateFile];
			return;
		}
		if (answer != 0)
			return;
	} else if (code == kDMCodeActions) {
		id actions = _actionsFromData(data);
		NSAssert([actions respondsToSelector:@selector(count)], @"Broken plist returned - impossible to create array.");
		[self _processActions:actions];
		return;
	} else {
		if ((unsigned short)(code - 200) < 100)
			return;
		if ([name isEqualToString:kAppleStoresFileName])
			return;
		answer = [(id)_updateDelegate errorWithCodeCatched:code data:data];
		if (answer == 1) {
			[self _getObject:name];
			return;
		}
		if (answer != 0)
			return;
	}
	[_updateDelegate release];
	_updateDelegate = nil;
}

- (void)terminateUpdating
{
	[(id)_updateDelegate updateWasFinished];
	[_updateDelegate release];
	_updateDelegate = nil;
}

- (void)_refreshRequestCompleted:(id)aCompleted
{
	YAConnection *connection = [aCompleted object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
	[connection release];
	short code = (short)[[[aCompleted userInfo] objectForKey:kConnectionLastErrorKey] intValue];
	NSData *data = [[aCompleted userInfo] objectForKey:kConnectionDataKey];

	if (code == kDMCodeOK) {
		id stores = [data originalRepresentation];
		if (stores != nil)
			[[AtlasDatabase database] setNewAppleStoresData:stores];
	} else if (code == kDMCodeUpdates) {
		if ([data length] != 0)
			[self _processUpdatesFromData:data];
	} else if (code == kDMCodeActions) {
		if ([Preferences usesSoftwareUpdating]) {
			id actions = _actionsFromData(data);
			NSAssert([actions respondsToSelector:@selector(count)], @"Broken plist returned - impossible to create array.");
			[self _processActions:actions];
		}
	} else if ((unsigned short)(code - 200) >= 100) {
		if (++_numRefreshAttempts < 10)
			[self refreshDatabase];
	}
}

- (void)_processUpdatesFromData:(id)aData
{
	NSString *string = [[[[NSString alloc] initWithData:aData encoding:NSASCIIStringEncoding] autorelease] lowercaseString];
	if (string == nil)
		return;
	NSArray *names = [string componentsSeparatedByString:@";"];
	NSInteger count = [names count];
	if (count == 0)
		return;
	BOOL hasStores = [[names objectAtIndex:0] isEqualToString:kAppleStoresFileName];
	if (hasStores && [Preferences usesSoftwareUpdating])
		[self _getObject:[names objectAtIndex:0]];
	[_updateFilesToDownload release];
	_updateFilesToDownload = nil;
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *folder = [manager updatesDownloadFolder];
	for (NSInteger i = hasStores ? 1 : 0; i < count; i++) {
		NSString *fileName = [@"upd" stringByAppendingString:[names objectAtIndex:i]];
		NSString *path = [folder stringByAppendingPathComponent:fileName];
		if ([manager isReadableFileAtPath:path])
			continue;
		id request = [NSString selectFilenameFromUpdatesThatIsLike:fileName];
		if ([[[AtlasDatabase database] simpleSearchWithRequest:request] count] == 0) {
			if (_updateFilesToDownload == nil)
				_updateFilesToDownload = [NSMutableArray new];
			[_updateFilesToDownload addObject:fileName];
		}
	}
	if ([self updatesAreAvailable])
		[[NSNotificationCenter defaultCenter] postNotificationName:kNewUpdatesAreAvailableNotification object:self userInfo:nil];
}

- (void)_getObject:(id)aObject
{
	NSString *url = [NSString stringWithFormat:@"%@%@/%@", _serverHost(), kGetToken, aObject];
	YAConnection *connection = [[YAConnection alloc] initWithURLString:url method:@"POST" userInfo:nil];
	NSString *code = [self _registrationCode];
	NSString *sid = @"";
	if ([self _registrationIsValid])
		sid = code != nil ? code : @"";
	NSString *body = [NSString stringWithFormat:@"sid=%@&cfb=%@&dll=%d", sid, _bundleVersion(),
	                                            (int)[DynamicEnvironment currentVersion]];
	[connection setBody:[body dataUsingEncoding:NSASCIIStringEncoding]];
	[connection setUserName:_sUserName password:_sUserPassword];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_getObjectRequestCompleted:)
	                                             name:kConnectionClosedNotification object:connection];
	[connection setUserInfo:aObject];
	[connection fetch];
}

- (void)refreshDatabase
{
	NSString *code = [self _registrationCode];
	if (![self _registrationIsValid] || code == nil)
		code = @"";
	NSString *url = [NSString stringWithFormat:@"%@%@", _serverHost(), kRefreshToken];
	YAConnection *connection = [[YAConnection alloc] initWithURLString:url method:@"POST" userInfo:nil];
	int revision = [[[[AtlasDatabase database] appleStoresRep] objectForKey:@"revision"] intValue];
	NSString *body = [NSString stringWithFormat:@"sid=%@&cfb=%@&dll=%d&astores=%d", code, _bundleVersion(),
	                                            (int)[DynamicEnvironment currentVersion], revision];
	[connection setBody:[body dataUsingEncoding:NSASCIIStringEncoding]];
	NSAssert(connection != nil, @"Unable to create apple stores refresh connection");
	[connection setUserName:_sUserName password:_sUserPassword];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_refreshRequestCompleted:)
	                                             name:kConnectionClosedNotification object:connection];
	[connection fetch];
}

- (void)_startAuthorization
{
	_authorizationFailedBecauseOfNoInternet = NO;
	if (!_isInternetAvailable()) {
		_isAuthorized = NO;
		_authorizationFailedBecauseOfNoInternet = YES;
		[self _authRequestCompleted:nil];
		return;
	}
	_authorizationInProgress = YES;
	NSString *code = [self _registrationCode];
	YAConnection *connection;
	if (![self _registrationIsValid] || code == nil) {
		connection = [self _prepareRegistrationRequest];
	} else {
		NSString *url = [NSString stringWithFormat:@"%@%@", _serverHost(), kIdentifyToken];
		connection = [[YAConnection alloc] initWithURLString:url method:@"POST" userInfo:nil];
		NSString *body = [NSString stringWithFormat:@"sid=%@&cfb=%@&dll=%d", code, _bundleVersion(),
		                                            (int)[DynamicEnvironment currentVersion]];
		[connection setBody:[body dataUsingEncoding:NSASCIIStringEncoding]];
	}
	NSAssert(connection != nil, @"Unable to create identify connection");
	[connection setUserName:_sUserName password:_sUserPassword];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_authRequestCompleted:)
	                                             name:kConnectionClosedNotification object:connection];
	[connection fetch];
}

- (void)_authRequestCompleted:(id)aCompleted
{
	if (_authorizationIsPostponed) {
		if (_postponedNotifications == nil)
			_postponedNotifications = [NSMutableArray new];
		NSMutableDictionary *entry = [NSMutableDictionary dictionary];
		if (aCompleted != nil)
			[entry setObject:aCompleted forKey:_kPostponedNotificationKey];
		[_postponedNotifications addObject:entry];
		return;
	}
	YAConnection *connection = [aCompleted object];
	if (connection != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
		[connection release];
	}
	short code = (short)[[[aCompleted userInfo] objectForKey:kConnectionLastErrorKey] intValue];
	NSData *data = [[aCompleted userInfo] objectForKey:kConnectionDataKey];

	if (code == kDMCodeOK) {
		_isAuthorized = YES;
		_authorizationInProgress = NO;
		_authorizationWasDone = YES;
		[self _openNextConnection];
		return;
	}
	if (code == kDMCodeActions) {
		id actions = _actionsFromData(data);
		NSAssert([actions respondsToSelector:@selector(count)], @"Broken plist returned - impossible to create array.");
		if ([self _processActions:actions])
			return;
	}
	_authorizationInProgress = NO;
	_authorizationWasDone = YES;
	while ([_tasksQueue count] != 0) {
		id task = [[[_tasksQueue objectAtIndex:0] retain] autorelease];
		[_tasksQueue removeObjectAtIndex:0];
		[self _taskWithInfo:task finishedWithData:nil code:code];
	}
}

- (BOOL)_registrationIsValid
{
	const char *code = [[self _registrationCode] cStringUsingEncoding:NSASCIIStringEncoding];
	uint32_t kind, mac;
	return code != NULL && _digest(code, &kind, &mac) && kind == 0x28 && _getMacAdInfo() == mac;
}

- (id)_registrationCode
{
	NSString *code = [[NSUserDefaults standardUserDefaults] stringForKey:kRegistrationKey];
	if ([code length] < 28)
		return nil;
	return code;
}

- (id)_prepareRegistrationRequest
{
	NSString *frameworkPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Frameworks/SMKGL.framework"];
	id marker = [[[NSBundle bundleWithPath:frameworkPath] infoDictionary] objectForKey:@"CFBundleGetlnfoString"];
	NSMutableString *extra = [NSMutableString stringWithString:marker != nil ? @"&upd=7" : @""];
	NSDictionary *info = [WSSubscriptionController registrationInfo];
	if (info != nil)
		[extra appendFormat:@"&fname=%@&lname=%@&email=%@&country=%@", [info objectForKey:kWSRFirstNameKey],
		                    [info objectForKey:kWSRLastNameKey], [info objectForKey:kWSREmailKey], [info objectForKey:kWSRCountryKey]];
	NSString *url = [NSString stringWithFormat:@"%@%@", _serverHost(), kRegisterToken];
	YAConnection *connection = [[YAConnection alloc] initWithURLString:url method:@"POST" userInfo:nil];
	UInt8 address[6];
	char requestID[32];
	_getMacAdInfoLong(address);
	_makeRegNo(address, 0x28, requestID);
	NSString *body = [NSString stringWithFormat:@"sid=%s&cfb=%@&dll=%d%@", requestID, _bundleVersion(),
	                                            (int)[DynamicEnvironment currentVersion], extra];
	[connection setBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
	return connection;
}

- (void)_dylibLoadCompleted:(id)aCompleted
{
	YAConnection *connection = [aCompleted object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
	[connection release];
	short code = (short)[[[aCompleted userInfo] objectForKey:kConnectionLastErrorKey] intValue];
	NSData *data = [[aCompleted userInfo] objectForKey:kConnectionDataKey];
	_authorizationInProgress = NO;
	if (code == kDMCodeOK) {
		_isAuthorized = YES;
		_authorizationWasDone = YES;
		[DynamicEnvironment replaceDYLIBWithNew:data];
	}
	[self _openNextConnection];
}

- (BOOL)_runAlertWithRep:(id)aRep
{
	NSDictionary *button1 = [aRep objectForKey:@"button1"];
	NSDictionary *button2 = [aRep objectForKey:@"button2"];
	NSDictionary *button3 = [aRep objectForKey:@"button3"];
	NSString *message = [aRep objectForKey:@"text2"];
	NSInteger result = NSRunAlertPanel([aRep objectForKey:@"text1"], @"%@", [button1 objectForKey:@"text"],
	                                   [button2 objectForKey:@"text"], [button3 objectForKey:@"text"], message ? message : @"");
	NSDictionary *button = result == NSAlertDefaultReturn ? button1 : (result == NSAlertAlternateReturn ? button2 : button3);
	return [self _processActions:[button objectForKey:@"actions"]];
}

- (BOOL)_processActions:(id)aActions
{
	NSInteger count = [aActions count];
	for (NSInteger i = 0; i < count; i++) {
		NSDictionary *action = [aActions objectAtIndex:i];
		switch (_actionType([action objectForKey:_typeKey])) {
		case 'ourl':
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[action objectForKey:_valKey]]];
			break;
		case 'brek':
			return NO;
		case 'alrt':
			if (![self _runAlertWithRep:action])
				return NO;
			break;
		case 'invl':
			_authorizationInProgress = NO;
			_isAuthorized = NO;
			_serverDeniedAuthorization = YES;
			_authorizationWasDone = YES;
			[[NSNotificationCenter defaultCenter] postNotificationName:kInternetStateWasChanged object:self userInfo:nil];
			break;
		case 'ldll': {
			YAConnection *connection = [[YAConnection alloc] initWithURLString:[action objectForKey:@"value"] method:@"GET" userInfo:nil];
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_dylibLoadCompleted:)
			                                             name:kConnectionClosedNotification object:connection];
			[connection fetch];
			break;
		}
		case 'regs':
			if ([WSSubscriptionController registrationInfo] == nil && ![WSSubscriptionController runModal])
				return NO;
			break;
		case 'quit': {
			int value = [[action objectForKey:_valKey] intValue];
			if (value == 0 || value == 1) {
				[NSApp terminate:nil];
				return NO;
			}
			break;
		}
		case 'reld':
			_authorizationInProgress = NO;
			[self _openNextConnection];
			break;
		case 'ssid':
			[[NSUserDefaults standardUserDefaults] setObject:[action objectForKey:_valKey] forKey:kRegistrationKey];
			break;
		}
	}
	return YES;
}

- (void)_taskWithInfo:(id)aInfo finishedWithData:(id)aData code:(NSInteger)aCode
{
	id delegate = [aInfo objectForKey:_kTaskDelegateKey];
	[delegate downloadForTask:[aInfo objectForKey:kTaskParametersDictionary] finishedWithData:aData error:aCode];
}

- (void)_connectionClosed:(id)aClosed
{
	YAConnection *connection = [aClosed object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
	if (_activeConnections == nil)
		return;
	NSUInteger index = [_activeConnections indexOfObject:connection];
	if (index == NSNotFound)
		return;
	[_activeConnections removeObjectAtIndex:index];
	id info = [connection userInfo];
	int code = [[[aClosed userInfo] objectForKey:kConnectionLastErrorKey] intValue];
	NSData *data = [[aClosed userInfo] objectForKey:kConnectionDataKey];
	if (code == kDMCodeOK && data != nil) {
		[self _iNetBecomeAvailable];
	} else {
		if (code < 0)
			[self _iNetBecomeUnavailable];
		data = nil;
	}
	[self _taskWithInfo:info finishedWithData:data code:code];
	if ([_activeConnections count] < (NSUInteger)_maxDownloads)
		[self _openNextConnection];
}

- (void)_openNextConnection
{
	if (!_authorizationWasDone || !_isAuthorized) {
		if (!_authorizationInProgress)
			[self _startAuthorization];
		return;
	}
	if (_sortingSelector != NULL)
		[_tasksQueue sortUsingSelector:_sortingSelector];
	int slots = (int)[_tasksQueue count];
	int free = _maxDownloads - (int)[_activeConnections count];
	if (free < slots)
		slots = free;
	while (slots > 0 && [_tasksQueue count] != 0) {
		NSDictionary *task = [_tasksQueue objectAtIndex:0];
		if (task == nil)
			return;
		[[task retain] autorelease];
		[_tasksQueue removeObjectAtIndex:0];
		NSDictionary *parameters = [task objectForKey:kTaskParametersDictionary];
		YAConnection *connection = [[[YAConnection alloc] initWithURLString:[parameters objectForKey:kTaskParameterRequestString]
		                                                             method:[parameters objectForKey:kTaskParameterMethod]
		                                                           userInfo:task] autorelease];
		if (connection == nil) {
			[self _taskWithInfo:task finishedWithData:nil code:400];
		} else {
			@try {
				id userName = [parameters objectForKey:kTaskParameterUserName];
				id password = [parameters objectForKey:kTaskParameterUserPassword];
				if (userName != nil && password != nil)
					[connection setUserName:userName password:password];
				if (_activeConnections == nil)
					_activeConnections = [NSMutableArray new];
				[_activeConnections addObject:connection];
				[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_connectionClosed:)
				                                             name:kConnectionClosedNotification object:connection];
				[connection fetch];
			} @catch (NSException *exception) {
				[_activeConnections removeObject:connection];
				[[NSNotificationCenter defaultCenter] removeObserver:self name:kConnectionClosedNotification object:connection];
				[self _taskWithInfo:task finishedWithData:nil code:400];
			}
		}
		slots--;
	}
}

- (void)_iNetBecomeUnavailable
{
	_failedConnctions++;
	[[NSNotificationCenter defaultCenter] postNotificationName:kINetBecomeUnavailableNotification object:self];
}

- (void)_iNetBecomeAvailable
{
	if (_failedConnctions != 0)
		[[NSNotificationCenter defaultCenter] postNotificationName:kINetBecomeAvailableNotification object:self];
	_failedConnctions = 0;
}

- (void)_internetStateWasChanged:(id)aChanged
{
	if (_postponedDBRefresh && [Preferences usesInternet]) {
		_postponedDBRefresh = NO;
		[self refreshDatabase];
	}
}

- (void)_appWillTerminate
{
	[self invalidate];
}

- (void)dealloc
{
	[_tasksQueue release];
	[_activeConnections release];
	[_updateFilesToDownload release];
	[_postponedNotifications release];
	_sDownloadManager = nil;
	_sDownloadManagerWasDeallocated = YES;
	[super dealloc];
}

- (void)invalidate
{
	[_activeConnections makeObjectsPerformSelector:@selector(terminate)];
	[_activeConnections release];
	_activeConnections = nil;
	[_tasksQueue release];
	_tasksQueue = nil;
	[_updateDelegate release];
	_updateDelegate = nil;
	[self release];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appWillTerminate)
		                                             name:NSApplicationWillTerminateNotification object:nil];
		_maxDownloads = 4;
	}
	return self;
}

@end
