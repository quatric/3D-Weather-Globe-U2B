#import "WeatherGlobePrefix.h"


@interface NSArray (NSArrayBinarySearch)
- (NSUInteger)indexOfObjectUsingFunctionComparator:(void *)aComparator withKey:(void *)aKey;
- (NSUInteger)indexOfObject:(id)aObject usingSelector:(SEL)aSelector;
@end

