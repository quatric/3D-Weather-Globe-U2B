#import "CWManager.h"


static CWManager *_sCWManager = nil;
static BOOL _sCWManagerWasDeallocated = NO;

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil];
}

// the "clouds download failed" style alert with a "don't show again" checkbox
static void _runCloudsAlert(NSString *aTitleKey, NSString *aMessageKey)
{
	WBAlert *alert = [[[WBAlert alloc] initWithTitle:_localized(aTitleKey) body:_localized(aMessageKey)
	                                       rightButt:_localized(@"Ok") middleButt:nil leftButt:nil
	                                   checkboxTitle:_localized(@"DontShowAlertAgain") hasHelpButt:NO
	                                    defButtIndex:1 cancelButtIndex:0 hasCustomBgr:NO] autorelease];
	[alert runModal];
	[Preferences setShowCloudsDownloadFailedAlert:![alert dontShowAgain]];
}

@implementation CWManager

+ (void)resetWeatherInternetState
{
	CWManager *manager = [CWManager sharedInstance];
	if (manager->_weatherInternetState != 0) {
		manager->_weatherInternetState = 0;
		[[NSNotificationCenter defaultCenter] postNotificationName:kWeatherInternetStateWasChangedNotification object:self userInfo:nil];
	}
}

+ (BOOL)isWeatherInternetStateOK
{
	return ((CWManager *)[CWManager sharedInstance])->_weatherInternetState == 0;
}

+ (id)windImagesForIconAtIndex:(NSInteger)aIndex
{
	return [((CWManager *)[CWManager sharedInstance])->_windImages imagesForIconAtIndex:aIndex];
}

+ (id)weatherImagesForIconAtIndex:(NSInteger)aIndex
{
	return [((CWManager *)[CWManager sharedInstance])->_weatherImages imagesForIconAtIndex:aIndex];
}

+ (id)cloudsManager
{
	return ((CWManager *)[CWManager sharedInstance])->_cloudsManager;
}

+ (NSInteger)cloudMapsCountInDownloadQueue
{
	return [[CWManager sharedInstance] _cloudMapsCountInDownloadQueue];
}

+ (void)scheduleCloudsReloadTask
{
	[[self cloudsManager] removeCacheFiles];
	CWManager *manager = [CWManager sharedInstance];
	[manager _clearCloudsLoadingQueue];
	if (manager->_updateTimer != nil)
		[manager _cloudsUpdateTimerProc:manager->_updateTimer];
}

+ (void)unscheduleCloudsUpdateTask
{
	[[CWManager sharedInstance] _stopCloudsUpdate];
}

+ (void)scheduleCloudsUpdateTask
{
	CWManager *manager = [CWManager sharedInstance];
	if (!_isInternetAvailable()) {
		[manager->_cloudsManager setUseDefaultClouds:YES];
		if ([Preferences doShowCloudsDownloadFailedAlert])
			_runCloudsAlert(@"CloudsDownloadFailedTitle", @"CloudsDownloadFailedMessage");
		return;
	}
	[manager->_cloudsManager setUseDefaultClouds:NO];
	[manager _startCloudsUpdate];
}

+ (void)cancelLoadTaskForCityEntry:(id)aEntry forReport:(NSInteger)aReport
{
	if ([AccuWeatherClient isEnabled])
		[AccuWeatherClient cancelReport:aReport forEntry:aEntry];
	WGReportTaskContext context = { aEntry, (int)aReport };
	[[DownloadManager downloadManager] enumerateTasksWithCallback:_clearReportTaskCB context:&context];
}

+ (void)downloadForTask:(id)aTask finishedWithData:(id)aData error:(NSInteger)aError
{
	id target = [aTask objectForKey:@"kNotificationTarget"];
	SEL selector = NSSelectorFromString([aTask objectForKey:@"kNotificationSelectorString"]);
	id reportID = [aTask objectForKey:@"kRequestedReportID"];
	if (aError == 200 && aData != nil) {
		id xmlData = [DynamicEnvironment xmlDataForReport:[reportID intValue] fromData:aData];
		id report = [[CWManager sharedInstance] parseXMLData:xmlData forReportID:reportID entry:[aTask objectForKey:@"kRequestEntry"]];
		if (report != nil) {
			if (reportID != nil) {
				[target performSelector:selector withObject:[NSDictionary dictionaryWithObjectsAndKeys:report, kReportDictionaryKey,
				                                                                                       reportID, kReportIDKey, nil]];
				[self resetWeatherInternetState];
				return;
			}
			goto failed;
		}
	}
	if (reportID != nil)
		[target performSelector:selector withObject:[NSDictionary dictionaryWithObjectsAndKeys:reportID, kReportIDKey, nil]];
failed:;
	CWManager *manager = [CWManager sharedInstance];
	if (manager->_weatherInternetState != 0)
		return;
	manager->_weatherInternetState = 1;
	[[NSNotificationCenter defaultCenter] postNotificationName:kWeatherInternetStateWasChangedNotification object:self userInfo:nil];
}

