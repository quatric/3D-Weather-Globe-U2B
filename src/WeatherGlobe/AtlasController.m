#import "AtlasController.h"

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil];
}

static AtlasController *_sGlobalAtlasController = nil;
static BOOL _sGlobalAtlasControllerWasDeallocated = NO;
static BOOL _sAllowMaxQualityConfig = NO;

// the alert with a "don't show again" checkbox the startup checks use
static WBAlert *_runCheckboxAlert(NSString *aTitle, NSString *aBody, NSString *aButton, NSString *aCheckbox)
{
	WBAlert *alert = [[[WBAlert alloc] initWithTitle:aTitle body:aBody rightButt:aButton middleButt:nil leftButt:nil
	                                   checkboxTitle:aCheckbox hasHelpButt:NO defButtIndex:1 cancelButtIndex:2
	                                    hasCustomBgr:NO] autorelease];
	[alert runModal];
	return alert;
}

@implementation AtlasController

+ (id)configDictionary
{
	static NSDictionary *configDictionary = nil;
	if (configDictionary == nil)
		configDictionary = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"config" ofType:@"plist"]];
	return configDictionary;
}

// the shared controller; the first call checks the installation and the
// hardware
+ (id)atlasController
{
	if (_sGlobalAtlasController == nil && !_sGlobalAtlasControllerWasDeallocated) {
		NSFileManager *manager = [NSFileManager defaultManager];
		if (![manager fileExistsAtPath:[manager securityFilePath]]) {
			NSRunAlertPanel(_localized(@"Illegal copy of MacKiev 3D Atlas"), @"%@", _localized(@"QuitButt"), nil, nil,
			                _localized(@"IllegalCopyBody"));
			[NSApp terminate:self];
			return nil;
		}
		[self _assertUnsupportedOS];
		[self _assertUnsupportedResolution];
		[self _assertUnsupportedColors];
		unsigned int texturesMemory = (unsigned int)texturesMemoryForScreen([NSScreen mainScreen]) >> 10;
		if (texturesMemory != 0) {
			NSDictionary *config = [self configDictionary];
			unsigned int minTexturesMemory = (unsigned int)[[config objectForKey:@"MinTexturesMemory"] intValue];
			unsigned int recTexturesMemory = (unsigned int)[[config objectForKey:@"RecTexturesMemory"] intValue];
			unsigned int recSystemMemory = (unsigned int)[[config objectForKey:@"RecSystemMemory"] intValue];
			unsigned long long systemMemory = [[NSProcessInfo processInfo] physicalMemory] >> 20;
			_sAllowMaxQualityConfig = recTexturesMemory < texturesMemory && recSystemMemory <= systemMemory;
			if (texturesMemory < minTexturesMemory && [Preferences doShowBadVideoAlert]) {
				WBAlert *alert = _runCheckboxAlert(_localized(@"Too old video hardware"), _localized(@"Will run with limitations"),
				                                   _localized(@"Ok"), _localized(@"DontShowAlertAgain"));
				[Preferences setShowBadVideoAlert:![alert dontShowAgain]];
			}
		}
		_sGlobalAtlasController = [AtlasController new];
		[NSApp setServicesProvider:_sGlobalAtlasController];
		[_sGlobalAtlasController _createRouteSamplesMenu];
	}
	return _sGlobalAtlasController;
}

// fewer than 12 bits per pixel can't run; fewer than 24 run poorly
+ (void)_assertUnsupportedColors
{
	NSScreen *screen = [self _generalScreen];
	NSInteger bitsPerPixel = screen != nil ? NSBitsPerPixelFromDepth([screen depth]) : 0;
	BOOL supported = bitsPerPixel > 11;
	if (supported && (![Preferences doShowUnsupportedColorAlert] || bitsPerPixel > 23))
		return;
	NSString *button = _localized(@"Ok");
	NSString *checkbox = _localized(@"DontShowAlertAgain");
	NSString *title = _localized(@"UnsupportedColorsTitle");
	NSString *message = _localized(@"LowColorsMessage");
	if (!supported) {
		button = _localized(@"QuitButt");
		message = _localized(@"UnsupportedColorsMessage");
		checkbox = nil;
	}
	WBAlert *alert = _runCheckboxAlert(title, message, button, checkbox);
	if (!supported)
		[NSApp terminate:self];
	[Preferences setShowUnsupportedColorAlert:![alert dontShowAgain]];
}

