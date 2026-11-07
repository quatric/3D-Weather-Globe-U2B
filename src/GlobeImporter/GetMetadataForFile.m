// Spotlight importer for route files: indexes the names of the route's
// stops as the file's text content. Reads both the old format (a bare array
// of entries) and the current one (a dictionary with an "entries" array).
#import <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>

static NSString *const space = @" ";

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes,
                           CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *path = (NSString *)pathToFile;
	NSArray *entries = [NSArray arrayWithContentsOfFile:path];
	if (entries == nil)
		entries = [[NSDictionary dictionaryWithContentsOfFile:path] objectForKey:@"entries"];

	NSUInteger count = [entries count];
	if (count == 0) {
		[pool release];
		return FALSE;
	}

	NSMutableString *text = [NSMutableString string];
	for (NSUInteger i = 0; i < count; i++) {
		NSString *name = [[entries objectAtIndex:i] objectForKey:@"CityName"];
		if ([name length]) {
			[text appendString:name];
			[text appendString:space];
		}
	}
	[(NSMutableDictionary *)attributes setObject:text forKey:(NSString *)kMDItemTextContent];
	[pool release];
	return TRUE;
}
