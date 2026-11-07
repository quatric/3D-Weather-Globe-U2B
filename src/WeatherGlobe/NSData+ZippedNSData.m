#import "NSData+ZippedNSData.h"

// Zipped data is the zlib stream followed by the original length (big
// endian) and the tag 'zdat'.
@implementation NSData (ZippedNSData)

- (id)originalRepresentation
{
	const unsigned char *bytes = [self bytes];
	NSUInteger length = [self length];
	uLongf originalLength = OSReadBigInt32(bytes, length - 8);
	if (OSReadBigInt32(bytes, length - 4) != 'zdat') {
		[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
		    file:[NSString stringWithCString:"/Users/3dwgbuilder/Projects/3DWGBuildFolder/WBAll/WBAtlas/Sources/Extensions/WBData.m"
		                            encoding:NSASCIIStringEncoding]
		    lineNumber:34 description:@"Broken original when passing to unzip"];
	}
	NSMutableData *data = [NSMutableData dataWithLength:originalLength];
	uncompress([data mutableBytes], &originalLength, [self bytes], (uLong)[self length]);
	return data;
}

- (id)zippedRepresentation
{
	uLongf zippedLength = (uLongf)[self length] + 2000;
	NSMutableData *data = [NSMutableData dataWithLength:zippedLength];
	compress([data mutableBytes], &zippedLength, [self bytes], (uLong)[self length]);
	[data setLength:zippedLength + 8];
	OSWriteBigInt32([data mutableBytes], zippedLength, (uint32_t)[self length]);
	OSWriteBigInt32([data mutableBytes], zippedLength + 4, 'zdat');
	return data;
}

@end
