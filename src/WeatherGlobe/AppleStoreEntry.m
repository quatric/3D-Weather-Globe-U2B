#import "AppleStoreEntry.h"

@implementation AppleStoreEntry

static float _colorComponent(NSDictionary *aRep, NSString *aKey)
{
    id value = [aRep objectForKey:aKey];
    return value != nil ? [value floatValue] : 1.0f;
}

+ (id)entryWithDictionaryRep:(id)aRep
{
    if (aRep == nil)
        return nil;
    struct WeatherGlobe_anon7 color;
    color.f0 = _colorComponent(aRep, kAppleStoreListEntryMarkerColorR);
    color.f1 = _colorComponent(aRep, kAppleStoreListEntryMarkerColorG);
    color.f2 = _colorComponent(aRep, kAppleStoreListEntryMarkerColorB);
    color.f3 = _colorComponent(aRep, kAppleStoreListEntryMarkerColorA);
    float lat = [[aRep objectForKey:kCityEntryLat] floatValue];
    float lon = [[aRep objectForKey:kCityEntryLong] floatValue];
    return [AppleStoreEntry appleStoreWithGeoPoint:NSMakePoint(lon, lat)
                                          cityName:[aRep objectForKey:kCityEntryName]
                                   alternativeName:[aRep objectForKey:kAppleStoreListEntryAlternativeName]
                                           address:[aRep objectForKey:kAppleStoreListEntryAddress]
                                               url:[aRep objectForKey:kAppleStoreListEntryURL]
                                    additionalInfo:[aRep objectForKey:kAppleStoreListEntryAdditionalInfo]
                                      markerString:[aRep objectForKey:kAppleStoreListEntryMarkerString]
                                       markerColor:color
                                        markerSize:[[aRep objectForKey:kAppleStoreListEntryMarkerSize] intValue]
                                  infoPaletteTitle:[aRep objectForKey:kAppleStoreListEntryInfoPaletteTitle]];
}

+ (id)appleStoreWithGeoPoint:(NSPoint)aPoint cityName:(id)aName alternativeName:(id)aName2 address:(id)aAddress url:(id)aUrl additionalInfo:(id)aInfo markerString:(id)aString markerColor:(struct WeatherGlobe_anon7)aColor markerSize:(NSInteger)aSize infoPaletteTitle:(id)aTitle
{
    return [[[AppleStoreEntry alloc] initWithGeoPoint:aPoint cityName:aName alternativeName:aName2 address:aAddress url:aUrl additionalInfo:aInfo markerString:aString markerColor:aColor markerSize:aSize infoPaletteTitle:aTitle] autorelease];
}

- (void)setInfoPaletteTitle:(id)aTitle
{
    [aTitle retain];
    [_infoPaletteTitle release];
    _infoPaletteTitle = aTitle;
}

- (id)infoPaletteTitle
{
    return _infoPaletteTitle;
}

- (void)setMarkerSize:(NSInteger)aSize
{
    _markerSize = (int)aSize;
}

- (NSInteger)markerSize
{
    return _markerSize;
}

- (void)setMarkerColor:(struct WeatherGlobe_anon7)aColor
{
    _markerColor.r = aColor.f0;
    _markerColor.g = aColor.f1;
    _markerColor.b = aColor.f2;
    _markerColor.a = aColor.f3;
}

- (struct WeatherGlobe_anon7)markerColor
{
    struct WeatherGlobe_anon7 color = {_markerColor.r, _markerColor.g, _markerColor.b, _markerColor.a};
    return color;
}

- (void)setMarkerString:(id)aString
{
    [aString retain];
    [_markerString release];
    _markerString = aString;
}

- (id)markerString
{
    return _markerString;
}

- (void)setAdditionalInfo:(id)aInfo
{
    [aInfo retain];
    [_additionalInfo release];
    _additionalInfo = aInfo;
}

- (void)setURL:(id)aURL
{
    [aURL retain];
    [_url release];
    _url = aURL;
}

- (void)setAddress:(id)aAddress
{
    [aAddress retain];
    [_address release];
    _address = aAddress;
}

- (void)setAlternativeName:(id)aName
{
    [aName retain];
    [_alternativeName release];
    _alternativeName = aName;
}

- (void)setCoordinates:(NSPoint)aCoordinates
{
    [super setGeoPoint:aCoordinates];
}

- (id)additionalInfo
{
    return _additionalInfo;
}

- (id)url
{
    return _url;
}

- (id)address
{
    return _address;
}

- (id)alternativeName
{
    return _alternativeName;
}

- (void)dealloc
{
    [_alternativeName release];
    [_address release];
    [_url release];
    [_additionalInfo release];
    [_markerString release];
    [_infoPaletteTitle release];
    [super dealloc];
}

- (id)entryDictionary
{
    struct WeatherGlobe_anon7 color = [self markerColor];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self shortCaption], kCityEntryName,
            [self alternativeName], kAppleStoreListEntryAlternativeName,
            [NSNumber numberWithFloat:_geoPoint.x], kCityEntryLong,
            [NSNumber numberWithFloat:_geoPoint.y], kCityEntryLat,
            [self address], kAppleStoreListEntryAddress,
            [self url], kAppleStoreListEntryURL,
            [self additionalInfo], kAppleStoreListEntryAdditionalInfo,
            [self markerString], kAppleStoreListEntryMarkerString,
            [NSNumber numberWithFloat:color.f0], kAppleStoreListEntryMarkerColorR,
            [NSNumber numberWithFloat:color.f1], kAppleStoreListEntryMarkerColorG,
            [NSNumber numberWithFloat:color.f2], kAppleStoreListEntryMarkerColorB,
            [NSNumber numberWithFloat:color.f3], kAppleStoreListEntryMarkerColorA,
            [NSNumber numberWithInt:(int)[self markerSize]], kAppleStoreListEntryMarkerSize,
            [self infoPaletteTitle], kAppleStoreListEntryInfoPaletteTitle,
            nil];
}

- (id)initWithGeoPoint:(NSPoint)aPoint cityName:(id)aName alternativeName:(id)aName2 address:(id)aAddress url:(id)aUrl additionalInfo:(id)aInfo markerString:(id)aString markerColor:(struct WeatherGlobe_anon7)aColor markerSize:(NSInteger)aSize infoPaletteTitle:(id)aTitle
{
    self = [super initWithGeoPoint:aPoint shortCaption:aName uid:nil];
    if (self != nil) {
        _alternativeName = [aName2 retain];
        _address = [aAddress retain];
        _url = [aUrl retain];
        _additionalInfo = [aInfo retain];
        _markerString = [aString retain];
        [self setMarkerColor:aColor];
        _markerSize = (int)aSize;
        _infoPaletteTitle = [aTitle retain];
    }
    return self;
}

@end
