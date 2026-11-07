#import "PreferencesController.h"

// wide enough for all six panes' toolbar items with the current toolbar metrics
static const CGFloat kMinPreferencesWidth = 480.0;

// the panes were laid out for a narrower window
static void _centerPaneView(NSView *aView, NSWindow *aWindow)
{
    NSRect frame = [aView frame];
    frame.origin.x = floor(([[aWindow contentView] frame].size.width - frame.size.width) / 2.0);
    [aView setFrameOrigin:frame.origin];
}

@implementation PreferencesController

- (id)toolbar:(id)aToolbar itemForItemIdentifier:(id)aIdentifier willBeInsertedIntoToolbar:(BOOL)aToolbar2
{
    PrefGenericController *controller = [self _prefControllerForKey:aIdentifier];
    PreferencesToolbarItem *item = [[[PreferencesToolbarItem alloc] initWithItemIdentifier:aIdentifier] autorelease];
    [item setLabel:[controller toolbarLabel]];
    [item setImage:[controller toolbarImage]];
    [item setTarget:self];
    [item setAction:@selector(_toolbarItemAction:)];
    return item;
}

- (id)toolbarSelectableItemIdentifiers:(id)aIdentifiers
{
    return [self _identifiers];
}

- (id)toolbarAllowedItemIdentifiers:(id)aIdentifiers
{
    return [self _identifiers];
}

- (id)toolbarDefaultItemIdentifiers:(id)aIdentifiers
{
    return [self _identifiers];
}

- (void)showWeatherPane
{
    [self _showPreferencesWithIdentifier:@"PrefCloudsController"];
}

- (void)showSelectCityDialog
{
    [self _showPreferencesWithIdentifier:@"PrefMyLocationController"];
    [[self _prefControllerForKey:@"PrefMyLocationController"] primaryAction];
}

- (void)showPreferences
{
    [self _loadNibIfNeeded];
    [_mainWindow makeKeyAndOrderFront:self];
}

- (void)_showPreferencesWithIdentifier:(id)aIdentifier
{
    NSUInteger index = [[self _identifiers] indexOfObject:aIdentifier];
    if (index == NSNotFound)
        return;
    [self _loadNibIfNeeded];
    [_mainWindow makeKeyAndOrderFront:self];
    [_toolbar setSelectedItemIdentifier:aIdentifier];
    [self _toolbarItemAction:[[_toolbar items] objectAtIndex:index]];
}

- (void)_toolbarItemAction:(id)aAction
{
    PrefGenericController *controller = [self _prefControllerForKey:[aAction itemIdentifier]];
    if (controller == _currentController)
        return;
    NSView *newView = [controller mainView];
    NSView *oldView = [_currentController mainView];
    [_currentController viewWillBeUninstalled];
    [oldView removeFromSuperview];
    NSRect windowFrame = [_mainWindow frame];
    NSRect oldFrame = [oldView frame];
    NSRect newFrame = [newView frame];
    CGFloat height = windowFrame.size.height - oldFrame.size.height + newFrame.size.height;
    windowFrame.origin.y = windowFrame.origin.y + windowFrame.size.height - height;
    windowFrame.size.height = height;
    [_mainWindow setFrame:windowFrame display:YES animate:YES];
    [controller viewWillBeInstalled];
    _centerPaneView(newView, _mainWindow);
    [[_mainWindow contentView] addSubview:newView];
    _currentController = controller;
    [_toolbar setSelectedItemIdentifier:[aAction itemIdentifier]];
    [_mainWindow makeFirstResponder:newView];
}

- (void)_loadNibIfNeeded
{
    if (_mainWindow == nil)
        [NSBundle loadNibNamed:@"Preferences" owner:self];
}

- (void)dealloc
{
    [_mainWindow release];
    [_toolbar release];
    [_identifiers release];
    [_prefControllers release];
    [super dealloc];
}

- (void)awakeFromNib
{
    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"com.mackiev.3dweatherglobe.preferences.toolbar"];
    [_toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
    [_toolbar setAllowsUserCustomization:NO];
    [_toolbar setDelegate:(id)self];
    if ([[self _identifiers] count] == 0)
        return;
    NSString *identifier = [_identifiers objectAtIndex:0];
    PrefGenericController *controller = [self _prefControllerForKey:identifier];
    NSView *view = [controller mainView];
    NSRect contentFrame = [[_mainWindow contentView] frame];
    NSRect viewFrame = [view frame];
    [_mainWindow setContentSize:NSMakeSize(MAX(contentFrame.size.width, kMinPreferencesWidth), viewFrame.size.height)];
    [controller viewWillBeInstalled];
    _centerPaneView(view, _mainWindow);
    [[_mainWindow contentView] addSubview:view];
    _currentController = controller;
    [_toolbar setSelectedItemIdentifier:identifier];
    [_mainWindow makeFirstResponder:view];
    NSString *appName = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleName"];
    NSString *format = [[NSBundle mainBundle] localizedStringForKey:@"PreferencesWindowTitle" value:@"" table:nil];
    [_mainWindow setTitle:[NSString stringWithFormat:format, appName]];
    // macOS 11 puts the title and toolbar on one line, which leaves this
    // narrow window room for one pane; the preference style centers them
    [_mainWindow setToolbarStyle:NSWindowToolbarStylePreference];
    [_mainWindow setToolbar:_toolbar];
    [_mainWindow center];
}

- (id)_prefControllerForKey:(id)aKey
{
    if (![[self _identifiers] containsObject:aKey])
        return nil;
    if (_prefControllers == nil)
        _prefControllers = [[NSMutableDictionary alloc] init];
    id controller = [_prefControllers objectForKey:aKey];
    if (controller == nil) {
        controller = [[[NSClassFromString(aKey) alloc] init] autorelease];
        [_prefControllers setObject:controller forKey:aKey];
    }
    return controller;
}

- (id)_identifiers
{
    if (_identifiers == nil)
        _identifiers = [[NSArray alloc] initWithObjects:@"PrefGeneralController", @"PrefApearanceController", @"PrefCloudsController", @"PrefMyLocationController", @"PrefOnlineController", @"PrefScreenSaverController", nil];
    return _identifiers;
}

@end

@implementation PreferencesToolbarItem

- (void)validate
{
    [self setEnabled:YES];
}

@end
