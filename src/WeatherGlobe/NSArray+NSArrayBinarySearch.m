#import "NSArray+NSArrayBinarySearch.h"

// Binary searches of sorted arrays. The comparison returns -1, 0 or 1 for
// the key against an element; the result is the match, NSNotFound for an
// empty array, or the index where the search ended.
@implementation NSArray (NSArrayBinarySearch)

// The original takes the high half without moving the low bound when the
// key compares greater, so the search ends with the bounds one apart.
- (NSUInteger)indexOfObjectUsingFunctionComparator:(void *)aComparator withKey:(void *)aKey
{
	int (*comparator)(id, void *) = (int (*)(id, void *))aComparator;
	if ([self count] == 0) {
		return NSNotFound;
	}
	unsigned int high = (unsigned int)[self count] - 1;
	unsigned int low = 0;
	while (low < high) {
		unsigned int middle = (low + high) >> 1;
		int order = comparator([self objectAtIndex:middle], aKey);
		if (order == 0) {
			return middle;
		}
		if (order == 1) {
			high = middle;
		} else if (order == -1) {
			if (high - low == 1) {
				return low;
			}
			low = middle;
		}
	}
	return low;
}

// aSelector is sent to aObject with each element and returns an NSComparisonResult
- (NSUInteger)indexOfObject:(id)aObject usingSelector:(SEL)aSelector
{
	if ([self count] == 0) {
		return NSNotFound;
	}
	unsigned int high = (unsigned int)[self count] - 1;
	unsigned int low = 0;
	for (;;) {
		unsigned int start = low;
		if (high <= start) {
			return start;
		}
		unsigned int middle = (start + high) >> 1;
		NSComparisonResult (*send)(id, SEL, SEL, id) = (NSComparisonResult (*)(id, SEL, SEL, id))objc_msgSend;
		int order = (int)send(aObject, @selector(performSelector:withObject:), aSelector, [self objectAtIndex:middle]);
		if (order == 0) {
			return middle;
		}
		if (order == 1) {
			low = middle;
			if (high - start == 1) {
				return start;
			}
		} else if (order == -1) {
			high = middle;
		}
	}
}

@end
