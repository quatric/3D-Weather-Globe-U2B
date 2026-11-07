// Shared declarations for the WeatherGlobe sources.
#import "WGSystem.h"
#import "SMKGLUmbrella.h"
#import "SMKControlsUmbrella.h"

@protocol CitiesDraggingHelperProtocol <NSObject>
@end
@protocol DatabaseUpdateDelegate <NSObject>
@end
@protocol SMK_GL_StaticTextLayouter <NSObject>
@end

@class AboutController;
@class AppNameTextField;
@class AppleStoreEditController;
@class AppleStoreEntry;
@class AppleStoreInfoPalette;
@class AppleStoreInfoPaletteController;
@class AtlasApplication;
@class AtlasController;
@class AtlasDatabase;
@class AtlasGLView;
@class AtlasPanelController;
@class BLOBWrapper;
@class BackgroundImageView;
@class BaseAtlasScene;
@class BaseDrawView;
@class BitmapDrawable;
@class BoundariesContainer;
@class CIBackgroundImageView;
@class CICitiesListController;
@class CIPaletteController;
@class CIPaletteTitleView;
@class CIPaletteView;
@class CIPaletteWindow;
@class CPAstronomyForecastView;
@class CPCurrentConditionsView;
@class CPExpandedForecastView;
@class CPMainPropertyView;
@class CPStatusBarView;
@class CPWeatherGenericView;
@class CWManager;
@class CWOnlineCityData;
@class CalcListView;
@class CaptionsLayouter;
@class CitiesListController;
@class CitiesListDraggAcceptButton;
@class CityInfoController;
@class CityInfoSelectionView;
@class CityInfoView;
@class CityPropertyAccessibilityObject;
@class CityPropertyGenericView;
@class CloudsManager;
@class CloudsMaterial;
@class CompanyLinkButton;
@class CompassAccessibilityObject;
@class CompassButton;
@class CompassCell;
@class CopyrightTextField;
@class CountryHiliter;
@class CountryHiliterTexturesStorage;
@class DBCityEntry;
@class DownloadManager;
@class DragSourceTableView;
@class DrawerController;
@class DrawerImageView;
@class DynamicEnvironment;
@class EFBox;
@class EFOneDayController;
@class FlatDrawView;
@class FlatMapController;
@class FlatMapCountryHiliter;
@class FlatMapScene;
@class FlatRoutePointsContainer;
@class FrameView;
@class FullCityInfoController;
@class GeoLocCityEntry;
@class ImageBLOB;
@class ImageViewAccessibilityIgnored;
@class ImagesSequence;
@class IndexBuffersBLOB;
@class InfoDrawer;
@class InfoDrawerController;
@class LayoutView;
@class LinkButton;
@class LookupGridBLOB;
@class MainCitiesListScrollView;
@class MainListController;
@class MainWindow;
@class MainWindowController;
@class MapPartsLoader;
@class MinimapCell;
@class PantherSpecificClass;
@class PlistBLOB;
@class PrefApearanceController;
@class PrefCloudsController;
@class PrefGeneralController;
@class PrefGenericController;
@class PrefMyLocationController;
@class PrefOnlineController;
@class PrefScreenSaverController;
@class Preferences;
@class PreferencesController;
@class PreferencesToolbarItem;
@class PrintController;
@class PrintingView;
@class RemoteControlBackgroundView;
@class RemoteControlController;
@class RemoteControlScaleSlider;
@class RemoteControlScaleSliderCell;
@class RemoteControlWindow;
@class RoutePointsContainer;
@class SQLiteDatabase;
@class SQLiteResultsContainer;
@class SQLiteStatement;
@class SQLiteTable;
@class ScalingIconsButton;
@class SelectCityBackgroundView;
@class SelectCityDialogController;
@class SelectCityWindow;
@class SphereCountryHiliter;
@class SphereDrawView;
@class SphereMapController;
@class SphereMapScene;
@class SphereRoutePointsContainer;
@class StartStopTrackNotifySlider;
@class TextFieldAccessibilityIgnored;
@class TextFieldCell;
@class TimeController;
@class VersionTextField;
@class VertexBuffersBLOB;
@class WBAStartupDelegate;
@class WBAlert;
@class WBAlertClearView;
@class WBAlertImageView;
@class WBAlertWindow;
@class WSSubscriptionController;
@class WSSubsribtionTextFormatter;
@class WeatherPrintController;
@class WeatherPrintingData;
@class WeatherPrintingView;
@class YACityEntry;
@class YAConnection;

struct WeatherGlobe_anon1 {
    float x;
    float y;
    float z;
};

struct WeatherGlobe_anon2 {
    float f0;
    float f1;
    float f2;
};

struct WeatherGlobe_anon3 {
    float f0;
    float f1;
    float f2;
    float f3;
    float f4;
    float f5;
    float f6;
    float f7;
    float f8;
    float f9;
    float f10;
    float f11;
    float f12;
    float f13;
    float f14;
    float f15;
};

struct WeatherGlobe_anon4 {
    struct WeatherGlobe_anon2 f0;
};

struct WeatherGlobe_anon5 {
    float f0;
    float f1;
};

struct WeatherGlobe_anon6 {
    float r;
    float g;
    float b;
    float a;
};

struct WeatherGlobe_anon7 {
    float f0;
    float f1;
    float f2;
    float f3;
};

struct WeatherGlobe_anon8 {
    struct WeatherGlobe_anon2 f0;
    struct WeatherGlobe_anon7 f1;
};

struct __dvFlags {
    unsigned int drawsMap:1;
    unsigned int drawsClouds:1;
    unsigned int drawsDayNight:1;
    unsigned int drawsGrid:1;
    unsigned int drawsCountryBorders:1;
    unsigned int drawsCountryNames:1;
    unsigned int drawsStateBorders:1;
    unsigned int drawsStateNames:1;
    unsigned int drawsAllCities:1;
    unsigned int drawsRouteMarkers:1;
    unsigned int drawsRouteLines:1;
    unsigned int drawsRouteNames:1;
    unsigned int drawsCityBorder:1;
    unsigned int drawsAppleStores:1;
    unsigned int _reserved:20;
};

struct WeatherGlobe_anon9 {
    float _11;
    float _12;
    float _13;
    float _14;
    float _21;
    float _22;
    float _23;
    float _24;
    float _31;
    float _32;
    float _33;
    float _34;
    float _41;
    float _42;
    float _43;
    float _44;
};

struct WeatherGlobe_anon10 {
    float x;
    float y;
};


#import "WeatherGlobeGlobals.h"
#import "WeatherGlobeFunctions.h"
