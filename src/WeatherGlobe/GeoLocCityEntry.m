#import "GeoLocCityEntry.h"

@implementation GeoLocCityEntry

- (void)setGeoPoint:(NSPoint)aPoint
{
    _geoPoint = aPoint;
    SMK_GL_Vec3 vec = _earthVecFromGeoPoint(aPoint);
    _earthVec.x = vec.x;
    _earthVec.y = vec.y;
    _earthVec.z = vec.z;
}

- (void)setShortCaption:(id)aCaption
{
    NSScanner *scanner = [NSScanner scannerWithString:aCaption];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"] intoString:&aCaption];
    if ([aCaption length] > 50)
        aCaption = [aCaption stringByPaddingToLength:50 withString:@"" startingAtIndex:0];
    [aCaption retain];
    [_name release];
    _name = aCaption;
}

- (id)uid
{
    if (_uid == nil) {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        _uid = (NSString *)CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
    }
    return _uid;
}

- (id)shortCaption
{
    if (_name == nil) {
        NSPoint point = [self coordinates];
        _name = [[NSString alloc] initWithFormat:@"(%@, %@)",
            [NSString latitudeDesription:point.y], [NSString longitudeDesription:point.x]];
    }
    return _name;
}

- (id)ownName
{
    return [self shortCaption];
}

- (id)entryDictionary
{
    NSMutableDictionary *dictionary = [[[super entryDictionary] mutableCopy] autorelease];
    [dictionary setObject:@"1" forKey:kCityEntryIsGeoLoc];
    return dictionary;
}

- (void)dealloc
{
    [_name release];
    [_uid release];
    [super dealloc];
}

- (id)initWithGeoPoint:(NSPoint)aPoint shortCaption:(id)aCaption uid:(id)aUid
{
    self = [super init];
    if (self != nil) {
        _geoPoint = aPoint;
        SMK_GL_Vec3 vec = _earthVecFromGeoPoint(aPoint);
        _earthVec.x = vec.x;
        _earthVec.y = vec.y;
        _earthVec.z = vec.z;
        _uid = [aUid retain];
        _name = [aCaption retain];
    }
    return self;
}

- (id)initWithGeoPoint:(NSPoint)aPoint
{
    return [self initWithGeoPoint:aPoint shortCaption:nil uid:nil];
}

@end
