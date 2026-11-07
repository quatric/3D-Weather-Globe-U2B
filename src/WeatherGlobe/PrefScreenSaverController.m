#import "PrefScreenSaverController.h"

@implementation PrefScreenSaverController

- (void)controlsAction:(id)aAction
{
    switch ([aAction tag]) {
    case 200:
        if (![[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/ScreenSaver.prefPane"])
            [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane"];
        break;
    case 300:
        [self _closeTipsSheet];
        break;
    case 100:
        [self _showTips];
        break;
    }
}

- (void)_closeTipsSheet
{
    [NSApp endSheet:_tipsSheet returnCode:1];
}

- (void)sheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
    [_tipsSheet orderOut:self];
}

- (void)_showTips
{
    if (!_tipsSet) {
        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ScreenSaverTips" ofType:@"rtf"];
        NSData *data = [[NSData alloc] initWithContentsOfFile:path];
        if (data != nil) {
            NSAttributedString *tips = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
            if (tips != nil) {
                [_tips setAttributedStringValue:tips];
                _tipsSet = YES;
                [tips release];
            }
            [data release];
        }
        if (!_tipsSet)
            return;
    }
    [NSApp beginSheet:_tipsSheet modalForWindow:[[self mainView] window] modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)viewWillBeUninstalled
{
}

- (void)viewWillBeInstalled
{
}

- (id)toolbarImage
{
    return [NSImage imageNamed:@"pref_scrsaver"];
}

- (id)toolbarLabel
{
    return [[NSBundle mainBundle] localizedStringForKey:@"ScreenSaverPrefLabel" value:@"" table:nil];
}

- (id)_nibName
{
    return @"PrefScreenSaver";
}

- (void)dealloc
{
    [_tipsSheet release];
    [super dealloc];
}

@end
