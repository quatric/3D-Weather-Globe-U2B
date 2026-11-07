#import "WeatherGlobePrefix.h"


@interface NSCalendarDate (DescriptionsExtension)
+ (NSInteger)monthWithMaxAbbrDescriptionWidth;
+ (NSInteger)weekdayWithMaxAbbrDescriptionWidth;
- (id)descriptionDateTime;
- (id)descriptionDate;
- (id)descriptionTimeZone;
- (id)descriptionGMTOffset;
@end

@interface NSDictionary (CWExtension)
- (id)pressureForKey:(id)aKey;
- (id)weatherDescription;
- (id)warningsDescription;
- (id)warningColor;
- (id)_localizedDesc:(id)aDesc;
- (id)windImageForKey:(id)aKey;
- (id)weatherImageForKey:(id)aKey;
- (NSInteger)weatherImageIndexForKey:(id)aKey;
- (id)percentsForKey:(id)aKey;
- (id)distanceForKey:(id)aKey;
- (id)speedValueForKey:(id)aKey;
- (id)speedForKey:(id)aKey;
- (id)temperatureForKey:(id)aKey;
- (id)shortTempratureForKey:(id)aKey;
@end

