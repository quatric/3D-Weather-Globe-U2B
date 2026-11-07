#import "WeatherGlobePrefix.h"
#import "GeoLocCityEntry.h"


@interface AppleStoreEntry : GeoLocCityEntry
{
    NSString *_alternativeName;
    NSString *_address;
    NSString *_url;
    NSString *_additionalInfo;
    NSString *_infoPaletteTitle;
    NSString *_markerString;
    struct WeatherGlobe_anon6 _markerColor;
    int _markerSize;
}
+ (id)entryWithDictionaryRep:(id)aRep;
+ (id)appleStoreWithGeoPoint:(NSPoint)aPoint cityName:(id)aName alternativeName:(id)aName2 address:(id)aAddress url:(id)aUrl additionalInfo:(id)aInfo markerString:(id)aString markerColor:(struct WeatherGlobe_anon7)aColor markerSize:(NSInteger)aSize infoPaletteTitle:(id)aTitle;
- (void)setInfoPaletteTitle:(id)aTitle;
- (id)infoPaletteTitle;
- (void)setMarkerSize:(NSInteger)aSize;
- (NSInteger)markerSize;
- (void)setMarkerColor:(struct WeatherGlobe_anon7)aColor;
- (struct WeatherGlobe_anon7)markerColor;
- (void)setMarkerString:(id)aString;
- (id)markerString;
- (void)setAdditionalInfo:(id)aInfo;
- (void)setURL:(id)aURL;
- (void)setAddress:(id)aAddress;
- (void)setAlternativeName:(id)aName;
- (void)setCoordinates:(NSPoint)aCoordinates;
- (id)additionalInfo;
- (id)url;
- (id)address;
- (id)alternativeName;
- (void)dealloc;
- (id)entryDictionary;
- (id)initWithGeoPoint:(NSPoint)aPoint cityName:(id)aName alternativeName:(id)aName2 address:(id)aAddress url:(id)aUrl additionalInfo:(id)aInfo markerString:(id)aString markerColor:(struct WeatherGlobe_anon7)aColor markerSize:(NSInteger)aSize infoPaletteTitle:(id)aTitle;
@end

