#import "LiveCloudMaps.h"
#import <ImageIO/ImageIO.h>

static NSString *const _kMapURL = @"https://clouds.matteason.co.uk/images/2048x1024/clouds.jpg";
// the service publishes a new map every three hours
static const NSTimeInterval _kMapLifetime = 30.0 * 60.0;

static NSData *_sMap;            // the global map, west half on the left
static NSDate *_sMapDate;
static NSMutableArray *_sWaiting;

// Clear sky is mid gray in these maps and black in the old feed's, which the
// app draws as cloud opacity; the curve keeps clear sky transparent.
static unsigned char _level(int aValue)
{
	double v = (aValue - 120) / 135.0;
	if (v <= 0.0)
		return 0;
	return (unsigned char)(v >= 1.0 ? 255 : v * v * 255.0 + 0.5);
}

static NSData *_hemisphere(NSData *aMap, BOOL aEast, NSInteger aSize)
{
	CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)aMap, NULL);
	CGImageRef image = source != NULL ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
	CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
	CGContextRef context = CGBitmapContextCreate(NULL, aSize, aSize, 8, aSize, gray, (CGBitmapInfo)kCGImageAlphaNone);
	NSMutableData *jpeg = nil;
	unsigned char table[256];
	int i;

	if (source != NULL)
		CFRelease(source);
	if (image != NULL && context != NULL) {
		unsigned char *pixels = CGBitmapContextGetData(context);
		CGImageRef half;
		CGImageDestinationRef destination;

		// the whole map is drawn twice as wide, so one half fills the context
		CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
		CGContextDrawImage(context, CGRectMake(aEast ? -aSize : 0, 0, aSize * 2, aSize), image);
		for (i = 0; i < 256; i++)
			table[i] = _level(i);
		for (i = 0; i < aSize * aSize; i++)
			pixels[i] = table[pixels[i]];
		half = CGBitmapContextCreateImage(context);
		jpeg = [NSMutableData data];
		destination = CGImageDestinationCreateWithData((CFMutableDataRef)jpeg, CFSTR("public.jpeg"), 1, NULL);
		if (destination != NULL) {
			CGImageDestinationAddImage(destination, half, (CFDictionaryRef)[NSDictionary dictionaryWithObject:
				[NSNumber numberWithDouble:0.85] forKey:(id)kCGImageDestinationLossyCompressionQuality]);
			if (!CGImageDestinationFinalize(destination))
				jpeg = nil;
			CFRelease(destination);
		} else {
			jpeg = nil;
		}
		CGImageRelease(half);
	}
	if (context != NULL)
		CGContextRelease(context);
	CGColorSpaceRelease(gray);
	if (image != NULL)
		CGImageRelease(image);
	return jpeg;
}

@implementation LiveCloudMaps

+ (BOOL)isEnabled
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"LiveCloudMapsDisabled"];
}

+ (void)_deliver:(void (^)(NSData *))aCompletion east:(BOOL)aEast size:(NSInteger)aSize
{
	NSData *map = [[_sMap retain] autorelease];
	if (map == nil) {
		aCompletion(nil);
		return;
	}
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
		NSData *jpeg = [_hemisphere(map, aEast, aSize) retain];
		dispatch_async(dispatch_get_main_queue(), ^{
			aCompletion(jpeg);
			[jpeg release];
		});
		[pool release];
	});
}

+ (void)loadMapForEast:(BOOL)aEast size:(NSInteger)aSize completion:(void (^)(NSData *aJPEG))aCompletion
{
	void (^request)(void) = [[^{
		[self _deliver:aCompletion east:aEast size:aSize];
	} copy] autorelease];

	if (_sMap != nil && -[_sMapDate timeIntervalSinceNow] < _kMapLifetime) {
		request();
		return;
	}
	if (_sWaiting != nil) {
		[_sWaiting addObject:request];
		return;
	}
	_sWaiting = [[NSMutableArray alloc] initWithObjects:request, nil];
	[[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:_kMapURL]
		completionHandler:^(NSData *aData, NSURLResponse *aResponse, NSError *aError) {
		NSInteger status = [aResponse isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)aResponse statusCode] : 0;
		dispatch_async(dispatch_get_main_queue(), ^{
			NSArray *waiting = [_sWaiting autorelease];
			_sWaiting = nil;
			if (status == 200 && [aData length] != 0) {
				[_sMap release];
				_sMap = [aData retain];
				[_sMapDate release];
				_sMapDate = [NSDate new];
			} else {
				NSLog(@"Live Cloud Maps request failed: HTTP %ld %@", (long)status, aError ? [aError localizedDescription] : @"");
			}
			for (void (^block)(void) in waiting)
				block();
		});
	}] resume];
}

@end