+ (void)_assertUnsupportedResolution
{
	NSScreen *screen = [self _generalScreen];
	if (screen != nil) {
		NSRect frame = [screen frame];
		if ((float)frame.size.width >= 1024.0f && !((float)frame.size.height < 600.0f))
			return;
	}
	NSRunAlertPanel(_localized(@"UnsupportedResolutionTitle"), @"%@", _localized(@"QuitButt"), nil, nil,
	                _localized(@"UnsupportedResolutionMessage"));
	[NSApp terminate:self];
}

+ (id)_generalScreen
{
	NSArray *screens = [NSScreen screens];
	if (screens != nil && [screens count] != 0)
		return [screens objectAtIndex:0];
	return [NSScreen mainScreen];
}

+ (void)_assertUnsupportedOS
{
	if ([PantherSpecificClass currentOSVersion] >= kPantherVersion || ![Preferences doShowUnsupportedOSAlert])
		return;
	NSString *title = [NSString stringWithFormat:_localized(@"MacOSXVersionRequiresTitle"), @"10.3"];
	WBAlert *alert = _runCheckboxAlert(title, _localized(@"MacOSXVersionRequiresMessage"), _localized(@"Ok"),
	                                   _localized(@"DontShowAlertAgain"));
	[Preferences setShowUnsupportedOSAlert:![alert dontShowAgain]];
}

+ (void)_appWillTerminate:(id)aTerminate
{
	if (_sGlobalAtlasController == nil)
		return;
	[NSApp setServicesProvider:nil];
	[_sGlobalAtlasController->_timeController invalidateTimer];
	[_sGlobalAtlasController release];
	_sGlobalAtlasController = nil;
	_sGlobalAtlasControllerWasDeallocated = YES;
}

+ (void)_appDidFinishLaunching:(id)aLaunching
{
	[NSBundle loadNibNamed:@"CoreInterface" owner:[AtlasController atlasController]];
	[NSApp setDelegate:(id)_sGlobalAtlasController];
	// the help book (MacKiev3DAtlas.help) is found through the bundle
	AHRegisterHelpBookWithURL((CFURLRef)[[NSBundle mainBundle] bundleURL]);
}

- (void)downloadWindowAction:(id)aAction
{
	if (_updIsInProgress) {
		NSInteger answer = NSRunAlertPanel(_localized(@"Updating will be stopped."), @"%@", _localized(@"ContinueButt"),
		                                   _localized(@"StopButt"), nil,
		                                   _localized(@"Are you sure you want to stop database updating process?"));
		if (answer == NSAlertDefaultReturn)
			return;
		[[DownloadManager downloadManager] terminateUpdating];
	}
	[_downloadWnd orderOut:aAction];
}

// returns whether to retry
- (NSInteger)errorWithCodeCatched:(NSInteger)aCatched data:(id)aData
{
	NSInteger answer = NSRunAlertPanel(_localized(@"Download error"), @"%@", _localized(@"RetryButt"), _localized(@"Cancel"),
	                                   nil, _localized(@"Download error body"));
	if (answer != NSAlertDefaultReturn) {
		[_downloadProgr stopAnimation:nil];
		[_downloadWnd orderOut:nil];
	}
	return answer == NSAlertDefaultReturn;
}

// 1: retry, 0: stop, 2: go on
- (NSInteger)fileWasDownloadedWithName:(id)aName error:(NSInteger)aError
{
	if (aError == -20) {
		NSInteger answer = NSRunAlertPanel(_localized(@"CannotStoreUpdatesTitle"), @"%@", _localized(@"RetryButt"),
		                                   _localized(@"Cancel"), nil, _localized(@"CannotStoreUpdatesMessage"));
		if (answer == NSAlertDefaultReturn)
			return 1;
		[_downloadProgr stopAnimation:nil];
		[_downloadWnd orderOut:nil];
		return 0;
	}
	_numDownloadFiles++;
	[_downloadProgr setDoubleValue:(double)_numDownloadFiles];
	return 2;
}

