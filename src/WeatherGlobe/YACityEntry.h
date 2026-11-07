#import "WeatherGlobePrefix.h"


@interface YACityEntry : NSObject
{
    struct WeatherGlobe_anon6 _color;
    BOOL _colorIsValid;
    NSPoint _geoPoint;
    struct WeatherGlobe_anon1 _earthVec;
    NSMutableDictionary *_BLOBwrappers;
    CWOnlineCityData *_onlineWrapper;
}
+ (id)entryWithDictionaryRep:(id)aRep;
+ (id)entryWithGeoPoint:(NSPoint)aPoint;
+ (id)entryWithGeoObjectDictionary:(id)aDictionary;
- (void)setCoordinates:(NSPoint)aCoordinates;
- (void)setShortCaption:(id)aCaption;
- (id)wrapperWithRepresentationOfType:(id)aType createIfNeeded:(BOOL)aNeeded;
- (NSInteger)customWeatherID;
- (CGFloat)population;
- (id)alternativeNames;
- (id)countryName;
- (id)stateName;
- (id)countyName;
- (id)ownType;
- (NSInteger)currentGMTOffset;
- (id)uid;
- (id)timeZone;
- (id)shortCaption;
- (id)regionName;
- (id)ownName;
- (CGFloat)distanceToEntry:(id)aEntry;
- (struct WeatherGlobe_anon2 *)vectorFromEarthCenter;
- (struct WeatherGlobe_anon7 *)cityMarkerColor;
- (NSPoint)coordinates;
- (id)entryDictionary;
- (BOOL)isPermanent;
- (id)dictionaryForReport:(NSInteger)aReport;
- (void)manualUpdateOfScheduledReports;
- (void)unscheduleAllReports;
- (void)unscheduleReports:(NSUInteger)aReports;
- (void)scheduleReports:(NSUInteger)aReports;
- (void)postSingleDownloadTaskForReports:(NSUInteger)aReports;
- (id)onlineWrapper;
- (void)_wrapperDataWasExpired:(id)aExpired;
- (void)_wrapperDataWasUpdated:(id)aUpdated;
- (id)_createWrapperIfNeeded;
- (id)description;
- (void)dealloc;
@end

@interface DBCityEntry : YACityEntry
{
    NSString *_timeZoneName;
    NSString *_ownName;
    NSString *_regionName;
    NSString *_shortCaption;
    NSString *_uid;
    NSTimeZone *_timeZone;
    NSString *_country_uid;
    NSString *_state_uid;
    NSString *_county_uid;
    NSString *_countyName;
    NSString *_stateName;
    NSString *_countryName;
    NSString *_ownType;
    float _population;
    int _currentGMTOffset;
    int _cw_id;
    NSString *_altNamesStr;
    NSArray *_altNamesArray;
}
- (NSInteger)customWeatherID;
- (CGFloat)population;
- (id)alternativeNames;
- (id)countryName;
- (id)stateName;
- (id)countyName;
- (id)ownType;
- (NSInteger)currentGMTOffset;
- (id)uid;
- (id)timeZone;
- (id)shortCaption;
- (id)regionName;
- (id)ownName;
- (BOOL)isPermanent;
- (void)dealloc;
- (id)initWithGeoObjectDictionary:(id)aDictionary;
@end