+ (void)postLoadTaskForCityEntry:(id)aEntry forReport:(NSInteger)aReport completeTarget:(id)aTarget completeSelector:(SEL)aSelector
{
	// MacKiev's authorization server no longer accepts clients; AccuWeather
	// stands in when an API key is set
	if ([AccuWeatherClient isEnabled]) {
		NSDictionary *task = [NSDictionary dictionaryWithObjectsAndKeys:
		    [NSNumber numberWithUnsignedInt:(unsigned)aReport], @"kRequestedReportID",
		    aEntry, @"kRequestEntry",
		    aTarget, @"kNotificationTarget",
		    NSStringFromSelector(aSelector), @"kNotificationSelectorString", nil];
		[AccuWeatherClient loadReport:aReport forEntry:aEntry completion:^(NSData *aXML) {
			[CWManager downloadForTask:task finishedWithData:aXML error:aXML != nil ? 200 : 0];
		}];
		return;
	}
	if (((CWManager *)[CWManager sharedInstance])->_weatherInternetState != 0 &&
	    [[DownloadManager downloadManager] authorizationFailed]) {
		[aTarget performSelector:aSelector withObject:[NSDictionary dictionaryWithObjectsAndKeys:
		                                                   [NSNumber numberWithUnsignedInt:(unsigned)aReport], kReportIDKey, nil]];
		return;
	}
	NSInteger weatherID = [aEntry customWeatherID];
	id url;
	if (weatherID < 1)
		url = [DynamicEnvironment URLForReportDownload:aReport geoPoint:[aEntry coordinates]];
	else
		url = [DynamicEnvironment URLForReportDownload:aReport cw_id:weatherID];
	id userName = [DynamicEnvironment reportUN];
	id password = [DynamicEnvironment reportP];
	if (url == nil)
		return;
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
	    url, kTaskParameterRequestString,
	    @"GET", kTaskParameterMethod,
	    [NSNumber numberWithUnsignedInt:(unsigned)aReport], @"kRequestedReportID",
	    aEntry, @"kRequestEntry",
	    aTarget, @"kNotificationTarget",
	    NSStringFromSelector(aSelector), @"kNotificationSelectorString",
	    userName, kTaskParameterUserName,
	    password, kTaskParameterUserPassword, nil];
	[[DownloadManager downloadManager] postDownloadTaskWithParameters:parameters delegate:self];
}

+ (id)sharedInstance
{
	if (_sCWManager == nil && !_sCWManagerWasDeallocated)
		_sCWManager = [CWManager new];
	return _sCWManager;
}

- (void)_internetStateWasChanged:(id)aChanged
{
	BOOL usesInternet = [Preferences usesInternet];
	if (![Preferences cloudsEnabled])
		return;
	if (usesInternet) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kCloudsTextureSizeWasChanged object:self];
		[self _startCloudsUpdate];
	} else {
		[self _stopCloudsUpdate];
		[[NSNotificationCenter defaultCenter] postNotificationName:kCloudsTextureSizeWasChanged object:self];
	}
}

- (NSInteger)_cloudMapsCountInDownloadQueue
{
	return [_fetchingCloudsDates count];
}

