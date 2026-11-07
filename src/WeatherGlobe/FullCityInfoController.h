#import "WeatherGlobePrefix.h"


@interface FullCityInfoController : NSObject
{
    NSPanel *_panel;
    NSTextField *_cityName;
    NSTextField *_region;
    NSTextField *_dateTime;
    NSTextField *_coordinates;
    NSView *_giContainerView;
    NSTextField *_temperature;
    NSTextField *_visibility;
    NSTextField *_pressure;
    NSTextField *_ccDewPoint;
    NSTextField *_ccComfortLevel;
    NSTextField *_ccWindSpeed;
    NSTextField *_ccHumidity;
    NSImageView *_ccSummary;
    NSImageView *_ccWindDirection;
    NSView *_ccContainerView;
    NSButton *_ccDisclosure;
    NSTextField *_ccExpiredText;
    int _ccSummaryToolTipTag;
    SMKSegmentedControl *_weekdays;
    NSTextField *_temperatureHigh;
    NSTextField *_temperatureLow;
    NSTextField *_precipitation;
    NSTextField *_uvIndex;
    NSTextField *_ffDewPoint;
    NSTextField *_efComfortLevel;
    NSTextField *_efWindSpeed;
    NSTextField *_efHumidity;
    NSImageView *_efSummary;
    NSImageView *_efWindDirection;
    NSView *_efContainerView;
    NSButton *_efDisclosure;
    NSTextField *_efExpiredText;
    int _efSummaryToolTipTag;
    NSTextField *_sunrise;
    NSTextField *_moonrise;
    NSTextField *_sunset;
    NSTextField *_moonset;
    NSView *_afContainerView;
    NSButton *_afDisclosure;
    NSTextField *_afExpiredText;
    NSProgressIndicator *_progressIndicator;
    NSBox *_separator1;
    NSBox *_separator2;
    NSBox *_separator3;
    NSButton *_manualUpdateButt;
    BOOL _scheduled;
    YACityEntry *_entry;
    BOOL _usesInternet;
    float _giHeight;
    float _ccHeight;
    float _efHeight;
    float _afHeight;
    int _ccDisclosureState;
    int _efDisclosureState;
    int _afDisclosureState;
}
+ (void)doPrint:(id)aPrint;
+ (void)refreshWithCityEntry:(id)aEntry;
+ (void)showWithCityEntry:(id)aEntry;
+ (BOOL)isVisible;
+ (id)sharedInstance;
- (void)runPageLayout:(id)aLayout;
- (void)doPrint:(id)aPrint;
- (void)manualUpdate:(id)aUpdate;
- (void)weekdayAction:(id)aAction;
- (void)disclosureAction:(id)aAction;
- (void)_reportsWereChanged:(id)aChanged;
- (void)_acceptAdjustTime:(id)aTime;
- (void)_clocksMeasureWereChanged:(id)aChanged;
- (void)_unitsOfMeasureWereChanged:(id)aChanged;
- (void)_internetStateWasChanged:(id)aChanged;
- (void)windowWillClose:(id)aClose;
- (BOOL)isVisible;
- (id)view:(id)aView stringForToolTip:(NSInteger)aTip point:(NSPoint)aPoint userData:(void *)aData;
- (void)_timeForRefresh:(id)aRefresh;
- (void)_showWithCityEntry:(id)aEntry;
- (void)_refreshWithCityEntry:(id)aEntry;
- (void)_refresh;
- (void)_setExpandedForecast:(id)aForecast;
- (void)_setCurrentConditions:(id)aConditions;
- (void)_adjustTime;
- (void)_unschedule;
- (void)_schedule;
- (void)_checkProgressIndicatorAnimation;
- (BOOL)_isWeatherExpired;
- (BOOL)_isExpandedForecastExpired;
- (BOOL)_isCurrentConditionExpired;
- (void)_loadNibIfNeeded;
- (void)dealloc;
- (void)awakeFromNib;
- (void)_refreshToolTipRects;
- (void)_checkInternet;
@end

@interface EFBox : NSBox
{
}
- (void)drawRect:(NSRect)aRect;
@end

