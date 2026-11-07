#import "CountryHiliter.h"

// Highlights countries by painting their outlines into 256x256 textures
// laid over the map; a subclass supplies the mesh for each texture.

// path drawing mode: flag 1 strokes, flag 2 fills, both or neither do both
static CGPathDrawingMode _drawingMode(NSUInteger aFlags)
{
    if ((aFlags & 2) && !(aFlags & 1))
        return kCGPathEOFill;
    if (!(aFlags & 2) && (aFlags & 1))
        return kCGPathStroke;
    return kCGPathEOFillStroke;
}

static void _getRGBA(NSColor *aColor, CGFloat *aComponents)
{
    [[aColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] getRed:&aComponents[0] green:&aComponents[1] blue:&aComponents[2] alpha:&aComponents[3]];
}

@implementation CountryHiliter

- (id)countryDictionaries
{
    return _countryDictionaries;
}

- (NSRect)actualGeoRect
{
    return _actualGeoRect;
}

- (id)captionGeoRects
{
    return _captionGeoRects;
}

- (id)captionFont
{
    return _captionFont;
}

- (BOOL)isDisabled
{
    return _partsCounter == 0;
}

- (id)glDrawableObjects
{
    return [_drawables subarrayWithRange:NSMakeRange(0, _partsCounter)];
}

- (void)disable
{
    _partsCounter = 0;
}

- (void)rebuildForCountryDictionaries:(id)aDictionaries
{
    if (_countryDictionaries != nil && [_countryDictionaries isEqual:aDictionaries])
        return;
    [aDictionaries retain];
    [_countryDictionaries release];
    _countryDictionaries = aDictionaries;
    [self _recalcCaptionSizes];
}

- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect
{
    NSAssert(NO, @"'CountryHiliter' not responds to 'createMeshCountryHilite:' meessage!");
    return nil;
}

- (void)dealloc
{
    [_drawables release];
    [_captionFont release];
    [_countryDictionaries release];
    [_captionSizes release];
    [_captionGeoRects release];
    [_stringAttributes release];
    [super dealloc];
}

- (id)initWithContainer:(id)aContainer panelController:(id)aController captionFont:(id)aFont storagePart:(NSUInteger)aPart
{
    self = [super init];
    if (self != nil) {
        _drawables = [[NSMutableArray alloc] initWithCapacity:16];
        _container = aContainer;
        _panelController = aController;
        _partsCounter = 0;
        _captionFont = [aFont retain];
        _storagePart = (unsigned int)aPart;
        _countryDictionaries = nil;
        _captionSizes = [[NSMutableArray alloc] initWithCapacity:4];
        _captionGeoRects = [[NSMutableArray alloc] initWithCapacity:4];
        _stringAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:_captionFont, NSFontAttributeName, nil];
    }
    return self;
}

@end

@implementation BitmapDrawable

+ (id)bitmapDrawableWithMesh:(id)aMesh texture:(id)aTexture imageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect container:(id)aContainer
{
    return [[[self alloc] initWithMesh:aMesh texture:aTexture imageWidth:aWidth imageHeight:aHeight geoRect:aRect container:aContainer] autorelease];
}

- (id)texture
{
    return _texture;
}

// the texture matrix maps the mesh onto the used corner of the texture
static void _setTextureMatrix(SMK_GL_2DTexture *aTexture, NSInteger aWidth, NSInteger aHeight)
{
    SMK_GL_Matrix matrix;
    matrix_make_identity(&matrix);
    matrix._11 = (float)aWidth * 0.00390625f;
    matrix._22 = (float)aHeight * -0.00390625f;
    matrix._24 = 1.0f;
    [aTexture setTransformMatrix:&matrix];
}

- (void)setNewValuesWithImageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect
{
    _imageWidth = (int)aWidth;
    _imageHeight = (int)aHeight;
    SMK_GL_Material *material = [(SMK_GL_Mesh *)[self mesh] material];
    _setTextureMatrix(_texture, aWidth, aHeight);
    [material setTexture:_texture atStage:0];
    _geoRect = aRect;
}

- (NSRect)geoRect
{
    return _geoRect;
}

- (NSInteger)imageHeight
{
    return _imageHeight;
}

- (NSInteger)imageWidth
{
    return _imageWidth;
}

- (void)dealloc
{
    [super dealloc];
}

- (id)initWithMesh:(id)aMesh texture:(id)aTexture imageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect container:(id)aContainer
{
    self = [super initWithMesh:aMesh];
    if (self != nil) {
        _texture = aTexture;
        SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:aContainer] autorelease];
        SMK_GL_Color white = {1.0f, 1.0f, 1.0f, 1.0f};
        [material setAmbient:white];
        [material setDiffuse:white];
        _setTextureMatrix(_texture, aWidth, aHeight);
        [material setTexture:_texture atStage:0];
        [(SMK_GL_Mesh *)aMesh setMaterial:material];
        _imageWidth = (int)aWidth;
        _imageHeight = (int)aHeight;
        _geoRect = aRect;
    }
    return self;
}

