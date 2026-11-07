#import "ImagesSequence.h"

@implementation ImagesSequence

- (id)imagesForIconAtIndex:(NSInteger)aIndex
{
    if (_iconsTextures == nil)
        return nil;
    if (aIndex < 1 || aIndex > _numIcons)
        aIndex = _numIcons;
    NSString *key = [NSString stringWithFormat:@"%d", (int)aIndex];
    NSMutableArray *images = [_cachedIcons objectForKey:key];
    if (images == nil) {
        if (_cachedIcons == nil)
            _cachedIcons = [NSMutableDictionary new];
        images = [NSMutableArray array];
        [_cachedIcons setObject:images forKey:key];
        int step;
        for (step = 0; step < _numAnimationSteps; step++)
            [images addObject:[self _createImageForIconAtIndex:aIndex - 1 animationStep:step]];
    }
    return images;
}

- (id)_createImageForIconAtIndex:(NSInteger)aIndex animationStep:(NSInteger)aStep
{
    NSBitmapImageRep *source = [_iconsTextures objectAtIndex:aIndex / _numIconsPerBitmap];
    NSInteger bitsPerPixel = [source bitsPerPixel];
    NSInteger samplesPerPixel = [source samplesPerPixel];
    NSInteger sourceRowBytes = [source bytesPerRow];
    size_t rowBytes = (bitsPerPixel >> 3) * _iconSize;
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:_iconSize pixelsHigh:_iconSize bitsPerSample:[source bitsPerSample]
        samplesPerPixel:samplesPerPixel hasAlpha:[source hasAlpha] isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:rowBytes bitsPerPixel:bitsPerPixel] autorelease];
    const unsigned char *from = [source bitmapData]
        + _iconSize * sourceRowBytes * aStep
        + rowBytes * (aIndex % _numIconsPerBitmap);
    unsigned char *to = [rep bitmapData];
    int row;
    for (row = 0; row < _iconSize; row++) {
        memcpy(to, from, rowBytes);
        to += rowBytes;
        from += sourceRowBytes;
    }
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(_iconSize, _iconSize)] autorelease];
    [image addRepresentation:rep];
    [image lockFocus];
    [image unlockFocus];
    return image;
}

- (void)dealloc
{
    [_cachedIcons release];
    [_iconsTextures release];
    [super dealloc];
}

- (id)initWithFileNamePrefix:(id)aPrefix fileExtension:(id)aExtension iconSize:(NSInteger)aSize
{
    self = [super init];
    if (self != nil) {
        _iconSize = (int)aSize;
        _numIcons = 0;
        _numIconsPerBitmap = 0;
        _numAnimationSteps = 0;
        NSMutableArray *textures = [NSMutableArray array];
        int index = 0;
        NSString *path;
        while ((path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"%@%d", aPrefix, index]
                                                       ofType:aExtension]) != nil) {
            index++;
            NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithData:[NSData dataWithContentsOfFile:path]] autorelease];
            if (rep == nil)
                continue;
            [textures addObject:rep];
            if (_numIconsPerBitmap == 0)
                _numIconsPerBitmap = (int)([rep pixelsWide] / _iconSize);
            if (_numAnimationSteps == 0)
                _numAnimationSteps = (int)([rep pixelsHigh] / _iconSize);
            _numIcons += (int)([rep pixelsWide] / _iconSize);
        }
        _iconsTextures = [[NSArray alloc] initWithArray:textures];
    }
    return self;
}

@end
