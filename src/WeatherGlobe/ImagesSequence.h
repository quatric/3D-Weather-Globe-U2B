#import "WeatherGlobePrefix.h"


@interface ImagesSequence : NSObject
{
    NSArray *_iconsTextures;
    int _numIconsPerBitmap;
    int _numAnimationSteps;
    int _numIcons;
    int _iconSize;
    NSMutableDictionary *_cachedIcons;
}
- (id)imagesForIconAtIndex:(NSInteger)aIndex;
- (id)_createImageForIconAtIndex:(NSInteger)aIndex animationStep:(NSInteger)aStep;
- (void)dealloc;
- (id)initWithFileNamePrefix:(id)aPrefix fileExtension:(id)aExtension iconSize:(NSInteger)aSize;
@end