@end

@implementation NSMutableDictionary (WBAtlasCountryHighlight)

- (void)addCaptionColor:(id)aColor
{
    if (aColor != nil)
        [self setObject:aColor forKey:kCountryHighlightCaptionColorKey];
}

- (void)addBorderColor:(id)aColor
{
    [self setObject:aColor forKey:kCountryHighlightBorderColorKey];
}

- (void)addFillColor:(id)aColor
{
    [self setObject:aColor forKey:kCountryHighlightFillColorKey];
}

@end

@implementation NSDictionary (WBAtlasCountryHighlight)

- (id)captionColor
{
    return [self objectForKey:kCountryHighlightCaptionColorKey];
}

- (id)borderColor
{
    return [self objectForKey:kCountryHighlightBorderColorKey];
}

- (id)fillColor
{
    return [self objectForKey:kCountryHighlightFillColorKey];
}

@end

@implementation CountryHiliter (Protected)

// Places the captions and repaints the textures covering the highlighted
// shapes within aTextures (map units), at the given pixels per degree.
- (void)_prepareHiliteImagesWidthViewMapRectForCaption:(NSRect)aCaption mapRectForTextures:(NSRect)aTextures scaleXFactor:(CGFloat)aFactor scaleYFactor:(CGFloat)aFactor2 scaleBorderFactor:(CGFloat)aFactor3 flags:(NSUInteger)aFlags
{
    NSUInteger count = [_countryDictionaries count];
    if (count == 0)
        return;
    float scaleX = aFactor, scaleY = aFactor2;
    NSRect captionGeoRect = _geoRectFromMapRect(aCaption);
    NSRect texturesGeoRect = NSMakeRect((aTextures.origin.x - 0.5) * 360.0, (aTextures.origin.y - 0.5) * 180.0, aTextures.size.width * 360.0, aTextures.size.height * 180.0);
    _actualGeoRect = NSZeroRect;
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *fillColors = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *borderColors = [NSMutableArray arrayWithCapacity:count];
    [_captionGeoRects removeAllObjects];
    for (NSUInteger i = 0; i < count; i++) {
        NSDictionary *country = [_countryDictionaries objectAtIndex:i];
        NSSize captionSize = [[_captionSizes objectAtIndex:i] sizeValue];
        NSRect actual;
        NSRect caption = _captionGeoRect(captionGeoRect, texturesGeoRect, country, captionSize.width / scaleX, captionSize.height / scaleY, &actual);
        [_captionGeoRects addObject:[NSValue valueWithRect:caption]];
        _actualGeoRect = i == 0 ? actual : NSUnionRect(_actualGeoRect, actual);
        [paths addObject:[(id)country drawedBorderPaths]];
        [fillColors addObject:[country fillColor]];
        [borderColors addObject:[country borderColor]];
    }
    _partsCounter = 0;
    if (texturesGeoRect.size.width * 3.0 < _actualGeoRect.size.width) {
        _actualGeoRect.origin.x = texturesGeoRect.origin.x;
        _actualGeoRect.size.width = texturesGeoRect.size.width;
    }
    float width = _actualGeoRect.size.width, height = _actualGeoRect.size.height;
    _actualGeoRect = NSInsetRect(_actualGeoRect, -4.0f / scaleX, -4.0f / scaleY);

    // split the image into 256 pixel square textures
    int pixelsWide = (int)(scaleX * width + 8.0f);
    int pixelsHigh = (int)(scaleY * height + 8.0f);
    int lastWidth = pixelsWide % 256, lastHeight = pixelsHigh % 256;
    int columns = pixelsWide / 256 + (lastWidth > 0);
    int rows = pixelsHigh / 256 + (lastHeight > 0);
    if (lastWidth == 0)
        lastWidth = 256;
    if (lastHeight == 0)
        lastHeight = 256;
    CountryHiliterTexturesStorage *storage = [CountryHiliterTexturesStorage sharedStorage];
    for (int column = 0; column < columns; column++) {
        int imageWidth = column == columns - 1 ? lastWidth : 256;
        for (int row = 0; row < rows; row++) {
            int imageHeight = row == rows - 1 ? lastHeight : 256;
            NSRect geoRect = NSMakeRect((float)(column * 256) / scaleX + _actualGeoRect.origin.x, (float)(row * 256) / scaleY + _actualGeoRect.origin.y, (float)imageWidth / scaleX, (float)imageHeight / scaleY);
            BitmapDrawable *drawable;
            if ((NSUInteger)_partsCounter < [_drawables count]) {
                drawable = [_drawables objectAtIndex:_partsCounter];
                [drawable setNewValuesWithImageWidth:imageWidth imageHeight:imageHeight geoRect:geoRect];
            } else {
                [_container beginAccumulationBlock];
                id texture = [storage getTextureWithIndex:_partsCounter storagePart:_storagePart];
                id mesh = [self createMeshCountryHiliteForGeoRect:geoRect];
                drawable = [BitmapDrawable bitmapDrawableWithMesh:mesh texture:texture imageWidth:imageWidth imageHeight:imageHeight geoRect:geoRect container:_container];
                [_drawables addObject:drawable];
                [_container endAccumulationBlock];
            }
            CGContextRef context = [(SMK_GL_2DTexture *)[drawable texture] lockAndCreateCGContextWithClear:YES];
            if (aFlags != 0) {
                CGContextSetInterpolationQuality(context, kCGInterpolationDefault);
                CGContextSetLineJoin(context, kCGLineJoinRound);
                CGContextSetLineWidth(context, 2.0f / (float)aFactor3);
                CGAffineTransform geoToPixels = CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformIdentity, scaleX, scaleY), -_actualGeoRect.origin.x, -_actualGeoRect.origin.y);
                CGAffineTransform toTile = CGAffineTransformTranslate(CGAffineTransformIdentity, column * -256, row * -256);
                CGContextConcatCTM(context, toTile);
                CGContextConcatCTM(context, geoToPixels);
                for (NSUInteger i = 0; i < count; i++) {
                    CGFloat components[4];
                    _getRGBA([fillColors objectAtIndex:i], components);
                    CGContextSetRGBFillColor(context, components[0], components[1], components[2], components[3]);
                    _getRGBA([borderColors objectAtIndex:i], components);
                    CGContextSetRGBStrokeColor(context, components[0], components[1], components[2], components[3]);
                    for (NSBezierPath *path in [paths objectAtIndex:i]) {
                        NSRect bounds = [path bounds];
                        // a shape may show a turn east or west of its coordinates
                        if (NSIntersectsRect(bounds, geoRect))
                            [self _drawBezierPathInCGContex:context bezierPath:path flags:aFlags offset:NSZeroPoint];
                        else if (NSIntersectsRect(NSOffsetRect(bounds, -360.0, 0.0), geoRect))
                            [self _drawBezierPathInCGContex:context bezierPath:path flags:aFlags offset:NSMakePoint(-360.0, 0.0)];
                        else if (NSIntersectsRect(NSOffsetRect(bounds, 360.0, 0.0), geoRect))
                            [self _drawBezierPathInCGContex:context bezierPath:path flags:aFlags offset:NSMakePoint(360.0, 0.0)];
                    }
                }
            }
            [(SMK_GL_2DTexture *)[drawable texture] unlock];
            _partsCounter++;
        }
    }
}

