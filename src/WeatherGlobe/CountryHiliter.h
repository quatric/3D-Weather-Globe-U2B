#import "WeatherGlobePrefix.h"


@interface CountryHiliter : NSObject
{
    NSMutableArray *_drawables;
    int _partsCounter;
    unsigned int _storagePart;
    SMK_GL_ObjectsContainer *_container;
    AtlasPanelController *_panelController;
    NSArray *_countryDictionaries;
    NSFont *_captionFont;
    NSDictionary *_stringAttributes;
    NSMutableArray *_captionSizes;
    NSMutableArray *_captionGeoRects;
    NSRect _actualGeoRect;
}
- (id)countryDictionaries;
- (NSRect)actualGeoRect;
- (id)captionGeoRects;
- (id)captionFont;
- (BOOL)isDisabled;
- (id)glDrawableObjects;
- (void)disable;
- (void)rebuildForCountryDictionaries:(id)aDictionaries;
- (id)createMeshCountryHiliteForGeoRect:(NSRect)aRect;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer panelController:(id)aController captionFont:(id)aFont storagePart:(NSUInteger)aPart;
@end

@interface BitmapDrawable : SMK_GL_Drawable
{
    NSRect _geoRect;
    int _imageWidth;
    int _imageHeight;
    SMK_GL_2DTexture *_texture;
}
+ (id)bitmapDrawableWithMesh:(id)aMesh texture:(id)aTexture imageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect container:(id)aContainer;
- (id)texture;
- (void)setNewValuesWithImageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect;
- (NSRect)geoRect;
- (NSInteger)imageHeight;
- (NSInteger)imageWidth;
- (void)dealloc;
- (id)initWithMesh:(id)aMesh texture:(id)aTexture imageWidth:(NSInteger)aWidth imageHeight:(NSInteger)aHeight geoRect:(NSRect)aRect container:(id)aContainer;
@end

@interface NSMutableDictionary (WBAtlasCountryHighlight)
- (void)addCaptionColor:(id)aColor;
- (void)addBorderColor:(id)aColor;
- (void)addFillColor:(id)aColor;
@end

@interface NSDictionary (WBAtlasCountryHighlight)
- (id)captionColor;
- (id)borderColor;
- (id)fillColor;
@end

@interface CountryHiliter (Protected)
- (void)_prepareHiliteImagesWidthViewMapRectForCaption:(NSRect)aCaption mapRectForTextures:(NSRect)aTextures scaleXFactor:(CGFloat)aFactor scaleYFactor:(CGFloat)aFactor2 scaleBorderFactor:(CGFloat)aFactor3 flags:(NSUInteger)aFlags;
@end

@interface CountryHiliter (Private)
- (void)_recalcCaptionSizes;
- (void)_drawBezierPathInCGContex:(struct CGContext *)aContex bezierPath:(id)aPath flags:(NSUInteger)aFlags offset:(NSPoint)aOffset;
@end

