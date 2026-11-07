#import "FlatMapCountryHiliter.h"

// Country highlights on the flat map: each texture is a quad covering its
// geo rect in map coordinates.

@implementation FlatMapCountryHiliter

- (void)rebuildForCountryDictionaries:(id)aDictionaries mapXPosition:(CGFloat)aPosition mapYPosition:(CGFloat)aPosition2 scaleValue:(CGFloat)aValue flags:(NSUInteger)aFlags
{
    [_container beginAccumulationBlock];
    [super rebuildForCountryDictionaries:aDictionaries];
    float height = 1.0f / (float)aValue;
    NSSize size = [[_container context] size];
    float width = ((float)size.width * height) / (float)size.height;
    float halfWidth = width * 0.5f;
    float y = (float)((1.0f - (float)aPosition2) + height * -0.5);
    float x = (float)((float)aPosition + width * -0.25);
    float borderFactor = ((float)aValue * (float)size.height) / 180.0f;
    [self disable];
    // when the view shows more than the whole map, textures cover all of it
    float texturesX = x, texturesWidth = halfWidth;
    if (halfWidth > 1.0f) {
        texturesX = -0.5f;
        texturesWidth = 2.0f;
    }
    [self _prepareHiliteImagesWidthViewMapRectForCaption:NSMakeRect(x, y, halfWidth, height)
                                      mapRectForTextures:NSMakeRect(texturesX, y, texturesWidth, height)
                                           scaleXFactor:borderFactor
                                           scaleYFactor:borderFactor
                                      scaleBorderFactor:borderFactor
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
        SMK_GL_Mesh *mesh = [drawable mesh];
        NSRect rect = _mapRectFromGeoRect([drawable geoRect]);
        SMK_GL_VertexBuffer *buffer = [mesh vertexBuffer];
        // 4 vertices of x, y, z, u, v
        float *v = [buffer lock:0];
        float left = (float)rect.origin.x, right = (float)(rect.origin.x + rect.size.width);
        float top = 1.0f - (float)rect.origin.y, bottom = 1.0f - (float)(rect.origin.y + rect.size.height);
        v[0] = left;   v[1] = top;     v[2] = 0.0f;
        v[5] = right;  v[6] = top;     v[7] = 0.0f;
        v[10] = left;  v[11] = bottom; v[12] = 0.0f;
        v[15] = right; v[16] = bottom; v[17] = 0.0f;
        [buffer unlock];
    }
}

- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect
{
    return [SMK_GL_Mesh createXYPlaneWithRect:NSZeroRect xSegments:1 ySegments:1 container:_container fvf:0x102 usage:1];
}

@end
