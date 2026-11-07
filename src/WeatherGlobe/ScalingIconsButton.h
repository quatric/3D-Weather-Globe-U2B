#import "WeatherGlobePrefix.h"


@interface ScalingIconsButton : NSButton
{
    float _lastWidth;
    BOOL _needRefreshIcon;
    BOOL _needRefreshAltIcon;
    NSMutableDictionary *_iconImages;
    NSMutableDictionary *_altIconImages;
}
- (void)drawRect:(NSRect)aRect;
- (void)setAlternateImage:(id)aImage toPosition:(NSInteger)aPosition;
- (void)setImage:(id)aImage toPosition:(NSInteger)aPosition;
- (void)_refreshIcons;
- (id)_imageFromImages:(id)aImages;
- (BOOL)_setImage:(id)aImage toPosition:(NSInteger)aPosition intoIconImages:(id)aImages;
- (void)dealloc;
@end

