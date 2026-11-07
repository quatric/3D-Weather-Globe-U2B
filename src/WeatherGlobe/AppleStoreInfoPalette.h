#import "WeatherGlobePrefix.h"


@interface AppleStoreInfoPalette : NSPanel
{
    NSPoint _initialLocation;
}
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (BOOL)acceptsFirstResponder;
- (BOOL)canBecomeKeyWindow;
- (void)performClose:(id)aClose;
- (BOOL)validateMenuItem:(id)aItem;
- (BOOL)resignFirstResponder;
- (BOOL)becomeFirstResponder;
- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer;
@end