- (void)_mapLoadCompleteWithInfo:(id)aInfo data:(id)aData
{
	if (aData == nil || [aData length] < 3)
		return;
	const unsigned char *bytes = [aData bytes];
	// JPEG SOI marker
	if (bytes[0] != 0xff || bytes[1] != 0xd8 || bytes[2] != 0xff)
		return;
	NSString *fileName = [aInfo objectForKey:@"MapFileName"];
	NSString *path = [[[NSFileManager defaultManager] cloudsDownloadFolder] stringByAppendingPathComponent:fileName];
	[_fetchingCloudsDates removeObject:fileName];
	if ([aData writeToFile:path atomically:YES]) {
		[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777] forKey:NSFilePosixPermissions]
		                                 ofItemAtPath:path error:NULL];
		[_cloudsManager removeDataForFile:path];
		[[NSNotificationCenter defaultCenter] postNotificationName:kCloudsWereUpdatedNotification object:self];
		return;
	}
	NSRunAlertPanel(_localized(@"No disk space title"), @"%@", _localized(@"Ok"), nil, nil, _localized(@"No disk space message"));
}

- (void)_stopCloudsUpdate
{
	[_updateTimer invalidate];
	_updateTimer = nil;
	[_cloudsManager cleanup];
	[self _clearCloudsLoadingQueue];
}

- (void)_startCloudsUpdate
{
	if (![Preferences usesInternet] || _updateTimer != nil)
		return;
	[_cloudsManager restoreAfterCleanup];
	_updateTimer = [NSTimer scheduledTimerWithTimeInterval:120.0 target:self selector:@selector(_cloudsUpdateTimerProc:)
	                                              userInfo:nil repeats:YES];
	[self _cloudsUpdateTimerProc:_updateTimer];
	[[NSNotificationCenter defaultCenter] postNotificationName:kCloudsWereUpdatedNotification object:self];
}

- (void)downloadForTask:(id)aTask finishedWithData:(id)aData error:(NSInteger)aError
{
	if (aError == 200 && aData != nil) {
		[self _mapLoadCompleteWithInfo:aTask data:aData];
		[_cloudsManager setUseDefaultClouds:NO];
		return;
	}
	if ([_fetchingCloudsDates count] == 0)
		return;
	[self _clearCloudsLoadingQueue];
	[_updateTimer invalidate];
	_updateTimer = nil;
	[_cloudsManager setUseDefaultClouds:YES];
	if (![[DownloadManager downloadManager] authorizationFailed]) {
		if ([Preferences doShowCloudsDownloadFailedAlert])
			_runCloudsAlert(@"CloudsDownloadFailedTitle", @"CloudsDownloadFailedMessage");
	} else if (![[DownloadManager downloadManager] authorizationFailedBecauseOfNoInternet]) {
		if ([Preferences doShowCloudsDownloadFailedAlert])
			_runCloudsAlert(@"AuthFailedOnCloudsRequestTitle", @"AuthFailedOnCloudsRequestMessage");
	}
}

- (void)_clearCloudsLoadingQueue
{
	[[DownloadManager downloadManager] enumerateTasksWithCallback:_clearCloudsCB context:NULL];
	[_fetchingCloudsDates removeAllObjects];
}

- (void)_cloudsUpdateTimerProc:(id)aProc
{
	NSCalendarDate *date = [NSCalendarDate calendarDate];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *folder = [manager cloudsDownloadFolder];
	NSInteger today = [date dayOfYear];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

	if ([Preferences usesInternet]) {
		// the last 12 maps, 6 hours apart; only one of them is "today's" map
		BOOL todayDone = NO;
		for (int i = 0; i < 12; i++) {
			BOOL isToday = [date dayOfYear] == today || (now - [date timeIntervalSinceReferenceDate]) / 3600.0 < 9.0;
			if (!isToday || !todayDone) {
				for (int east = 0; east < 2; east++) {
					NSString *fileName = [CloudsManager cloudsFileNameForDate:date isEast:east forToday:isToday];
					if ([_fetchingCloudsDates containsObject:fileName])
						continue;
					NSString *path = [folder stringByAppendingPathComponent:fileName];
					BOOL needed;
					if (isToday)
						needed = ![manager fileExistsAtPath:path] || (now - [manager lastUpdateTimeForFile:path]) / 3600.0 > 1.0;
					else
						needed = ![manager fileExistsAtPath:path];
					if (needed)
						[self _postCloudsRequestForDate:date isEast:east fileName:fileName];
				}
				if (isToday)
					todayDone = YES;
			}
			date = [date dateByAddingYears:0 months:0 days:0 hours:-6 minutes:0 seconds:0];
		}
	}

	// remove maps older than three days
	now = [NSDate timeIntervalSinceReferenceDate];
	NSArray *files = [manager contentsOfDirectoryAtPath:folder error:NULL];
	id lastFiles = [_cloudsManager lastDownloadedCloudsFileNames];
	NSInteger count = [files count];
	for (NSInteger i = 0; i < count; i++) {
		NSString *path = [folder stringByAppendingPathComponent:[files objectAtIndex:i]];
		NSTimeInterval age = now - [manager lastUpdateTimeForFile:path];
		if ((age < 0.0 || age > 259200.0) && ![lastFiles containsObject:path] && [manager isDeletableFileAtPath:path])
			[manager removeItemAtPath:path error:NULL];
	}
}

