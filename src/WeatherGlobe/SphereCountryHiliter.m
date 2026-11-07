#import "SphereCountryHiliter.h"

// Country highlights on the globe: each texture is a grid of sphere cells,
// one per 4 degrees of longitude and 2 degrees of latitude.

static NSUInteger _cellsCount(CGFloat aDegrees, float aCellSize)
{
    float cells = ceilf((float)aDegrees * aCellSize);
    return cells > 0.0f ? (NSUInteger)cells : 0;
}

@implementation SphereCountryHiliter

- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect
{
    NSUInteger xCells = _cellsCount(aRect.size.width, 0.25f);
    NSUInteger yCells = _cellsCount(aRect.size.height, 0.5f);
    NSPoint origin = _radiansFromDegreesPoint(aRect.origin);
    NSSize size = _radiansFromDegreesSize(aRect.size);
    NSUInteger rowLength = xCells + 1;
    SMK_GL_Mesh *mesh = [[[SMK_GL_Mesh alloc] initWithContainer:_container fvf:0x102 usage:0x1001 verticesCount:(yCells + 1) * rowLength primitivesCount:xCells * yCells * 2 primitiveType:4] autorelease];
    [self _calculateVertexes:[mesh vertexBuffer] forGeoRectSphereSegment:NSMakeRect(origin.x, origin.y, size.width, size.height) xCells:xCells yCells:yCells];

    // two triangles per cell
    SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
    void *indices = [indexBuffer lock:2];
    BOOL wide = [indexBuffer are32BitIndices];
    NSUInteger n = 0;
    for (NSUInteger y = 0; y < yCells; y++) {
        NSUInteger row = rowLength * y, nextRow = rowLength * (y + 1);
        for (NSUInteger x = 0; x < xCells; x++) {
            NSUInteger cell[6] = {row + x, nextRow + x + 1, nextRow + x, row + x, row + x + 1, nextRow + x + 1};
            for (int i = 0; i < 6; i++, n++) {
                if (wide)
                    ((uint32_t *)indices)[n] = (uint32_t)cell[i];
                else
                    ((uint16_t *)indices)[n] = (uint16_t)cell[i];
            }
        }
    }
    [indexBuffer unlock];
    return mesh;
}

- (void)rebuildForCountryDictionaries:(id)aDictionaries scaleValue:(CGFloat)aValue flags:(NSUInteger)aFlags evaluateGlobeViewRect:(NSRect)aRect
{
    [_container beginAccumulationBlock];
    [super rebuildForCountryDictionaries:aDictionaries];
    [self disable];
    [_drawables removeAllObjects];
    // 1024 / 180: texture pixels per degree
    [self _prepareHiliteImagesWidthViewMapRectForCaption:aRect
                                      mapRectForTextures:NSMakeRect(-0.25, 0.0, 1.5, 1.0)
                                           scaleXFactor:5.688889f
                                           scaleYFactor:5.688889f
                                      scaleBorderFactor:(float)pow((float)aValue * 70.0f, 0.3)
                                                  flags:aFlags];
    [self _recalcVertexBuffers];
    [_container endAccumulationBlock];
}

- (void)_recalcVertexBuffers
{
    NSArray *drawables = [self glDrawableObjects];
    int count = (int)[drawables count];
    for (int i = 0; i < count; i++) {
        BitmapDrawable *drawable = [drawables objectAtIndex:i];
        NSAssert(drawable != nil, @"currentDrawable==nil");
        SMK_GL_Mesh *mesh = [drawable mesh];
        NSAssert(mesh != nil, @"Drawable must have mesh.");
        NSRect rect = [drawable geoRect];
        NSUInteger xCells = _cellsCount(rect.size.width, 0.25f);
        NSUInteger yCells = _cellsCount(rect.size.height, 0.5f);
        SMK_GL_VertexBuffer *buffer = [mesh vertexBuffer];
        NSPoint origin = _radiansFromDegreesPoint(rect.origin);
        NSSize size = _radiansFromDegreesSize(rect.size);
        [self _calculateVertexes:buffer forGeoRectSphereSegment:NSMakeRect(origin.x, origin.y, size.width, size.height) xCells:xCells yCells:yCells];
    }
}

// vertices of x, y, z, u, v; aSegment is in radians
- (void)_calculateVertexes:(id)aVertexes forGeoRectSphereSegment:(NSRect)aSegment xCells:(NSUInteger)aCells yCells:(NSUInteger)aCells2
{
    float *v = [(SMK_GL_VertexBuffer *)aVertexes lock:2];
    for (int y = 0; y <= (int)aCells2; y++) {
        float latitude = ((float)y / (float)aCells2) * (float)aSegment.size.height + (float)aSegment.origin.y;
        float sinLatitude = sinf(latitude);
        float cosLatitude = cosf(latitude);
        for (int x = 0; x <= (int)aCells; x++) {
            double longitude = (float)aSegment.size.width * ((float)x / (float)aCells) + (float)aSegment.origin.x;
            float sinLongitude = (float)sin(longitude);
            float cosLongitude = (float)cos(longitude);
            v[0] = cosLongitude * cosLatitude * _radius;
            v[1] = sinLongitude * cosLatitude * _radius;
            v[2] = sinLatitude * _radius;
            v[3] = (float)x / (float)aCells;
            v[4] = (float)y / (float)aCells2;
            v += 5;
        }
    }
    [(SMK_GL_VertexBuffer *)aVertexes unlock];
}

- (id)initWithContainer:(id)aContainer panelController:(id)aController captionFont:(id)aFont storagePart:(NSUInteger)aPart radius:(CGFloat)aRadius
{
    self = [super initWithContainer:aContainer panelController:aController captionFont:aFont storagePart:aPart];
    if (self != nil)
        _radius = (float)aRadius;
    return self;
}

@end