- (void)fileWillBeDownloadedWithName:(id)aName
{
	[_downloadStatus setStringValue:[NSString stringWithFormat:_localized(@"UpdDownloadStat"), _numDownloadFiles + 1, _numFilesToDownload]];
}

- (void)updateWasFinished
{
	if ([NSApp modalWindow] != nil) {
		[self performSelector:@selector(updateWasFinished) withObject:nil afterDelay:1.0];
		return;
	}
	[[DownloadManager downloadManager] pauseAuthorization];
	[_downloadProgr setIndeterminate:YES];
	[_downloadProgr display];
	[_downloadProgr startAnimation:nil];
	[_downloadStatus setStringValue:_localized(@"ApplyUpdates")];
	[_downloadStatus display];
	[_downloadButt setEnabled:NO];
	[[AtlasDatabase database] rescanForUpdatesWithModalWindow:_downloadWnd];
	[_downloadProgr setDoubleValue:1.0];
	[_downloadProgr setMaxValue:1.0];
	[_downloadProgr setIndeterminate:NO];
	[_downloadProgr stopAnimation:nil];
	[_downloadStatus setStringValue:_localized(@"UpdDownloadFinished")];
	[_downloadButt setEnabled:YES];
	[_downloadButt setTitle:_localized(@"Ok")];
	[_downloadButt setKeyEquivalent:@"\r"];
	_updIsInProgress = NO;
	[_downloadWnd displayIfNeeded];
	[[DownloadManager downloadManager] resumeAuthorization];
}

- (void)updateWillStartWithFilesCount:(NSInteger)aCount
{
	_numDownloadFiles = 0;
	_numFilesToDownload = (int)aCount;
	[_downloadProgr startAnimation:nil];
	[_downloadProgr setIndeterminate:NO];
	[_downloadProgr setDoubleValue:0.0];
	[_downloadProgr setMaxValue:(double)aCount];
	[_downloadStatus setStringValue:@""];
	[_downloadButt setTitle:_localized(@"StopButt")];
	[_downloadButt setKeyEquivalent:@""];
	[_downloadWnd center];
	[_downloadWnd makeKeyAndOrderFront:nil];
	_updIsInProgress = YES;
}

- (BOOL)application:(id)aApplication printFile:(id)aFile
{
	if (![self application:aApplication openFile:aFile])
		return NO;
	[[self mainWindowController] doPrint:nil];
	return YES;
}

// opens route sets and Apple Store sets
- (BOOL)application:(id)aApplication openFile:(id)aFile
{
	if ([NSApp modalWindow] != nil)
		return NO;
	NSString *extension = [aFile pathExtension];
	if (![extension isEqual:kRouteSetFileExt] && ![[aFile pathExtension] isEqual:kAppleStoresSetFileExt])
		return NO;
	[self showMainWindow];
	[[self mainWindowController] openRouteDocumentAtPath:aFile reverting:NO];
	return YES;
}

- (struct WeatherGlobe_anon2)moonDirection
{
	if (!_moonDirIsValid)
		[self _calculateMoonDirection];
	struct WeatherGlobe_anon2 result = { _moonDirection.x, _moonDirection.y, _moonDirection.z };
	return result;
}

- (struct WeatherGlobe_anon2)lightDirection
{
	if (!_lightDirIsValid)
		[self _calculateLightDirection];
	struct WeatherGlobe_anon2 result = { _lightDirection.x, _lightDirection.y, _lightDirection.z };
	return result;
}

// the fraction of the synodic month since a new moon
- (CGFloat)moonPhase
{
	double phase = [[_timeController currentDate] timeIntervalSince1970] / 2360591.4996 + 0.36000001430511475;
	return (float)(phase - floor(phase));
}

// the fraction of the tropical year since the winter solstice
- (CGFloat)normalizedYearPhase
{
	double phase = [[_timeController currentDate] timeIntervalSince1970] / 31556927.8 - 0.211;
	return (float)(phase - floor(phase));
}

- (CGFloat)yearPhase
{
	NSCalendarDate *date = [_timeController currentDate];
	NSInteger day = [date dayOfYear];
	NSInteger year = [date yearOfCommonEra];
	float dayPhase = (float)[self GMTDayPhase];
	float days = (year & 3) == 0 ? 366.0f : 365.0f;
	return ((float)(int)day + dayPhase) / days;
}