- (void)_postCloudsRequestForDate:(id)aDate isEast:(BOOL)aEast fileName:(id)aName
{
	NSInteger size = (NSInteger)(float)[_cloudsManager frameTextureSize].width;
	// MacKiev's cloud feed is gone; Live Cloud Maps only has the latest map,
	// which is kept as today's map and as the current six-hour frame
	if ([LiveCloudMaps isEnabled]) {
		if (![aName hasSuffix:@"_tooday.jpg"])
			return;
		NSString *frameName = [CloudsManager cloudsFileNameForDate:[NSCalendarDate calendarDate] isEast:aEast forToday:NO];
		NSDictionary *task = [NSDictionary dictionaryWithObjectsAndKeys:aName, @"MapFileName", nil];
		[_fetchingCloudsDates addObject:aName];
		[LiveCloudMaps loadMapForEast:aEast size:size completion:^(NSData *aJPEG) {
			if (aJPEG != nil)
				[self _mapLoadCompleteWithInfo:[NSDictionary dictionaryWithObject:frameName forKey:@"MapFileName"] data:aJPEG];
			[self downloadForTask:task finishedWithData:aJPEG error:aJPEG != nil ? 200 : 0];
		}];
		return;
	}
	id url = [DynamicEnvironment URLForCloudsWest:!aEast date:aDate size:size];
	if (url == nil)
		return;
	[_fetchingCloudsDates addObject:aName];
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:url, kTaskParameterRequestString,
	                                                                     @"GET", kTaskParameterMethod,
	                                                                     @"MAP", @"kRequestKind",
	                                                                     aName, @"MapFileName", nil];
	[[DownloadManager downloadManager] postDownloadTaskWithParameters:parameters delegate:self];
}

- (id)parseXMLData:(id)aData forReportID:(id)aID entry:(id)aEntry
{
	unsigned reportID = [aID unsignedIntValue];
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	CFXMLTreeRef tree = CFXMLTreeCreateFromData(kCFAllocatorDefault, (CFDataRef)aData, NULL,
	                                            kCFXMLParserSkipWhitespace, kCFXMLNodeCurrentVersion);
	if (tree == NULL)
		return result;
	CFXMLTreeRef report = [self _copySubtreeWithDescriptor:@"report" fromTree:tree];
	CFRelease(tree);
	if (report == NULL)
		return result;
	id header = [self _headerForReport:(struct __CFXMLNode *)CFXMLTreeGetNode(report)];
	if (header != nil)
		[result setObject:header forKey:@"HEADER"];
	switch (reportID) {
	case 0:
		[self _parseCurrentReport:report forEntry:aEntry toDictionary:result];
		break;
	case 1:
		[self _parseExtendedReport:report toDictionary:result];
		break;
	case 2:
		[self _parseExpandedReport:report toDictionary:result];
		break;
	case 3:
		[self _parseAstronomyReport:report toDictionary:result];
		break;
	}
	CFRelease(report);
	return result;
}

- (void)_parseAstronomyReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary
{
	CFXMLTreeRef forecast = [self _copySubtreeWithDescriptor:@"forecast" fromTree:aReport];
	if (forecast == NULL)
		return;
	NSDictionary *attributes = [self _attributesForNode:(struct __CFXMLNode *)CFXMLTreeGetNode(forecast)];
	CFRelease(forecast);
	[aDictionary setObject:[attributes objectForKey:@"city"] forKey:@"CITY_ID"];
	[aDictionary setObject:[attributes objectForKey:@"city_name"] forKey:@"CITY_NAME"];
	[aDictionary setObject:[attributes objectForKey:@"sunrise"] forKey:@"SUNRISE"];
	[aDictionary setObject:[attributes objectForKey:@"sunset"] forKey:@"SUNSET"];
	[aDictionary setObject:[attributes objectForKey:@"moonrise"] forKey:@"MOONRISE"];
	[aDictionary setObject:[attributes objectForKey:@"moonset"] forKey:@"MOONSET"];
	[aDictionary setObject:[attributes objectForKey:@"moon_phase"] forKey:@"MOONPHASE"];
}

