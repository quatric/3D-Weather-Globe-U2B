#import "SphereDrawView.h"

// Renders an orthographic view of the globe seen from aPosition (fractions
// of a turn in longitude and latitude) into aDest from the west and east
// halves of the flat map; pixels near the rim fade to white.
static void _projectSphereToFlatImage(NSBitmapImageRep *aWest, NSBitmapImageRep *aEast, NSBitmapImageRep *aDest, float aLongitude, float aLatitude)
{
    NSInteger size = [aWest pixelsWide];
    NSInteger destSize = [aDest pixelsWide];
    if (size != [aWest pixelsHigh] || size != [aEast pixelsWide] || size != [aEast pixelsHigh] || destSize != [aDest pixelsHigh])
        return;
    const unsigned char *west = [aWest bitmapData];
    const unsigned char *east = [aEast bitmapData];
    unsigned char *dest = [aDest bitmapData];
    memset(dest, 0xff, destSize * destSize * [aDest samplesPerPixel]);
    float step = 2.0f / ((float)destSize + 0.01f);
    SMK_GL_Matrix rotZ, rotY, matrix;
    SMK_GL_Vec3 axis = {0, 0, 1};
    rotateMatrix(&rotZ, aLongitude * 6.2831855f, &axis);
    axis = (SMK_GL_Vec3){0, 1, 0};
    rotateMatrix(&rotY, (aLatitude - 0.5f) * 3.1415927f, &axis);
    matrix_mul(&matrix, &rotZ, &rotY);
    float fsize = (float)size;
    for (NSInteger row = 0; row < destSize; row++) {
        float y = step * (float)row - 1.0f;
        float halfWidth = sqrtf(1.0f - y * y);
        unsigned char *pixel = dest;
        float x = -1.0f;
        for (NSInteger column = 0; column < destSize; column++, x += step, pixel += 4) {
            if (x > halfWidth || x < -halfWidth)
                continue;
            float r2 = x * x + y * y;
            float rim = r2 * r2 * r2 * r2;
            rim *= rim;
            rim *= rim;
            SMK_GL_Vec3 vec = {sqrtf(1.0f - r2), x, y};
            SMK_GL_Vec4 earth;
            vec3_matrix_mul(&earth, &vec, &matrix);
            SMK_GL_Vec3 earthVec = {earth.x, earth.y, earth.z};
            NSPoint mapPoint = _mapPointFromEarthVec(&earthVec);
            float mapX = mapPoint.x;
            int sourceRow = (int)((float)mapPoint.y * fsize);
            BOOL isEast = mapX > 0.5f;
            if (isEast)
                mapX -= 0.5f;
            int sourceColumn = (int)(mapX * (fsize + fsize));
            if (sourceRow >= size || sourceRow < 0 || sourceColumn >= size || sourceColumn < 0)
                continue;
            const unsigned char *source = (isEast ? east : west) + (sourceColumn + sourceRow * size) * 4;
            unsigned char r = source[0], g = source[1], b = source[2];
            if (rim > 0.01f) {
                float keep = 1.0f - rim;
                float white = rim * 255.0f;
                r = (unsigned char)(int)((float)r * keep + white);
                g = (unsigned char)(int)((float)g * keep + white);
                b = (unsigned char)(int)(white + (float)b * keep);
            }
            pixel[0] = r;
            pixel[1] = g;
            pixel[2] = b;
            pixel[3] = source[3];
        }
        dest += destSize * 4;
    }
}

// light factors for one map pixel: how much of the day image, of the night
// image and of the clouds it shows
static void _dayNightFactors(float aDot, float *aDay, float *aNight, float *aClouds)
{
    float day = 0.25f - aDot * 4.0f;
    if (day > 1.0f) {
        *aNight = 0.0f;
        day = 1.0f;
        *aClouds = 0.5f;
    } else if (day < 0.25f) {
        day = 0.25f;
        *aNight = 0.25f * 0.7f * 4.0f;
        *aClouds = 0.25f * 0.5f;
    } else if (day > 0.5f) {
        *aClouds = day * 0.5f;
        *aNight = 0.0f;
    } else {
        *aNight = (0.5f - day) * 0.7f * 4.0f;
        *aClouds = day * 0.5f;
    }
    *aClouds += 0.5f;
    *aDay = day;
}