- (CGFloat)GMTDayPhase
{
	NSCalendarDate *date = [_timeController currentDate];
	float local = (float)[self localDayPhase];
	float phase = (float)(int)[[date timeZone] secondsFromGMTForDate:date] / -86400.0f + local;
	return phase - floorf(phase);
}

- (CGFloat)localDayPhase
{
	NSCalendarDate *date = [_timeController currentDate];
	NSInteger hour = [date hourOfDay];
	NSInteger minute = [date minuteOfHour];
	NSInteger second = [date secondOfMinute];
	return (float)(int)hour / 24.0f + (float)(int)minute / 1440.0f + (float)(int)second / 86400.0f;
}

- (void)_calculateMoonDirection
{
	_moonDirIsValid = YES;
	float moonPhase = (float)[self moonPhase];
	float dayPhase = (float)[self GMTDayPhase];
	float yearPhase = (float)[self normalizedYearPhase];
	SMK_GL_Vec3 direction = _moonDirection_EarthSystem(yearPhase, dayPhase, moonPhase);
	_moonDirection.x = direction.x;
	_moonDirection.y = direction.y;
	_moonDirection.z = direction.z;
}

- (void)_calculateLightDirection
{
	_lightDirIsValid = YES;
	float dayPhase = (float)[self GMTDayPhase];
	float yearPhase = (float)[self normalizedYearPhase];
	SMK_GL_Vec3 direction = _lightDirection_EarthSystem(yearPhase, dayPhase);
	_lightDirection.x = direction.x;
	_lightDirection.y = direction.y;
	_lightDirection.z = direction.z;
}

- (void)_worldTimeWasChanged:(id)aChanged
{
	_lightDirIsValid = NO;
	_moonDirIsValid = NO;
	if ([[_mainWindowController mainWindow] isVisible])
		[[_mainWindowController glView] setNeedsDisplay:YES];
}

- (void)_dbWasChanged:(id)aChanged
{
	[self _createRouteSamplesMenu];
	[_mainWindowController reloadRouteButtonMenu];
}

- (void)_dbUpdatesAreAvailable:(id)aAvailable
{
	if (![Preferences usesSoftwareUpdating])
		return;
	NSInteger answer = NSRunAlertPanel(_localized(@"New Database Updates"), @"%@", _localized(@"DownloadNow"),
	                                   _localized(@"DownloadLater"), nil, _localized(@"New database updates are available"));
	if (answer == NSAlertDefaultReturn)
		[[DownloadManager downloadManager] updateWithDelegate:self];
}

- (void)_inetBecomeAvailable:(id)aAvailable
{
	[_alertTimer invalidate];
	_alertTimer = nil;
	[_badInternetAlert orderOut:aAvailable];
}

- (void)_inetBecomeUnavailable:(id)aUnavailable
{
	if (_alertTimer == nil && ![_badInternetAlert isVisible])
		_alertTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(_showBadInternetAlert:)
		                                             userInfo:nil repeats:NO];
}

- (void)_showBadInternetAlert:(id)aAlert
{
	_alertTimer = nil;
}

- (id)timeController
{
	return _timeController;
}

- (id)database
{
	if (_database == nil && !_databaseIsCreating) {
		_databaseIsCreating = YES;
		_database = [AtlasDatabase new];
		[_database rescanForUpdates];
		[[DownloadManager downloadManager] refreshDatabase];
		_databaseIsCreating = NO;
	}
	return _database;
}

- (void)hideMainWindow
{
	if (!_windowIsShown)
		return;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[_mainWindowController mainWindow]];
	[_mainWindowController hideWindow];
	_windowIsShown = NO;
}

- (void)showMainWindow
{
	if (_windowIsShown)
		return;
	[_mainWindowController showWindow];
	_windowIsShown = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_mainWindowWillBeClosed:)
	                                             name:NSWindowWillCloseNotification object:[_mainWindowController mainWindow]];
}

- (void)_mainWindowWillBeClosed:(id)aClosed
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[_mainWindowController mainWindow]];
	[_mainWindowController hideWindow];
	_windowIsShown = NO;
}