- (void)_parseExpandedReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary
{
	CFXMLTreeRef location = [self _copySubtreeWithDescriptor:@"location" fromTree:aReport];
	if (location == NULL)
		return;
	NSArray *forecasts = [self _allAttributesWithDescriptor:@"forecast" fromTree:location];
	CFRelease(location);
	NSMutableArray *days = [NSMutableArray arrayWithCapacity:7];
	[aDictionary setObject:days forKey:@"SEVEN_FORECASTS"];
	NSInteger count = [forecasts count];
	for (NSInteger i = 0; i < count; i++) {
		NSMutableDictionary *day = [NSMutableDictionary dictionary];
		[days addObject:day];
		NSDictionary *forecast = [forecasts objectAtIndex:i];
		[self _processWeatherDictionary:forecast toDestination:day];
		[self _addStringIfExistsInDictionary:forecast forKey:@"day_of_week" toDictionary:day withKey:@"DAY_OF_WEEK"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"low_temp" toDictionary:day withKey:@"TEMPERATURE_LOW"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"high_temp" toDictionary:day withKey:@"TEMPERATURE_HIGH"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"precip_prob" toDictionary:day withKey:@"PRECIPTATIONS_PROBABILITY"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"rainfall" toDictionary:day withKey:@"RAINFALL"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"snowfall" toDictionary:day withKey:@"SNOWFALL"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"uv_index" toDictionary:day withKey:@"UV_INDEX"];
		[self _addStringIfExistsInDictionary:forecast forKey:@"uv" toDictionary:day withKey:@"UV_TEXT"];
	}
}

- (void)_parseExtendedReport:(struct __CFTree *)aReport toDictionary:(id)aDictionary
{
}

- (void)_parseCurrentReport:(struct __CFTree *)aReport forEntry:(id)aEntry toDictionary:(id)aDictionary
{
	NSArray *observations = [self _allAttributesWithDescriptor:@"observation" fromTree:aReport];
	NSArray *warnings = [self _allAttributesWithDescriptor:@"warning" fromTree:aReport];
	NSInteger count = [observations count];
	// AccuWeather's alerts; a lower priority number is more severe
	if (warnings != nil)
		[aDictionary setObject:[warnings sortedArrayUsingDescriptors:[NSArray arrayWithObject:
		    [NSSortDescriptor sortDescriptorWithKey:@"priority.intValue" ascending:YES]]] forKey:@"WARNINGS"];
	if (count == 0)
		return;
	NSMutableArray *dicts = [NSMutableArray array];
	NSInteger i;
	// collect observations until one has a sky or summary code
	for (i = 0; i < count; i++) {
		NSDictionary *observation = [observations objectAtIndex:i];
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		[dicts addObject:dict];
		[self _processWeatherDictionary:observation toDestination:dict];
		[self _addStringIfExistsInDictionary:observation forKey:@"temperature" toDictionary:dict withKey:@"TEMPERATURE"];
		[self _addStringIfExistsInDictionary:observation forKey:@"baro_pressure" toDictionary:dict withKey:@"BAROMETRIC_PRESSURE"];
		if ([[observation objectForKey:@"sky_desc"] intValue] != 0 || [[observation objectForKey:@"icon"] intValue] != 0)
			break;
	}
	if (i != 0 && i != count) {
		[self _addFirstNonZeroEntryWithKey:@"SUMMARY_CODE" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstNonZeroEntryWithKey:@"SKY_CODE" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstNonZeroEntryWithKey:@"PRECIPTATIONS_CODE" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstEntryWithKey:@"SUMMARY_TEXT" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstEntryWithKey:@"SKY_TEXT" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstEntryWithKey:@"PRECIPTATIONS_TEXT" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstEntryWithKey:@"TEMPERATURE_TEXT" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addFirstEntryWithKey:@"TEMPERATURE" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"WIND_SPEED" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"WIND_DIR" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"VISIBILITY" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"COMFORT_LEVEL" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"HUMIDITY" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"DEW_POINT" fromDictsArray:dicts toDictionary:aDictionary];
		[self _addAverageForEntryWithKey:@"BAROMETRIC_PRESSURE" fromDictsArray:dicts toDictionary:aDictionary];
		return;
	}
	[aDictionary addEntriesFromDictionary:[dicts objectAtIndex:0]];
}

