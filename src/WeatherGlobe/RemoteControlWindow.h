#import "WeatherGlobePrefix.h"


@interface RemoteControlWindow : NSPanel
{
    NSWindow *_parentWindow;
}
- (void)performZoom:(id)aZoom;
- (void)performMiniaturize:(id)aMiniaturize;
- (void)performClose:(id)aClose;
- (BOOL)validateMenuItem:(id)aItem;
- (BOOL)canBecomeKeyWindow;
- (void)keyDown:(id)aDown;
- (id)initWithParentWindow:(id)aWindow;
- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer;
@end

