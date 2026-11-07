#import "WBAStartupDelegate.h"

@implementation WBAStartupDelegate

- (BOOL)application:(id)aApplication printFile:(id)aFile
{
    BOOL opened = [self application:aApplication openFile:aFile];
    if (opened)
        [[[AtlasController atlasController] mainWindowController] doPrint:nil];
    return opened;
}

- (BOOL)application:(id)aApplication openFile:(id)aFile
{
    if ([NSApp modalWindow] != nil)
        return NO;
    NSString *extension = [aFile pathExtension];
    if (![extension isEqual:kRouteSetFileExt] && ![extension isEqual:kAppleStoresSetFileExt])
        return NO;
    AtlasController *controller = [AtlasController atlasController];
    [controller showMainWindow];
    [[controller mainWindowController] openRouteDocumentAtPath:aFile reverting:NO];
    return YES;
}

@end