- (void)gotoGetMoreRoutes:(id)aRoutes
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_localized(@"Get More Routes Page")]];
}

// opens a page of the web site with the application version in its URL
static void _openVersionedPage(NSString *aKey)
{
	id version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:_localized(aKey), version]]];
}

- (void)gotoTechSupport:(id)aSupport
{
	_openVersionedPage(@"Tech Support Page");
}

- (void)openUserGuide:(id)aGuide
{
	NSString *name = _localized(@"UserGuideFileName");
	NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@""];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[[NSWorkspace sharedWorkspace] openFile:path];
		return;
	}
	NSString *message = [NSString stringWithFormat:_localized(@"UserGuideNotFoundMessage"), name];
	NSRunAlertPanel(_localized(@"UserGuideNotFoundTitle"), @"%@", _localized(@"OK"), nil, nil, message);
}

- (void)showSettingsHelp:(id)aHelp
{
	AHGotoPage(CFSTR("3D Weather Globe Help"), CFSTR("topics/settings.html"), NULL);
}

- (void)registerAtlas:(id)aAtlas
{
	if ([self isBoxVersion])
		_openVersionedPage(@"Registration Page");
}

- (void)provideFeedback:(id)aFeedback
{
	_openVersionedPage(@"Feedback Page");
}

- (void)timeInfoPalette:(id)aPalette
{
	[_timeController showPalette];
}

- (void)showAboutPanel:(id)aPanel
{
	[_aboutController showPanel];
}

- (void)showPreferences:(id)aPreferences
{
	[_preferencesController showPreferences];
}

- (void)toggleCitiesInfoPalette:(id)aPalette
{
	[_citiesPaletteController togglePalette];
}

- (void)hideCitiesInfoPalette:(id)aPalette
{
	[_citiesPaletteController hidePalette];
}

- (void)showCitiesInfoPalette:(id)aPalette
{
	[_citiesPaletteController showPalette];
}

- (void)hideStatusMenu:(id)aMenu
{
	[self hideStatusBarItems];
}

- (void)changeOnlineStatus:(id)aStatus
{
}

- (void)browseTheEarth:(id)aEarth
{
	[NSApp activateIgnoringOtherApps:NO];
	[self showMainWindow];
}

- (void)activateAtlas:(id)aAtlas
{
	[NSApp activateIgnoringOtherApps:NO];
}

// fills the item's submenu with the sample routes of the database
- (NSInteger)_updateRouteSamplesMenuForItem:(id)aItem
{
	NSArray *routes = [[AtlasDatabase database] allSampleRoutes];
	NSInteger count = [routes count];
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Samples"];
	[aItem setSubmenu:menu];
	[menu release];
	for (NSInteger i = 0; i < count; i++) {
		NSDictionary *route = [routes objectAtIndex:i];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[route objectForKey:kColumnNameName] action:NULL keyEquivalent:@""];
		[item setTarget:nil];
		[item setAction:@selector(routeSampleMenu:)];
		[item setRepresentedObject:[[routes objectAtIndex:i] objectForKey:kColumnNameBLOBUid]];
		[menu addItem:item];
		[item release];
	}
	return count;
}

- (void)_createRouteSamplesMenu
{
	[self _updateRouteSamplesMenuForItem:[[[[NSApp mainMenu] itemWithTitle:@"Route"] submenu] itemWithTitle:@"Samples"]];
}

// the dock menu: the home city's weather, then updating and choosing it
- (void)_recreateDockMenu
{
	[_dockMenu release];
	_dockMenu = nil;
	if (_dockEntry == nil)
		return;
	_dockMenu = [[NSMenu alloc] initWithTitle:@""];
	NSDictionary *report = [_dockEntry dictionaryForReport:0];
	if (report != nil && [[report objectForKey:@"DATA_EXPIRED"] intValue] == 0) {
		NSString *title = [NSString stringWithFormat:_localized(@"DockMenuWeatherText"), [_dockEntry shortCaption],
		                                             [report temperatureForKey:@"TEMPERATURE"], [report weatherDescription]];
		[_dockMenu addItem:[[[NSMenuItem alloc] initWithTitle:title action:@selector(_dockEntryWasSelected:) keyEquivalent:@""] autorelease]];
	}
	[_dockMenu addItem:[[[NSMenuItem alloc] initWithTitle:_localized(@"UpdateCurrentTemperature")
	                                              action:@selector(_updateDockWeather:) keyEquivalent:@""] autorelease]];
	[_dockMenu addItem:[[[NSMenuItem alloc] initWithTitle:_localized(@"DockMenuSelectCity")
	                                              action:@selector(_selectHomeCityFromDock:) keyEquivalent:@""] autorelease]];
}

