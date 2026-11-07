#import "WeatherGlobePrefix.h"


@interface FrameView : NSBox
{
    BOOL _drawBackground;
    NSColor *_color1;
    NSColor *_color2;
    NSColor *_color3;
    NSColor *_color4;
}
- (void)setDrawBackground:(BOOL)aBackground;
- (BOOL)drawBackground;
- (void)drawRect:(NSRect)aRect;
- (void)dealloc;
- (void)awakeFromNib;
- (id)initWithFrame:(NSRect)aFrame;
- (void)_createAllColors;
- (void)_releaseAllColors;
@end

