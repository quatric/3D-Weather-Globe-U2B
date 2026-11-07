#import "WeatherGlobePrefix.h"


@interface CIPaletteWindow : NSPanel
{
    NSPoint _initialLocation;
    float _titleOffset;
}
- (void)setTitleOffset:(CGFloat)aOffset;
- (void)mouseUp:(id)aUp;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (BOOL)canBecomeKeyWindow;
- (void)performClose:(id)aClose;
- (BOOL)validateMenuItem:(id)aItem;
- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer;
@end

