#import "WeatherGlobePrefix.h"


// Weather from AccuWeather instead of MacKiev's CustomWeather service, whose
// authorization server no longer lets clients in. Used when the defaults hold
// an API key (AccuWeatherAPIKey). The reports come back as the CustomWeather
// XML that CWManager parses.
@interface AccuWeatherClient : NSObject
+ (BOOL)isEnabled;
+ (void)loadReport:(NSInteger)aReport forEntry:(id)aEntry completion:(void (^)(NSData *aXML))aCompletion;
+ (void)cancelReport:(NSInteger)aReport forEntry:(id)aEntry;
@end