- (void)_addAverageForEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary
{
	NSInteger count = [aArray count];
	float sum = 0.0f, n = 0.0f;
	for (NSInteger i = 0; i < count; i++) {
		id value = [[aArray objectAtIndex:i] objectForKey:aKey];
		if (value != nil) {
			sum += [value floatValue];
			n += 1.0f;
		}
	}
	if (n > 0.0f)
		[aDictionary setObject:[NSString stringWithFormat:@"%f", (double)(sum / n)] forKey:aKey];
}

- (void)_addFirstNonZeroEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary
{
	NSInteger count = [aArray count];
	for (NSInteger i = 0; i < count; i++) {
		id value = [[aArray objectAtIndex:i] objectForKey:aKey];
		if ([value intValue] != 0) {
			[aDictionary setObject:value forKey:aKey];
			return;
		}
	}
}

- (void)_addFirstEntryWithKey:(id)aKey fromDictsArray:(id)aArray toDictionary:(id)aDictionary
{
	NSInteger count = [aArray count];
	for (NSInteger i = 0; i < count; i++) {
		id value = [[aArray objectAtIndex:i] objectForKey:aKey];
		if (value != nil) {
			[aDictionary setObject:value forKey:aKey];
			return;
		}
	}
}

- (void)_processWeatherDictionary:(id)aDictionary toDestination:(id)aDestination
{
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"icon" toDictionary:aDestination withKey:@"SUMMARY_CODE"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"wind_speed" toDictionary:aDestination withKey:@"WIND_SPEED"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"wind_dir" toDictionary:aDestination withKey:@"WIND_DIR"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"sky_desc" toDictionary:aDestination withKey:@"SKY_CODE"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"visibility" toDictionary:aDestination withKey:@"VISIBILITY"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"precip_desc" toDictionary:aDestination withKey:@"PRECIPTATIONS_CODE"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"comfort" toDictionary:aDestination withKey:@"COMFORT_LEVEL"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"humidity" toDictionary:aDestination withKey:@"HUMIDITY"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"description" toDictionary:aDestination withKey:@"SUMMARY_TEXT"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"precip" toDictionary:aDestination withKey:@"PRECIPTATIONS_TEXT"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"sky" toDictionary:aDestination withKey:@"SKY_TEXT"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"temp" toDictionary:aDestination withKey:@"TEMPERATURE_TEXT"];
	[self _addStringIfExistsInDictionary:aDictionary forKey:@"dew_point" toDictionary:aDestination withKey:@"DEW_POINT"];
}

- (void)_addStringIfExistsInDictionary:(id)aDictionary forKey:(id)aKey toDictionary:(id)aDictionary2 withKey:(id)aKey2
{
	id value = [aDictionary objectForKey:aKey];
	if ([value length] != 0 && ![value isEqual:@"*"])
		[aDictionary2 setObject:value forKey:aKey2];
}

- (id)_headerForReport:(struct __CFXMLNode *)aReport
{
	NSDictionary *attributes = [self _attributesForNode:aReport];
	return [NSDictionary dictionaryWithObjectsAndKeys:[attributes objectForKey:@"unix_date"], @"UNIX_DATE",
	                                                  [attributes objectForKey:@"state_name"], @"STATE",
	                                                  [attributes objectForKey:@"country_name"], @"COUNTRY", nil];
}

- (struct __CFTree *)_copySubtreeWithDescriptor:(id)aDescriptor fromTree:(struct __CFTree *)aTree
{
	CFIndex count = CFTreeGetChildCount(aTree);
	for (CFIndex i = 0; i < count; i++) {
		CFXMLTreeRef child = CFTreeGetChildAtIndex(aTree, i);
		NSString *name = (NSString *)CFXMLNodeGetString(CFXMLTreeGetNode(child));
		if ([name compare:aDescriptor options:NSCaseInsensitiveSearch] == NSOrderedSame) {
			CFRetain(child);
			return child;
		}
	}
	return NULL;
}

