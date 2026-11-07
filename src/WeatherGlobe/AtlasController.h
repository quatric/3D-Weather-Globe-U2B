#import "WeatherGlobePrefix.h"


@interface AtlasController : NSObject <DatabaseUpdateDelegate>
{
    AtlasDatabase *_database;
    BOOL _databaseIsCreating;
    BOOL _refreshWasRequested;
    BOOL _windowIsShown;
    MainWindowController *_mainWindowController;
    NSStatusItem *_barItems;
    NSMenu *_defaultStatusMenu;
    NSMenuItem *_onlineStatusMenuItem;
    struct WeatherGlobe_anon1 _lightDirection;
    struct WeatherGlobe_anon1 _moonDirection;
    BOOL _lightDirIsValid;
    BOOL _moonDirIsValid;
    CIPaletteController *_citiesPaletteController;
    PreferencesController *_preferencesController;
    AboutController *_aboutController;
    TimeController *_timeController;
    NSWindow *_badInternetAlert;
    NSTimer *_alertTimer;
    BOOL _boxVersion;
    BOOL _boxVersionIsValid;
    NSWindow *_downloadWnd;
    NSTextField *_downloadStatus;
    NSProgressIndicator *_downloadProgr;
    NSProgressIndicator *_downloadSpin;
    NSButton *_downloadButt;
    int _numDownloadFiles;
    int _numFilesToDownload;
    BOOL _updIsInProgress;
    NSMenu *_dockMenu;
    YACityEntry *_dockEntry;
    BOOL _dockScheduled;
    BOOL _dockWeatherWasInitialize;
}
+ (id)configDictionary;
+ (id)atlasController;
+ (void)_assertUnsupportedColors;
+ (void)_assertUnsupportedResolution;
+ (id)_generalScreen;
+ (void)_assertUnsupportedOS;
+ (void)_appWillTerminate:(id)aTerminate;
+ (void)_appDidFinishLaunching:(id)aLaunching;
- (void)downloadWindowAction:(id)aAction;
- (NSInteger)errorWithCodeCatched:(NSInteger)aCatched data:(id)aData;
- (NSInteger)fileWasDownloadedWithName:(id)aName error:(NSInteger)aError;
- (void)fileWillBeDownloadedWithName:(id)aName;
- (void)updateWasFinished;
- (void)updateWillStartWithFilesCount:(NSInteger)aCount;
- (BOOL)application:(id)aApplication printFile:(id)aFile;
- (BOOL)application:(id)aApplication openFile:(id)aFile;
- (struct WeatherGlobe_anon2)moonDirection;
- (struct WeatherGlobe_anon2)lightDirection;
- (CGFloat)moonPhase;
- (CGFloat)normalizedYearPhase;
- (CGFloat)yearPhase;
- (CGFloat)GMTDayPhase;
- (CGFloat)localDayPhase;
- (void)_calculateMoonDirection;
- (void)_calculateLightDirection;
- (void)_worldTimeWasChanged:(id)aChanged;
- (void)_dbWasChanged:(id)aChanged;
- (void)_dbUpdatesAreAvailable:(id)aAvailable;
- (void)_inetBecomeAvailable:(id)aAvailable;
- (void)_inetBecomeUnavailable:(id)aUnavailable;
- (void)_showBadInternetAlert:(id)aAlert;
- (id)timeController;
- (id)database;
- (void)hideMainWindow;
- (void)showMainWindow;
- (void)_mainWindowWillBeClosed:(id)aClosed;
- (void)gotoGetMoreRoutes:(id)aRoutes;
- (void)gotoTechSupport:(id)aSupport;
- (void)openUserGuide:(id)aGuide;
- (void)showSettingsHelp:(id)aHelp;
- (void)registerAtlas:(id)aAtlas;
- (void)provideFeedback:(id)aFeedback;
- (void)timeInfoPalette:(id)aPalette;
- (void)showAboutPanel:(id)aPanel;
- (void)showPreferences:(id)aPreferences;
- (void)toggleCitiesInfoPalette:(id)aPalette;
- (void)hideCitiesInfoPalette:(id)aPalette;
- (void)showCitiesInfoPalette:(id)aPalette;
- (void)hideStatusMenu:(id)aMenu;
- (void)changeOnlineStatus:(id)aStatus;
- (void)browseTheEarth:(id)aEarth;
- (void)activateAtlas:(id)aAtlas;
- (NSInteger)_updateRouteSamplesMenuForItem:(id)aItem;
- (void)_createRouteSamplesMenu;
- (void)_recreateDockMenu;
- (id)applicationDockMenu:(id)aMenu;
- (void)setDockIconOverlayText:(id)aText;
- (BOOL)statusBarItemsWereInstalled;
- (void)hideStatusBarItems;
- (void)installStatusBarItems;
- (id)_menuForStatusBar;
- (BOOL)validateMenuItem:(id)aItem;
- (void)servicesLookup:(id)aLookup userData:(id)aData error:(id *)aError;
- (BOOL)enableMaxQuality;
- (BOOL)isBoxVersion;
- (void)dealloc;
- (void)awakeFromNib;
- (id)init;
- (id)preferencesController;
- (id)mainWindowController;
@end

@interface AtlasController (AtlasControllerDockWeather)
- (void)_updateDockWeather:(id)aWeather;
- (void)_selectHomeCityFromDock:(id)aDock;
- (void)_dockEntryWasSelected:(id)aSelected;
- (void)_homeCityWasChanged:(id)aChanged;
- (void)_dockReportsWereChanged:(id)aChanged;
- (void)_unitsOfMeasureWereChanged:(id)aChanged;
- (void)_showWeatherInDockStateWasChanged:(id)aChanged;
- (void)_finilizeDockWeather;
- (void)_initDockWeather;
- (void)_hideDockWeather;
- (void)_showDockWeather;
- (void)_unscheduleDockEntry;
- (void)_scheduleDockEntry;
- (void)_refreshDockWeather;
@end

@interface NSAttributedString (NSAttributedStringDockIconText)
+ (id)stringForTemperature:(CGFloat)aTemperature inCelsius:(BOOL)aCelsius;
@end