// bilinear sample of one channel of the clouds bitmap
static float _cloudSample(const unsigned char *aData, int aChannel, float aX, float aY, int aWidth, int aHeight, int aBytesPerPixel, int aBytesPerRow)
{
    int ix = (int)aX, iy = (int)aY;
    float tx = aX - floorf(aX);
    float ty = aY - floorf(aY);
    int row0 = aBytesPerRow * iy, row1 = aBytesPerRow * (iy + 1);
    int col0 = aBytesPerPixel * ix, col1 = aBytesPerPixel * (ix + 1);
    BOOL hasNextRow = iy + 1 < aHeight, hasNextColumn = ix + 1 < aWidth;
    float p00 = aData[aChannel + row0 + col0];
    float p10 = hasNextColumn ? aData[aChannel + row0 + col1] : p00;
    float p01 = hasNextRow ? aData[aChannel + row1 + col0] : p00;
    float p11 = aData[aChannel + (hasNextRow ? row1 : row0) + (hasNextColumn ? col1 : col0)];
    float top = p00 + (float)(int)(p10 - p00) * tx;
    float bottom = p01 + (float)(int)(p11 - p01) * tx;
    return (bottom - top) * ty + top;
}

@implementation SphereDrawView

- (void)drawRect:(NSRect)aRect
{
    [super drawRect:aRect];
}

- (void)drawGridInRect:(NSRect)aRect
{
    int step = (int)[_panelController degreesGridStep];
    float delta = 90.0f / _transfRect.size.width;
    NSBezierPath *path = [NSBezierPath bezierPath];
    BOOL visible;
    for (float latitude = (float)((-89 / step) * step); latitude < 90.0f; latitude += (float)step) {
        BOOL previous = NO;
        for (float longitude = -180.0f; longitude < 180.0f; longitude += delta) {
            NSPoint point = [self convertGeoPoint:NSMakePoint(longitude, latitude) isVisible:&visible];
            visible = visible && NSPointInRect(point, aRect);
            if (visible) {
                if (previous)
                    [path lineToPoint:point];
                else
                    [path moveToPoint:point];
            }
            previous = visible;
        }
    }
    for (float longitude = -180.0f; longitude < 180.0f; longitude += (float)step) {
        BOOL previous = NO;
        for (float latitude = -90.0f; latitude < 90.0f; latitude += delta) {
            NSPoint point = [self convertGeoPoint:NSMakePoint(longitude, latitude) isVisible:&visible];
            visible = visible && NSPointInRect(point, aRect);
            if (visible) {
                if (previous)
                    [path lineToPoint:point];
                else
                    [path moveToPoint:point];
            }
            previous = visible;
        }
    }
    [(NSColor *)[self gridColor] set];
    [path setLineWidth:0.5];
    [path stroke];
}

- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
    if (_cashedMapImage == nil)
        _cashedMapImage = [[self _projectedSphereImageForPosition:[(SphereMapController *)_panelController rotationAngles] enableClouds:aClouds enableDayNight:aNight] retain];
    NSRect source = {NSZeroPoint, [_cashedMapImage size]};
    [_cashedMapImage drawInRect:aRect fromRect:source operation:NSCompositingOperationCopy fraction:1.0];
}

- (id)_projectedSphereImageForPosition:(NSPoint)aPosition enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
    NSRect frame = [self frame];
    int side = (int)frame.size.width;
    if (frame.size.height < (float)(int)frame.size.width)
        side = (int)frame.size.height;
    int size = side * 2;
    if (size > 1024)
        size = 1024;
    NSBitmapImageRep *east = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:4096 bitsPerPixel:32] autorelease];
    NSBitmapImageRep *west = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:4096 bitsPerPixel:32] autorelease];
    NSBitmapImageRep *sphere = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size pixelsHigh:size bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:size * 4 bitsPerPixel:32] autorelease];
    MapPartsLoader *loader = [[_panelController windowController] mapPartsLoader];
    [loader fillBitmapRep:west withContentsOfFile:[MapPartsLoader pathForMapTextureForLOD:0 xPos:0 yPos:0]];
    [loader fillBitmapRep:east withContentsOfFile:[MapPartsLoader pathForMapTextureForLOD:0 xPos:1 yPos:0]];
    [self _addCloudsAndDayNightToWestImageRep:west eastImageRep:east enableClouds:aClouds enableDayNight:aNight];
    _projectSphereToFlatImage(west, east, sphere, aPosition.x, aPosition.y);
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(size, size)] autorelease];
    [image addRepresentation:sphere];
    return image;
}

