#import "WeatherGlobePrefix.h"


@interface NSString (StringExtension)
+ (id)shortGeoCoordinatesDescription:(NSPoint)aDescription;
+ (id)latitudeDesription:(CGFloat)aDesription;
+ (id)longitudeDesription:(CGFloat)aDesription;
+ (id)monthAbbreviation:(NSInteger)aAbbreviation;
+ (id)weekdayAbbreviation:(NSInteger)aAbbreviation;
@end