- (id)_allAttributesWithDescriptor:(id)aDescriptor fromTree:(struct __CFTree *)aTree
{
	CFIndex count = CFTreeGetChildCount(aTree);
	NSMutableArray *result = [NSMutableArray array];
	for (CFIndex i = 0; i < count; i++) {
		CFXMLNodeRef node = CFXMLTreeGetNode(CFTreeGetChildAtIndex(aTree, i));
		NSString *name = (NSString *)CFXMLNodeGetString(node);
		if ([name compare:aDescriptor options:NSCaseInsensitiveSearch] == NSOrderedSame)
			[result addObject:[self _attributesForNode:(struct __CFXMLNode *)node]];
	}
	return [result count] != 0 ? result : nil;
}

- (id)_attributesForNode:(struct __CFXMLNode *)aNode
{
	if (CFXMLNodeGetTypeCode(aNode) != kCFXMLNodeTypeElement)
		return nil;
	return (NSDictionary *)((const CFXMLElementInfo *)CFXMLNodeGetInfoPtr(aNode))->attributes;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_skyDescriptions release];
	[_precipDescriptions release];
	[_weatherImages release];
	[_windImages release];
	[super dealloc];
	_sCWManager = nil;
	_sCWManagerWasDeallocated = YES;
}

- (void)_appWillTerminate:(id)aTerminate
{
	[self invalidate];
}

- (void)invalidate
{
	[_cloudsManager invalidate];
	_cloudsManager = nil;
	[_updateTimer invalidate];
	_updateTimer = nil;
	[_fetchingCloudsDates release];
	[self release];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_appWillTerminate:)
		                                             name:NSApplicationWillTerminateNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_internetStateWasChanged:)
		                                             name:kInternetStateWasChanged object:nil];
		_fetchingCloudsDates = [NSMutableSet new];
		_cloudsManager = [CloudsManager new];
		[self _loadCSVs];
		_weatherImages = [[ImagesSequence alloc] initWithFileNamePrefix:@"weather_icons" fileExtension:@"tiff" iconSize:36];
		_windImages = [[ImagesSequence alloc] initWithFileNamePrefix:@"wind_icons" fileExtension:@"tif" iconSize:32];
		[[DownloadManager downloadManager] setTaskQueueSortSelector:@selector(compareWithOtherTaskInfo:)];
	}
	return self;
}

- (void)_loadCSVs
{
	_skyDescriptions = [[self _parseSingleCSV:@"sky_descrs"] retain];
	_precipDescriptions = [[self _parseSingleCSV:@"precip_descrs"] retain];
}

- (id)_parseSingleCSV:(id)aCSV
{
	NSMutableArray *result = [NSMutableArray array];
	NSString *path = [[NSBundle mainBundle] pathForResource:aCSV ofType:@"csv"];
	NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSMacOSRomanStringEncoding error:NULL];
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	NSInteger count = [lines count];
	for (NSInteger i = 0; i < count; i++) {
		NSArray *fields = [[lines objectAtIndex:i] componentsSeparatedByString:@","];
		if ([fields count] > 3)
			[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			    [fields objectAtIndex:1], @"TEXT",
			    [NSNumber numberWithInt:[[fields objectAtIndex:2] intValue]], @"DayIconNumber",
			    [NSNumber numberWithInt:[[fields objectAtIndex:3] intValue]], @"NightIconNumber", nil]];
	}
	return [NSArray arrayWithArray:result];
}

@end

@implementation NSDictionary (CWDownloadTaskComparision)

// cloud maps are downloaded after everything else
- (NSInteger)compareWithOtherTaskInfo:(id)aInfo
{
	BOOL isMap = [[[self objectForKey:kTaskParametersDictionary] objectForKey:@"kRequestKind"] isEqual:@"MAP"];
	BOOL otherIsMap = [[[aInfo objectForKey:kTaskParametersDictionary] objectForKey:@"kRequestKind"] isEqual:@"MAP"];
	if (!isMap)
		return otherIsMap ? NSOrderedAscending : NSOrderedSame;
	return otherIsMap ? NSOrderedSame : NSOrderedDescending;
}

@end