- (void)_addCloudsAndDayNightToWestImageRep:(id)aRep eastImageRep:(id)aRep2 enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
    if (aRep == nil || aRep2 == nil || (!aClouds && !aNight))
        return;
    int bytesPerPixel = (int)[aRep bitsPerPixel] >> 3;
    unsigned char *west = [aRep bitmapData];
    unsigned char *east = [aRep2 bitmapData];
    if (west == NULL)
        return;
    struct WeatherGlobe_anon2 light = [[[_panelController windowController] atlasController] lightDirection];

    const unsigned char *nightWest = NULL, *nightEast = NULL;
    if (aNight) {
        NSString *maps = [[NSBundle mainBundle] pathForResource:@"Maps" ofType:@""];
        NSString *westPath = [maps stringByAppendingPathComponent:@"Night/earth_1024_west.jpo"];
        NSString *eastPath = [maps stringByAppendingPathComponent:@"Night/earth_1024_east.jpo"];
        NSBitmapImageRep *westRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:4096 bitsPerPixel:32] autorelease];
        [[[_panelController windowController] mapPartsLoader] fillBitmapRep:westRep withContentsOfFile:westPath];
        NSBitmapImageRep *eastRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:4096 bitsPerPixel:32] autorelease];
        [[[_panelController windowController] mapPartsLoader] fillBitmapRep:eastRep withContentsOfFile:eastPath];
        if (westRep == nil || eastRep == nil)
            return;
        nightWest = [westRep bitmapData];
        nightEast = [eastRep bitmapData];
        if (nightWest == NULL || nightEast == NULL)
            return;
    }

    BOOL clouds = aClouds;
    const unsigned char *cloudsWest = NULL, *cloudsEast = NULL;
    int cloudsWidth = 0, cloudsHeight = 0, cloudsBytesPerPixel = 0, cloudsBytesPerRow = 0;
    float cloudsScale = 0.0f;
    if (aClouds) {
        NSArray *reps = [[CWManager cloudsManager] currentCloudsBitmapReps];
        NSBitmapImageRep *westRep = nil, *eastRep = nil;
        if (reps != nil) {
            westRep = [reps objectAtIndex:1];
            eastRep = [reps objectAtIndex:0];
            cloudsWidth = (int)[westRep size].width;
            cloudsHeight = (int)[westRep size].height;
            cloudsScale = (float)cloudsHeight * (1.0f / 1024.0f);
            cloudsBytesPerPixel = (int)[westRep bitsPerPixel] >> 3;
            cloudsBytesPerRow = cloudsWidth * cloudsBytesPerPixel;
        }
        cloudsWest = [westRep bitmapData];
        cloudsEast = [eastRep bitmapData];
        if (cloudsWest == NULL || cloudsEast == NULL)
            clouds = NO;
    }

    float cosLongitude[1024], sinLongitude[1024];
    float lastLatitude = -10.0f, cosLatitude = 0.0f, sinLatitude = 0.0f;
    int rowOffset = 0;
    for (int y = 0; y < 1024; y++) {
        float cloudsY = cloudsScale * (float)y;
        float latitude = ((float)y * (1.0f / 1024.0f) - 0.5f) * 3.1415927f;
        int offset = rowOffset;
        for (int x = 0; x < 1024; x++) {
            float dayWest = 1.0f, dayEast = 1.0f, nightWestFactor = 0.0f, nightEastFactor = 0.0f, cloudsWestFactor = 1.0f, cloudsEastFactor = 1.0f;
            if (aNight) {
                if (y == 0) {
                    float longitude = (float)x * (1.0f / 1024.0f) * 0.5f * 6.2831855f;
                    cosLongitude[x] = cosf(longitude);
                    sinLongitude[x] = sinf(longitude);
                }
                if (latitude != lastLatitude) {
                    cosLatitude = cosf(latitude);
                    sinLatitude = sinf(latitude);
                    lastLatitude = latitude;
                }
                float c = cosLatitude * cosLongitude[x];
                float s = cosLatitude * sinLongitude[x];
                // the east half is the west half turned by 180 degrees
                float westDot = -light.f0 * c + s * -light.f1 + sinLatitude * -light.f2;
                float eastDot = (-s * -light.f1 - c * -light.f0) + sinLatitude * -light.f2;
                _dayNightFactors(westDot, &dayWest, &nightWestFactor, &cloudsWestFactor);
                _dayNightFactors(eastDot, &dayEast, &nightEastFactor, &cloudsEastFactor);
            }
            float cloudsX = cloudsScale * (float)x;
            for (int channel = 0; channel < 3; channel++) {
                unsigned char *westPixel = west + offset + channel;
                unsigned char *eastPixel = east + offset + channel;
                float westValue = *westPixel;
                float eastValue = *eastPixel;
                if (aNight) {
                    westValue = westValue * dayWest + (float)nightWest[offset + channel] * nightWestFactor;
                    eastValue = eastValue * dayEast + (float)nightEast[offset + channel] * nightEastFactor;
                }
                if (clouds) {
                    float westCloud, eastCloud;
                    if (cloudsScale >= 0.999f) {
                        westCloud = cloudsWest[offset + channel];
                        eastCloud = cloudsEast[offset + channel];
                    } else {
                        // as in the original, scaled clouds get the light factor twice
                        westCloud = _cloudSample(cloudsWest, channel, cloudsX, cloudsY, cloudsWidth, cloudsHeight, cloudsBytesPerPixel, cloudsBytesPerRow) * cloudsWestFactor;
                        eastCloud = _cloudSample(cloudsEast, channel, cloudsX, cloudsY, cloudsWidth, cloudsHeight, cloudsBytesPerPixel, cloudsBytesPerRow) * cloudsEastFactor;
                    }
                    westValue += westCloud * cloudsWestFactor;
                    eastValue += eastCloud * cloudsEastFactor;
                }
                *westPixel = westValue <= 255.0f ? (unsigned char)(int)westValue : 0xff;
                *eastPixel = eastValue <= 255.0f ? (unsigned char)(int)eastValue : 0xff;
            }
            offset += bytesPerPixel;
        }
        rowOffset += bytesPerPixel * 1024;
    }
}