- (id)applicationDockMenu:(id)aMenu
{
	return _dockMenu;
}

// draws the text in a rounded box over the top of the dock icon; an empty
// text restores the plain icon
- (void)setDockIconOverlayText:(id)aText
{
	[NSApp setApplicationIconImage:nil];
	if ([aText length] == 0)
		return;
	NSSize size = [(NSAttributedString *)aText size];
	float radius = (float)size.height * 0.5f;
	float width = (float)size.width + radius * 1.5f;
	float bottom = 124.0f - (float)size.height;
	float left = radius + 0.0f;
	float right = width + 0.0f;
	float top = radius + radius + bottom;
	float upper = top + radius * -0.2f;
	float lower = bottom + radius * 0.2f;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(left, bottom)];
	[path lineToPoint:NSMakePoint(right - radius, bottom)];
	[path curveToPoint:NSMakePoint(right - radius, top) controlPoint1:NSMakePoint(right, lower) controlPoint2:NSMakePoint(right, upper)];
	[path lineToPoint:NSMakePoint(left, top)];
	[path curveToPoint:NSMakePoint(left, bottom) controlPoint1:NSMakePoint(0.0, upper) controlPoint2:NSMakePoint(0.0, lower)];
	[path closePath];
	NSImage *icon = [[[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)] autorelease];
	[icon lockFocus];
	[[NSImage imageNamed:NSImageNameApplicationIcon] drawInRect:NSMakeRect(0.0, 0.0, 128.0, 128.0) fromRect:NSZeroRect
	                                                   operation:NSCompositingOperationSourceOver fraction:1.0];
	[[NSColor colorWithDeviceRed:0.0 green:0.1 blue:0.2 alpha:0.85] set];
	[path fill];
	[path setLineWidth:1.5];
	[[NSColor whiteColor] set];
	[path stroke];
	[(NSAttributedString *)aText drawInRect:NSMakeRect(0.0, bottom, width, radius + radius)];
	[icon unlockFocus];
	[NSApp setApplicationIconImage:icon];
}

- (BOOL)statusBarItemsWereInstalled
{
	return _barItems != nil;
}

- (void)hideStatusBarItems
{
	if (_barItems == nil)
		return;
	[[NSStatusBar systemStatusBar] removeStatusItem:_barItems];
	[_barItems autorelease];
	_barItems = nil;
}

- (void)installStatusBarItems
{
}

- (id)_menuForStatusBar
{
	return _defaultStatusMenu;
}

- (BOOL)validateMenuItem:(id)aItem
{
	SEL action = [aItem action];
	if (action == @selector(browseTheEarth:) && _windowIsShown)
		return NO;
	if (action == @selector(toggleCitiesInfoPalette:)) {
		[aItem setTitle:_localized([_citiesPaletteController paletteIsVisible] ? @"Hide Cities Info Palette" : @"Show Cities Info Palette")];
		return YES;
	}
	if (action == @selector(showPreferences:) || action == @selector(showAboutPanel:))
		return [NSApp modalWindow] == nil;
	if (action == @selector(gotoGetMoreRoutes:))
		[aItem setState:NSControlStateValueOff];
	return YES;
}

