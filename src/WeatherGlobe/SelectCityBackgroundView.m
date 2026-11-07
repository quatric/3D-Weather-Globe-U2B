#import "SelectCityBackgroundView.h"

static SelectCityDialogController *_sSelectCityDialogController = nil;

@implementation SelectCityBackgroundView

- (void)drawRect:(NSRect)aRect
{
    NSRect contentFrame = [[[self window] contentView] frame];
    if (NSEqualSizes([_image size], contentFrame.size))
        [_image drawInRect:aRect fromRect:aRect operation:NSCompositingOperationSourceOver fraction:1.0];
}

- (void)setImage:(id)aImage
{
    if (_image != aImage) {
        [_image release];
        _image = [aImage retain];
        [self setNeedsDisplay:YES];
    }
}

@end

@implementation SelectCityWindow

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer
{
    self = [super initWithContentRect:aRect styleMask:NSWindowStyleMaskBorderless backing:aBacking defer:aDefer];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setAlphaValue:1.0];
    [self setOpaque:NO];
    [self setHasShadow:YES];
    [self setMovableByWindowBackground:YES];
    return self;
}

@end

@implementation SelectCityDialogController

+ (void)beginSheetModalForWindow:(id)aWindow modalDelegate:(id)aDelegate
{
    [[self _sharedController] _beginSheetWithDefaultCity:[self _homeCity] modalForWindow:aWindow modalDelegate:aDelegate];
}

+ (void)runModalDialog
{
    [[self _sharedController] _runModalDialogWithDefaultCity:[self _homeCity]];
}

+ (id)_homeCity
{
    return [[AtlasDatabase database] dbEntryWithUID:[Preferences homeCityUID]];
}

+ (id)_sharedController
{
    if (_sSelectCityDialogController == nil)
        _sSelectCityDialogController = [SelectCityDialogController new];
    return _sSelectCityDialogController;
}

- (void)selectAction:(id)aAction
{
    if ([self selectedItem] == nil) {
        NSBeep();
        return;
    }
    if (_dialogMode == 0)
        [NSApp stopModalWithCode:1];
    else if (_dialogMode == 1)
        [NSApp endSheet:_window returnCode:1];
}

- (void)sheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
    id city = (id)aInfo;
    if (aCode == 1)
        city = [self selectedItem];
    [_window orderOut:self];
    [Preferences setHomeCityUID:[city uid]];
    if ([_modalDelegate respondsToSelector:@selector(selectCitySheetDidEnd)])
        [_modalDelegate performSelector:@selector(selectCitySheetDidEnd)];
    _modalDelegate = nil;
}

- (void)_beginSheetWithDefaultCity:(id)aCity modalForWindow:(id)aWindow modalDelegate:(id)aDelegate
{
    [self _prepareWindowForCity:aCity];
    _dialogMode = 1;
    _modalDelegate = aDelegate;
    [NSApp beginSheet:_window modalForWindow:aWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:aCity];
}

- (void)_runModalDialogWithDefaultCity:(id)aCity
{
    [self _prepareWindowForCity:aCity];
    _dialogMode = 0;
    id city = aCity;
    if ([NSApp runModalForWindow:_window] == 1)
        city = [self selectedItem];
    [_window orderOut:self];
    [Preferences setHomeCityUID:[city uid]];
}

- (void)_prepareWindowForCity:(id)aCity
{
    if (aCity == nil) {
        aCity = [[AtlasDatabase database] dbEntryWithAddressBookCity];
        if (aCity == nil)
            aCity = [[AtlasDatabase database] dbEntryWithSystemTimeZoneCity];
    }
    [_searchString release];
    _searchString = [[aCity ownName] copy];
    [self loadNibIfNeeded];
    [_filterTextField setStringValue:_searchString];
    [_window makeFirstResponder:nil];
    [_window selectNextKeyView:nil];
}

- (void)_doubleClickAction:(id)aAction
{
    if ([[self citiesTableView] clickedRow] >= 0)
        [self selectAction:aAction];
}

- (id)nibName
{
    return @"SelectCityDialog";
}

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [_backgroundView setImage:[NSImage imageNamed:@"home_city_bg"]];
    [_window center];
    [_window setExcludedFromWindowsMenu:YES];
    [[self citiesTableView] setDoubleAction:@selector(_doubleClickAction:)];
}

@end
