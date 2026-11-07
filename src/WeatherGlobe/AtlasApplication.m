#import "AtlasApplication.h"

static NSUInteger _jaguarSpecificFlags = NSEventModifierFlagControl;

@implementation AtlasApplication

+ (void)initialize
{
    if ([PantherSpecificClass currentOSVersion] < kPantherVersion)
        _jaguarSpecificFlags |= NSEventModifierFlagShift;
}

- (BOOL)validateMenuItem:(id)aItem
{
    if ([aItem action] == @selector(runPageLayout:))
        return NO;
    return [super validateMenuItem:aItem];
}

- (void)showHelp:(id)aHelp
{
    AHGotoPage((CFStringRef)@"3D Weather Globe Help", NULL, NULL);
}

- (void)sendEvent:(id)aEvent
{
    const NSUInteger mask = NSEventModifierFlagShift | NSEventModifierFlagControl
                          | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    if ([(NSEvent *)aEvent type] == NSEventTypeKeyDown) {
        NSUInteger flags = [aEvent modifierFlags] & mask;
        unsigned short keyCode = [aEvent keyCode];
        if ([[aEvent characters] isEqualToString:@"/"] && flags == NSEventModifierFlagCommand) {
            [self sendAction:@selector(showHelp:) to:nil from:nil];
            return;
        }
        if (keyCode == 0x60 && flags == _jaguarSpecificFlags
            && [self keyWindow] == [[[AtlasController atlasController] mainWindowController] mainWindow]) {
            [self sendAction:@selector(toggleToolbarFocus:) to:nil from:nil];
            return;
        }
        if (keyCode == 10 && flags == NSEventModifierFlagCommand) {
            [self sendAction:@selector(toggleRemoteControleFocus:) to:nil from:nil];
            return;
        }
        if (keyCode == 0x18 && flags == NSEventModifierFlagCommand) {
            [self sendAction:@selector(viewControlMenu:) to:nil from:_zoomInMenuItem];
            return;
        }
    }
    [super sendEvent:aEvent];
}

@end