// the Services menu: look a place up on the map
- (void)servicesLookup:(id)aLookup userData:(id)aData error:(id *)aError
{
	NSString *term = [aLookup stringForType:NSPasteboardTypeString];
	[self showMainWindow];
	[_mainWindowController openSearchForTerm:term];
	[NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)enableMaxQuality
{
	return _sAllowMaxQualityConfig;
}

- (BOOL)isBoxVersion
{
	if (!_boxVersionIsValid) {
		_boxVersionIsValid = YES;
		_boxVersion = YES;
	}
	return _boxVersion;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_citiesPaletteController release];
	[_preferencesController release];
	[_aboutController release];
	[self hideStatusBarItems];
	[_timeController release];
	[_mainWindowController release];
	[_defaultStatusMenu release];
	[_database release];
	_database = nil;
	[self _finilizeDockWeather];
	[_dockMenu release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self _initDockWeather];
	[_defaultStatusMenu setAutoenablesItems:NO];
	[self installStatusBarItems];
	[Preferences setupBeforeMainWindowLoad];
	if ([Preferences doShowMainWindowOnStartup])
		[self showMainWindow];
	if ([Preferences doShowWeatherOnStartup])
		[_citiesPaletteController showPalette];
	[_badInternetAlert center];
	[_downloadProgr setUsesThreadedAnimation:YES];
}

- (id)init
{
	self = [super init];
	if (self == nil)
		return nil;
	_mainWindowController = [[MainWindowController alloc] initWithAtlasController:self];
	_timeController = [[TimeController alloc] initWithAtlasController:self];
	@try {
		_citiesPaletteController = [CIPaletteController new];
		_preferencesController = [PreferencesController new];
		_aboutController = [AboutController new];
	} @catch (NSException *exception) {
	}
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_worldTimeWasChanged:) name:kWorldTimeWasChanged object:nil];
	[center addObserver:self selector:@selector(_inetBecomeUnavailable:) name:kINetBecomeUnavailableNotification object:nil];
	[center addObserver:self selector:@selector(_inetBecomeAvailable:) name:kINetBecomeAvailableNotification object:nil];
	[center addObserver:self selector:@selector(_dbUpdatesAreAvailable:) name:kNewUpdatesAreAvailableNotification object:nil];
	[center addObserver:self selector:@selector(_dbWasChanged:) name:kMainDatabaseChangedNotification object:nil];
	return self;
}

- (id)preferencesController
{
	return [[_preferencesController retain] autorelease];
}

- (id)mainWindowController
{
	return [[_mainWindowController retain] autorelease];
}

@end

@implementation AtlasController (AtlasControllerDockWeather)

- (void)_updateDockWeather:(id)aWeather
{
	[CWManager resetWeatherInternetState];
	[_dockEntry manualUpdateOfScheduledReports];
}

- (void)_selectHomeCityFromDock:(id)aDock
{
	[_preferencesController showSelectCityDialog];
}

- (void)_dockEntryWasSelected:(id)aSelected
{
	[FullCityInfoController showWithCityEntry:_dockEntry];
}

- (void)_homeCityWasChanged:(id)aChanged
{
	YACityEntry *home = [Preferences homeCity];
	if (home == _dockEntry)
		return;
	[self _unscheduleDockEntry];
	[_dockEntry release];
	_dockEntry = [home retain];
	[self _scheduleDockEntry];
	[self _refreshDockWeather];
}

- (void)_dockReportsWereChanged:(id)aChanged
{
	if ([[[aChanged userInfo] objectForKey:kReportIDKey] unsignedIntValue] == 0)
		[self _refreshDockWeather];
}

- (void)_unitsOfMeasureWereChanged:(id)aChanged
{
	[self _refreshDockWeather];
}

- (void)_showWeatherInDockStateWasChanged:(id)aChanged
{
	if ([Preferences doShowWeatherInDock] && [Preferences usesInternet])
		[self _showDockWeather];
	else
		[self _hideDockWeather];
}

- (void)_finilizeDockWeather
{
	if (!_dockWeatherWasInitialize)
		return;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:kShowWeatherInDockStateWasChanged object:nil];
	[center removeObserver:self name:kInternetStateWasChanged object:nil];
	[self _hideDockWeather];
	_dockWeatherWasInitialize = NO;
}

- (void)_initDockWeather
{
	if (_dockWeatherWasInitialize)
		return;
	if ([Preferences doShowWeatherInDock] && [Preferences usesInternet])
		[self _showDockWeather];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_showWeatherInDockStateWasChanged:) name:kShowWeatherInDockStateWasChanged object:nil];
	[center addObserver:self selector:@selector(_showWeatherInDockStateWasChanged:) name:kInternetStateWasChanged object:nil];
	_dockWeatherWasInitialize = YES;
}