- (void)invalidateCashes
{
    [_cashedMapImage release];
    _cashedMapImage = nil;
}

- (NSRect)destinationRect
{
    NSRect frame = [self frame];
    float x = NSZeroPoint.x, y = NSZeroPoint.y, side;
    if (frame.size.width <= frame.size.height) {
        y = (frame.size.height - frame.size.width) * 0.5f;
        side = frame.size.width;
    } else {
        x = (frame.size.width - frame.size.height) * 0.5f;
        side = frame.size.height;
    }
    _transfRect.size.width = side * 0.5f;
    _transfRect.size.height = side * 0.5f;
    _transfRect.origin.x = x + _transfRect.size.width;
    _transfRect.origin.y = y + side * 0.5f;
    [self _getTransformMatrix:(struct WeatherGlobe_anon3 *)&_transfMatrix];
    return NSMakeRect(x, y, side, side);
}

- (NSRect)geoRect
{
    return NSMakeRect(-180.0, -90.0, 360.0, 180.0);
}

- (CGFloat)cityRadius
{
    return 0.6f;
}

- (NSSize)convertSizeToGeoSize:(NSSize)aSize
{
    float scale = _transfRect.size.width / 90.0f;
    return NSMakeSize(aSize.width / scale, aSize.height / scale);
}

- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible
{
    vec3_normalize((SMK_GL_Vec3 *)&aPoint);
    return [self _convertEarthVec:&aPoint isVisible:aVisible];
}

- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible
{
    SMK_GL_Vec3 vec = _earthVecFromGeoPoint(aPoint);
    return [self _convertEarthVec:(struct WeatherGlobe_anon2 *)&vec isVisible:aVisible];
}

- (NSPoint)_convertEarthVec:(struct WeatherGlobe_anon2 *)aVec isVisible:(BOOL *)aVisible
{
    SMK_GL_Vec4 out;
    vec3_matrix_mul(&out, (const SMK_GL_Vec3 *)aVec, (const SMK_GL_Matrix *)&_transfMatrix);
    if (aVisible != NULL)
        *aVisible = out.x >= 0.0f;
    return NSMakePoint(out.y * _transfRect.size.width + _transfRect.origin.x, out.z * _transfRect.size.height + _transfRect.origin.y);
}

- (void)_getTransformMatrix:(struct WeatherGlobe_anon3 *)aMatrix
{
    if (aMatrix == NULL)
        return;
    NSPoint angles = NSZeroPoint;
    if ([_panelController isKindOfClass:[SphereMapController class]])
        angles = [(SphereMapController *)_panelController rotationAngles];
    SMK_GL_Matrix rotZ, rotY;
    SMK_GL_Vec3 axis = {0, 0, 1};
    rotateMatrix(&rotZ, (float)angles.x * -6.2831855f, &axis);
    axis = (SMK_GL_Vec3){0, 1, 0};
    rotateMatrix(&rotY, ((float)angles.y - 0.5f) * 3.1415927f, &axis);
    matrix_mul((SMK_GL_Matrix *)aMatrix, &rotY, &rotZ);
}

- (void)dealloc
{
    [_cashedMapImage release];
    [super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
    return [super initWithFrame:aFrame];
}

@end