@end

@implementation CountryHiliter (Private)

- (void)_recalcCaptionSizes
{
    NSUInteger count = [_countryDictionaries count];
    [_captionSizes removeAllObjects];
    for (NSUInteger i = 0; i < count; i++) {
        NSSize size = [[[_countryDictionaries objectAtIndex:i] fullShapeName] sizeWithAttributes:_stringAttributes];
        [_captionSizes addObject:[NSValue valueWithSize:size]];
    }
}

// each closed subpath is drawn as soon as it is complete
- (void)_drawBezierPathInCGContex:(struct CGContext *)aContex bezierPath:(id)aPath flags:(NSUInteger)aFlags offset:(NSPoint)aOffset
{
    NSInteger count = [aPath elementCount];
    CGContextBeginPath(aContex);
    for (NSInteger i = 0; i < count; i++) {
        NSPoint points[3];
        switch ([aPath elementAtIndex:i associatedPoints:points]) {
        case NSBezierPathElementMoveTo:
            CGContextMoveToPoint(aContex, aOffset.x + points[0].x, aOffset.y + points[0].y);
            break;
        case NSBezierPathElementLineTo:
            CGContextAddLineToPoint(aContex, aOffset.x + points[0].x, aOffset.y + points[0].y);
            break;
        case NSBezierPathElementCurveTo:
            CGContextAddCurveToPoint(aContex, aOffset.x + points[0].x, aOffset.y + points[0].y, aOffset.x + points[1].x, aOffset.y + points[1].y, aOffset.x + points[2].x, aOffset.y + points[2].y);
            break;
        case NSBezierPathElementClosePath:
            CGContextClosePath(aContex);
            CGContextDrawPath(aContex, _drawingMode(aFlags));
            CGContextBeginPath(aContex);
            break;
        default:
            break;
        }
    }
    CGContextClosePath(aContex);
    CGContextDrawPath(aContex, _drawingMode(aFlags));
}

@end