- (void)_hideDockWeather
{
	if (_dockEntry == nil)
		return;
	[self _unscheduleDockEntry];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:kUnitsOfMeasureWereChanged object:nil];
	[center removeObserver:self name:kHomeCityWasChanged object:nil];
	[_dockEntry release];
	_dockEntry = nil;
	[self _refreshDockWeather];
}

- (void)_showDockWeather
{
	if (_dockEntry != nil)
		return;
	_dockEntry = [[Preferences homeCity] retain];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];
	[center addObserver:self selector:@selector(_homeCityWasChanged:) name:kHomeCityWasChanged object:nil];
	[self _scheduleDockEntry];
	[self _refreshDockWeather];
}

- (void)_unscheduleDockEntry
{
	if (!_dockScheduled)
		return;
	[_dockEntry unscheduleReports:1];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:kCityEntryWasUpdatedViaOnlineNotification object:_dockEntry];
	[center removeObserver:self name:kCityEntryWasExpiredViaOnlineNotification object:_dockEntry];
	_dockScheduled = NO;
}

- (void)_scheduleDockEntry
{
	if (_dockScheduled || ![Preferences usesInternet])
		return;
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_dockReportsWereChanged:) name:kCityEntryWasUpdatedViaOnlineNotification object:_dockEntry];
	[center addObserver:self selector:@selector(_dockReportsWereChanged:) name:kCityEntryWasExpiredViaOnlineNotification object:_dockEntry];
	[_dockEntry scheduleReports:1];
	_dockScheduled = YES;
}

// the current temperature on the dock icon
- (void)_refreshDockWeather
{
	NSDictionary *report = [_dockEntry dictionaryForReport:0];
	int expired = [[report objectForKey:@"DATA_EXPIRED"] intValue];
	id temperature = [report objectForKey:@"TEMPERATURE"];
	NSAttributedString *text = nil;
	if (temperature != nil && (char)expired == 0) {
		BOOL metric = [Preferences usesMetricSystem];
		float value = metric ? [temperature floatValue] : _fahrenheitFromCelsius([temperature floatValue]);
		text = [NSAttributedString stringForTemperature:value inCelsius:metric];
	}
	[self setDockIconOverlayText:text];
	[self _recreateDockMenu];
}

@end

@implementation NSAttributedString (NSAttributedStringDockIconText)

// the sign, the rounded degrees and the unit, white and centred
+ (id)stringForTemperature:(CGFloat)aTemperature inCelsius:(BOOL)aCelsius
{
	float temperature = (float)aTemperature;
	BOOL negative = temperature < 0.0f;
	if (negative)
		temperature = -temperature;
	NSMutableParagraphStyle *paragraph = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[paragraph setAlignment:NSTextAlignmentCenter];
	NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Arial" traits:NSBoldFontMask weight:9 size:36.0];
	NSColor *white = [NSColor whiteColor];
	if (font == nil)
		font = [NSFont boldSystemFontOfSize:30.0];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, white,
	                                         NSForegroundColorAttributeName, paragraph, NSParagraphStyleAttributeName, nil];
	NSMutableAttributedString *string = [[NSMutableAttributedString new] autorelease];
	NSImage *sign = [NSImage imageNamed:negative ? @"sign_minus.tiff" : @"sign_plus.tiff"];
	if (sign != nil) {
		NSFileWrapper *wrapper = [[NSFileWrapper new] autorelease];
		[wrapper setIcon:sign];
		NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
		[string appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
	}
	NSString *degrees = [NSString stringWithFormat:@"%d", (int)(temperature + 0.5f)];
	[string appendAttributedString:[[[NSMutableAttributedString alloc] initWithString:degrees attributes:nil] autorelease]];
	NSImage *unit = [NSImage imageNamed:aCelsius ? @"temper_C.tiff" : @"temper_F.tiff"];
	if (unit != nil) {
		NSFileWrapper *wrapper = [[NSFileWrapper new] autorelease];
		[wrapper setIcon:unit];
		NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
		[string appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
	}
	[string addAttributes:attributes range:NSMakeRange(0, [string length])];
	return string;
}

@end
