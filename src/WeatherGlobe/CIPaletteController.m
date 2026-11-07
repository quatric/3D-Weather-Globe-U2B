#import "CIPaletteController.h"

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil];
}

@implementation CIPaletteController

- (void)runPageLayout:(id)aLayout
{
	[[NSPageLayout pageLayout] runModal];
}

- (void)doPrint:(id)aPrint
{
	NSInteger count = [_cityInfoControllers count];
	NSMutableArray *cities = [NSMutableArray arrayWithCapacity:count];
	for (NSInteger i = 0; i < count; i++)
		[cities addObject:[[_cityInfoControllers objectAtIndex:i] cityEntry]];
	[WeatherPrintController printCities:cities];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_timeTick invalidate];
	[_citiesIndexes release];
	[_cityInfoControllers release];
	[_paletteMenu release];
	[_citiesListController release];
	[_citiesPalette release];
	[_separatorViews release];
	[_verticalSeparatorImage release];
	[super dealloc];
}

- (void)awakeFromNib
{
	_verticalSeparatorImage = [[NSImage imageNamed:@"city_info_separartor"] retain];
	_separatorViews = [NSMutableArray new];
	[_citiesPaletteTitleView setMenu:_paletteMenu];
	[_citiesPaletteView setMenu:_paletteMenu];
	NSSize size = [_citiesPaletteTitleView sizeForBestFit];
	[_citiesPalette setTitleOffset:[_citiesPaletteTitleView isVertical] ? size.width : size.height];
	_minContentSize.height = size.height;
	_minContentSize.width = size.width;
	[self _setCitiesFromPreferences];
	[self _reconstructPalette];
	[self _resizePalette];
	[_citiesPalette center];
	[_citiesPalette setFrameAutosaveName:@"Cities Info Palette"];
	[self _constrainKeyViewsChain];
}

- (id)init
{
	self = [super init];
	if (self == nil)
		return nil;
	_citiesPalette = [CIPaletteWindow new];
	_citiesListController = [CICitiesListController new];
	[_citiesListController setDelegate:self];
	_cityInfoControllers = [NSMutableArray new];
	_citiesIndexes = [NSMutableArray new];
	[self _createMenu];
	[self _createTitleView];
	_citiesPaletteView = [[[CIPaletteView alloc] initWithController:self] autorelease];
	[_citiesPaletteView addSubview:_citiesPaletteTitleView];
	[_citiesPalette setDelegate:(id)self];
	[_citiesPalette setContentView:_citiesPaletteView];
	[_paletteMenu setDelegate:(id)self];
	_timeTick = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(_timeTick:) userInfo:nil repeats:YES];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_acceptNeedReconstruct:) name:@"NeedReconstructNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptAddCities:) name:@"AddCitiesNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptResetCities:) name:@"ResetCitiesNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptDraggingEntered:) name:@"DraggingEnteredNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptDraggingUpdated:) name:@"DraggingUpdatedNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptDraggingExited:) name:@"DraggingExitedNotification" object:nil];
	[center addObserver:self selector:@selector(_acceptDraggingRemoveCity:) name:@"DraggingRemoveCityNotification" object:nil];
	[center addObserver:self selector:@selector(_transparencyLevelWasChanged:) name:kCITransparencyLevelWasChanged object:nil];
	return self;
}

// the cities list's marker column adds or removes a city; returns whether
// the palette changed
- (BOOL)markerColumnAction:(id)aAction forCity:(id)aCity
{
	NSArray *cities = [NSArray arrayWithObject:[aCity entryDictionary]];
	if ([aAction intValue] == 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ResetCitiesNotification" object:cities userInfo:nil];
		return YES;
	}
	NSUInteger count = [_cityInfoControllers count];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddCitiesNotification" object:cities userInfo:nil];
	return [_cityInfoControllers count] != count;
}

- (BOOL)cityIsMarked:(id)aMarked
{
	return [_citiesIndexes containsObject:[aMarked uid]];
}

- (BOOL)dragIsSupportedForController:(id)aController
{
	return YES;
}

- (void)menuDidClose:(id)aClose
{
	NSArray *components = [_citiesPaletteTitleView viewComponents];
	NSInteger count = [components count];
	for (NSInteger i = 0; i < count; i++) {
		id component = [components objectAtIndex:i];
		[component setState:0];
		[component setNeedsDisplay:YES];
	}
	[_citiesPalette becomeFirstResponder];
}

- (void)windowDidBecomeKey:(id)aKey
{
	[[CityInfoView selectedView] setNeedsDisplay:YES];
}

- (void)windowDidResignKey:(id)aKey
{
	[[CityInfoView selectedView] setNeedsDisplay:YES];
}

- (void)windowDidResize:(id)aResize
{
	NSSize size = [_citiesPaletteTitleView sizeForBestFit];
	NSRect frame = [_citiesPalette frame];
	// the title bar runs along the long side of the window
	if (![_citiesPaletteTitleView isVertical])
		size.width = frame.size.width;
	else
		size.height = frame.size.height;
	[_citiesPaletteTitleView setFrameSize:size];
}

- (BOOL)windowShouldClose:(id)aClose
{
	[_citiesListController hideWindow];
	[Preferences setShowWeatherOnStartup:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NeedStopAnimationsNotification" object:self userInfo:nil];
	return YES;
}

- (void)_selectCityAtIndex:(NSInteger)aIndex
{
	[CityInfoView setSelectedView:[[_cityInfoControllers objectAtIndex:aIndex] mainView]];
}

- (void)moveUp:(id)aUp
{
	NSInteger index = [_cityInfoControllers count];
	id owner = [[CityInfoView selectedView] owner];
	if (owner != nil)
		index = [_cityInfoControllers indexOfObject:owner];
	if (index - 1 >= 0)
		[self _selectCityAtIndex:index - 1];
}

- (void)moveRight:(id)aRight
{
	NSUInteger index = 0;
	id owner = [[CityInfoView selectedView] owner];
	if (owner != nil)
		index = [_cityInfoControllers indexOfObject:owner] + 1;
	if (index < [_cityInfoControllers count])
		[self _selectCityAtIndex:index];
}

- (void)moveLeft:(id)aLeft
{
	[self moveUp:aLeft];
}

- (void)moveDown:(id)aDown
{
	[self moveRight:aDown];
}

- (void)deleteForward:(id)aForward
{
	id owner = [[CityInfoView selectedView] owner];
	if (owner == nil)
		return;
	NSUInteger index = [_cityInfoControllers indexOfObject:owner];
	NSArray *cities = [NSArray arrayWithObject:[[owner cityEntry] entryDictionary]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ResetCitiesNotification" object:cities userInfo:nil];
	// select the city that took its place, or the new last one
	NSInteger next = (NSInteger)index + ((index < [_cityInfoControllers count]) - 1);
	if (next >= 0)
		[self _selectCityAtIndex:next];
}

- (void)removeAllCities
{
	NSMutableArray *cities = [NSMutableArray array];
	NSInteger count = [_cityInfoControllers count];
	for (NSInteger i = 0; i < count; i++)
		[cities addObject:[[[_cityInfoControllers objectAtIndex:i] cityEntry] entryDictionary]];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ResetCitiesNotification" object:cities userInfo:nil];
}

- (void)manualUpdate
{
	[CWManager resetWeatherInternetState];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ManualUpdateWeatherNotification" object:self];
}

- (BOOL)paletteIsVisible
{
	return [_citiesPalette isVisible];
}

- (void)togglePalette
{
	if ([_citiesPalette isVisible])
		[self hidePalette];
	else
		[self showPalette];
}

- (void)hidePalette
{
	[_citiesPalette performClose:self];
}

- (void)showPalette
{
	[self _loadNibIfNeeded];
	[self _adjustPalettePosition];
	if ([_citiesPalette isVisible])
		return;
	[_citiesPalette makeKeyAndOrderFront:self];
	[Preferences setShowWeatherOnStartup:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"WindowDidShowNotification" object:_citiesPalette userInfo:nil];
	[self manualUpdate];
}

- (void)_transparencyLevelWasChanged:(id)aChanged
{
	[_citiesPalette setBackgroundColor:[[_citiesPalette backgroundColor] colorWithAlphaComponent:(float)[Preferences paletteTransparencyLevel]]];
	[_citiesPalette display];
	NSInteger count = [_cityInfoControllers count];
	for (NSInteger i = 0; i < count; i++)
		[[[_cityInfoControllers objectAtIndex:i] mainView] setNeedsCreateImage];
}

// the dragged city was dropped outside the palette
- (void)_acceptDraggingRemoveCity:(id)aCity
{
	if (!_mouseOutside)
		return;
	[_draggedCityInfo release];
	_draggedCityInfo = nil;
	if ([self _refreshMaxSizeWithNeedReconstruct:NO]) {
		[self _reconstructPalette];
		[_citiesPaletteView setNeedsDisplay:YES];
		[self _resizePalette];
		[_citiesPaletteView displayIfNeeded];
	}
	_mouseOutside = NO;
	_needReloadCitiesList = YES;
}

// a city was dragged out of the palette: take it out of the list until it
// comes back or is dropped
- (void)_acceptDraggingExited:(id)aExited
{
	_draggedCityInfo = [aExited object];
	if (![[_draggedCityInfo mainView] isDraggingAborted]) {
		if (_mouseOutside)
			return;
		_mouseOutside = YES;
		[_draggedCityInfo retain];
		[_cityInfoControllers removeObject:_draggedCityInfo];
		[_citiesIndexes removeObject:[[_draggedCityInfo cityEntry] uid]];
	} else {
		_mouseOutside = NO;
		[_cityInfoControllers addObject:_draggedCityInfo];
		[_citiesIndexes addObject:[[_draggedCityInfo cityEntry] uid]];
		[_draggedCityInfo release];
		_draggedCityInfo = nil;
	}
	[Preferences setCitiesList:_citiesIndexes];
	[self _reconstructPalette];
	[_citiesPaletteView setNeedsDisplay:YES];
	[self _resizePalette];
}

// a city dragged over another one swaps places with it
- (void)_acceptDraggingUpdated:(id)aUpdated
{
	id info = [aUpdated object];
	CityInfoView *source = [info draggingSource];
	[source tearOffImageIfNeeded];
	NSPoint location = [info draggingLocation];
	CityInfoView *target = (CityInfoView *)[_citiesPaletteView hitTest:location];
	if (![target isMemberOfClass:[CityInfoView class]])
		return;
	NSPoint point = [target convertPoint:location fromView:nil];
	if (![target mouse:point inRect:[target opaqueBounds]])
		return;
	NSRect targetFrame = [target frame];
	[target setFrameAnimated:[source frame]];
	[source setFrame:targetFrame];
	id sourceOwner = [source owner];
	id targetOwner = [target owner];
	NSUInteger sourceIndex = [_cityInfoControllers indexOfObject:sourceOwner];
	NSUInteger targetIndex = [_cityInfoControllers indexOfObject:targetOwner];
	[_cityInfoControllers replaceObjectAtIndex:sourceIndex withObject:targetOwner];
	[_cityInfoControllers replaceObjectAtIndex:targetIndex withObject:sourceOwner];
	[_citiesIndexes replaceObjectAtIndex:sourceIndex withObject:[[targetOwner cityEntry] uid]];
	[_citiesIndexes replaceObjectAtIndex:targetIndex withObject:[[sourceOwner cityEntry] uid]];
	[Preferences setCitiesList:_citiesIndexes];
	[_citiesPalette setViewsNeedDisplay:YES];
}

// the dragged city came back: put it before the city under the mouse
- (void)_acceptDraggingEntered:(id)aEntered
{
	if (!_mouseOutside)
		return;
	_mouseOutside = NO;
	NSPoint location = [[aEntered object] draggingLocation];
	id view = [_citiesPaletteView hitTest:location];
	if (![view isMemberOfClass:[CityInfoView class]]) {
		[_cityInfoControllers addObject:_draggedCityInfo];
		[_citiesIndexes addObject:[[_draggedCityInfo cityEntry] uid]];
	} else {
		NSUInteger index = [_cityInfoControllers indexOfObject:[view owner]];
		[_cityInfoControllers insertObject:_draggedCityInfo atIndex:index];
		[_citiesIndexes insertObject:[[_draggedCityInfo cityEntry] uid] atIndex:index];
	}
	[Preferences setCitiesList:_citiesIndexes];
	[self _reconstructPalette];
	[_citiesPaletteView setNeedsDisplay:YES];
	[self _resizePalette];
	[_draggedCityInfo release];
	_draggedCityInfo = nil;
}

- (void)_acceptAddCities:(id)aCities
{
	[self showPalette];
	NSArray *cities = [aCities object];
	NSInteger count = [cities count];
	AtlasDatabase *database = [AtlasDatabase database];
	NSInteger limit = [Preferences citiesCountLimit];
	NSInteger shown = [_cityInfoControllers count];
	NSMutableSet *uids = [NSMutableSet setWithCapacity:shown];
	for (NSInteger i = 0; i < shown; i++)
		[uids addObject:[[[_cityInfoControllers objectAtIndex:i] cityEntry] uid]];
	BOOL changed = NO;
	BOOL overLimit = NO;
	for (NSInteger i = 0; i < count; i++) {
		if (shown >= limit) {
			overLimit = YES;
			break;
		}
		id uid = [[cities objectAtIndex:i] objectForKey:kCityEntryUID];
		if ([uids containsObject:uid])
			continue;
		if (!changed) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"NeedStopAnimationsNotification" object:self userInfo:nil];
			changed = YES;
		}
		id entry = [database dbEntryWithUID:uid];
		if (entry != nil) {
			[self _addCityInfo:[[[CityInfoController alloc] initWithCityEntry:entry] autorelease]];
			[_citiesIndexes addObject:uid];
			shown++;
		}
	}
	if (changed) {
		[Preferences setCitiesList:_citiesIndexes];
		[self _reconstructPalette];
		[self _resizePalette];
		_needReloadCitiesList = YES;
	}
	if (overLimit) {
		NSString *ok = _localized(@"Ok");
		NSString *message = [NSString stringWithFormat:_localized(@"Cannot add city message"), (int)limit];
		NSRunAlertPanel(_localized(@"Cannot add city title"), @"%@", ok, nil, nil, message);
	}
}

- (void)_acceptResetCities:(id)aCities
{
	NSArray *cities = [aCities object];
	NSInteger count = [cities count];
	NSMutableSet *uids = [NSMutableSet setWithCapacity:count];
	for (NSInteger i = 0; i < count; i++)
		[uids addObject:[[cities objectAtIndex:i] objectForKey:kCityEntryUID]];
	for (NSInteger i = (NSInteger)[_cityInfoControllers count] - 1; i >= 0; i--) {
		id controller = [_cityInfoControllers objectAtIndex:i];
		id uid = [[controller cityEntry] uid];
		if (![uids containsObject:uid])
			continue;
		[_citiesIndexes removeObject:uid];
		[_cityInfoControllers removeObject:controller];
		CityInfoView *view = [controller mainView];
		[view removeFromSuperview];
		[view setOwner:nil];
	}
	[Preferences setCitiesList:_citiesIndexes];
	[self _addDefaultCityIfNeeded];
	[self _refreshMaxSizeWithNeedReconstruct:NO];
	[self _reconstructPalette];
	[_citiesPaletteView setNeedsDisplay:YES];
	[self _resizePalette];
	_needReloadCitiesList = YES;
}

- (void)_acceptNeedReconstruct:(id)aReconstruct
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NeedStopAnimationsNotification" object:self userInfo:nil];
	if ([self _refreshMaxSizeWithNeedReconstruct:YES])
		[_citiesPaletteView setNeedsDisplay:YES];
	[self _reconstructPalette];
	[self _resizePalette];
}

// once a second: refreshes the views and, when the minute or the locale's
// date changes, the times shown
- (void)_timeTick:(id)aTick
{
	static NSString *lastLocaleDate = nil;
	static int lastMinutesCount = -1;
	if ([CityInfoView isDraggingInProgress])
		return;
	if (_needReloadCitiesList) {
		_needReloadCitiesList = NO;
		[_citiesListController reloadTableData];
	}
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	if ([_citiesPalette isVisible])
		[center postNotificationName:@"NeedStartAnimationsNotification" object:self userInfo:nil];
	[_citiesPalette setViewsNeedDisplay:NO];
	[self _cacheNextImageIfNeeded];
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	BOOL localeChanged = NO;
	NSDictionary *userInfo = nil;
	Class panther = [PantherSpecificClass principalClass];
	if (panther != nil) {
		NSString *date = [panther stringWithLocaleShortDateFormatForAbsoluteTime:now];
		if (lastLocaleDate == nil)
			lastLocaleDate = [date retain];
		if (![date isEqualToString:lastLocaleDate]) {
			[lastLocaleDate release];
			lastLocaleDate = [date retain];
			userInfo = [NSDictionary dictionary];
			localeChanged = YES;
		}
	}
	int minutes = (int)(now / 60.0);
	if (lastMinutesCount == -1)
		lastMinutesCount = minutes;
	if (minutes != lastMinutesCount || localeChanged) {
		lastMinutesCount = minutes;
		[center postNotificationName:@"AdjustTimeNotification" object:[NSCalendarDate calendarDate] userInfo:userInfo];
		if (userInfo != nil)
			[center postNotificationName:@"NeedReconstructNotification" object:self];
	}
}

// pops the palette menu up under the title bar's menu button; a click
// opening it from the keyboard gets a key event at the button instead
- (void)_acceptMenuAction:(id)aAction
{
	if (![aAction isKindOfClass:[NSView class]])
		return;
	NSEvent *event = [_citiesPalette currentEvent];
	NSRect bounds = [aAction bounds];
	NSPoint center = NSMakePoint((float)(bounds.origin.x + bounds.size.width * 0.5),
	                             (float)(bounds.origin.y + bounds.size.height * 0.5));
	NSPoint location = [aAction convertPoint:center toView:nil];
	NSEventType type = [event type];
	if (type != NSEventTypeLeftMouseDown) {
		if (type == NSEventTypeKeyDown) {
			event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:location modifierFlags:[event modifierFlags]
			                        timestamp:[event timestamp] windowNumber:[event windowNumber] context:nil
			                       characters:[event characters] charactersIgnoringModifiers:[event charactersIgnoringModifiers]
			                        isARepeat:[event isARepeat] keyCode:[event keyCode]];
		} else {
			event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:location modifierFlags:[event modifierFlags]
			                        timestamp:[event timestamp] windowNumber:[_citiesPalette windowNumber] context:nil
			                       characters:@" " charactersIgnoringModifiers:@" " isARepeat:NO keyCode:0x31];
		}
	}
	[NSMenu popUpContextMenu:_paletteMenu withEvent:event forView:aAction];
}

- (void)_acceptVerticalAction:(id)aAction
{
	[self _changeVerticalState];
}

- (void)_acceptCloseAction:(id)aAction
{
	[_citiesPalette performClose:aAction];
}

// the palette menu, and a copy of it as the submenu of the application
// menu's Weather item
- (void)_createMenu
{
	[self _createSelfMenu];
	NSArray *optionGroups = [CityInfoController optionsMenuItems];
	NSInteger groups = [optionGroups count];
	if (groups != 0 && [_paletteMenu numberOfItems] != 0)
		[_paletteMenu addItem:[NSMenuItem separatorItem]];
	for (NSInteger i = 0; i < groups; i++) {
		NSArray *items = [optionGroups objectAtIndex:i];
		NSInteger count = [items count];
		for (NSInteger j = 0; j < count; j++)
			[_paletteMenu addItem:[items objectAtIndex:j]];
	}
	[self _addSelfMenu];
	NSMenu *menu = [[NSMenu new] autorelease];
	NSMenuItem *item = [self _menuItemWithTitle:_localized(@"Show City Weather Details") selector:@selector(showCityDetails:) tag:0 targer:nil];
	[item setKeyEquivalent:@"i"];
	[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[menu addItem:item];
	[menu addItem:[NSMenuItem separatorItem]];
	item = [self _menuItemWithTitle:_localized(@"Show Cities Info Palette") selector:@selector(toggleCitiesInfoPalette:) tag:0 targer:nil];
	[item setKeyEquivalent:@"I"];
	[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[menu addItem:item];
	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItems:[_paletteMenu itemArray]];
	// without the trailing separator and Go to Preferences
	[menu removeItemAtIndex:[menu numberOfItems] - 1];
	[menu removeItemAtIndex:[menu numberOfItems] - 1];
	NSMenuItem *weatherItem = [[NSApp menu] recursiveFindItemWithTag:0x7bc];
	NSMenuItem *newItem = [[NSMenuItem new] autorelease];
	[menu setTitle:[weatherItem title]];
	[newItem setTitle:[weatherItem title]];
	[newItem setTag:[weatherItem tag]];
	[newItem setSubmenu:menu];
	NSInteger index = [[NSApp menu] indexOfItem:weatherItem];
	[[NSApp menu] removeItem:weatherItem];
	[[NSApp menu] insertItem:newItem atIndex:index];
}

- (void)_addSelfMenu
{
	if ([_paletteMenu numberOfItems] != 0)
		[_paletteMenu addItem:[NSMenuItem separatorItem]];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"Update Weather") selector:@selector(_paletteActionsMenu:) tag:2 targer:self]];
	[_paletteMenu addItem:[NSMenuItem separatorItem]];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"PrintWeather") selector:@selector(_paletteActionsMenu:) tag:6 targer:self]];
	[_paletteMenu addItem:[NSMenuItem separatorItem]];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"Go to Preferences") selector:@selector(_paletteActionsMenu:) tag:4 targer:self]];
}

- (void)_createSelfMenu
{
	_paletteMenu = [NSMenu new];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"Add City") selector:@selector(_paletteActionsMenu:) tag:0 targer:self]];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"Remove Selected") selector:@selector(_paletteActionsMenu:) tag:1 targer:self]];
	[_paletteMenu addItem:[self _menuItemWithTitle:_localized(@"Remove All Cities") selector:@selector(_paletteActionsMenu:) tag:5 targer:self]];
	[_paletteMenu addItem:[NSMenuItem separatorItem]];
	[_paletteMenu addItem:[self _fontSizeMenuItem]];
}

- (id)_menuItemWithTitle:(id)aTitle selector:(SEL)aSelector tag:(NSInteger)aTag targer:(id)aTarger
{
	NSMenuItem *item = [[NSMenuItem new] autorelease];
	[item setTitle:aTitle];
	[item setTarget:aTarger];
	[item setAction:aSelector];
	[item setTag:aTag];
	return item;
}

- (id)_fontSizeMenuItem
{
	NSMenu *menu = [[NSMenu new] autorelease];
	[menu addItem:[self _newFontSizeMenuItemWithTitle:_localized(@"Mini Font Size") tag:0]];
	[menu addItem:[self _newFontSizeMenuItemWithTitle:_localized(@"Small Font Size") tag:1]];
	[menu addItem:[self _newFontSizeMenuItemWithTitle:_localized(@"Regular Font Size") tag:2]];
	NSMenuItem *item = [[NSMenuItem new] autorelease];
	[item setTitle:_localized(@"Font Size")];
	[item setSubmenu:menu];
	return item;
}

- (id)_newFontSizeMenuItemWithTitle:(id)aTitle tag:(NSInteger)aTag
{
	NSMenuItem *item = [[NSMenuItem new] autorelease];
	[item setTitle:aTitle];
	[item setTag:aTag];
	[item setTarget:self];
	[item setAction:@selector(_fontSizeMenu:)];
	return item;
}

- (void)_paletteActionsMenu:(id)aMenu
{
	switch ([aMenu tag]) {
	case 0:
		[_citiesListController showWindow];
		break;
	case 1:
		[self deleteForward:nil];
		break;
	case 2:
		[self manualUpdate];
		break;
	case 3:
		[FullCityInfoController showWithCityEntry:[[[CityInfoView selectedView] owner] cityEntry]];
		break;
	case 4:
		[[[AtlasController atlasController] preferencesController] showWeatherPane];
		break;
	case 5:
		[self removeAllCities];
		break;
	case 6:
		if ([_citiesPalette isVisible])
			[self doPrint:nil];
		else if ([FullCityInfoController isVisible])
			[FullCityInfoController doPrint:nil];
		break;
	}
	[self menuDidClose:_paletteMenu];
}

- (void)_fontSizeMenu:(id)aMenu
{
	if ([aMenu state] != 0)
		return;
	switch ([aMenu tag]) {
	case 0:
		[Preferences setPaletteFontSize:9.0];
		break;
	case 1:
		[Preferences setPaletteFontSize:11.0];
		break;
	case 2:
		[Preferences setPaletteFontSize:13.0];
		break;
	}
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center postNotificationName:@"NeedStopAnimationsNotification" object:self userInfo:nil];
	[center postNotificationName:@"AdjustFontSizeNotification" object:self userInfo:nil];
	[self _refreshMaxSizeWithNeedReconstruct:YES];
	[self _reconstructPalette];
	[self _resizePalette];
}

- (void)showCityDetails:(id)aDetails
{
	[FullCityInfoController showWithCityEntry:[[[CityInfoView selectedView] owner] cityEntry]];
}

- (BOOL)_selectedCityIsActive
{
	return [_citiesPalette isKeyWindow] && [CityInfoView selectedView] != nil;
}

- (BOOL)validateMenuItem:(id)aItem
{
	NSInteger tag = [aItem tag];
	SEL action = [aItem action];
	if (action == @selector(_fontSizeMenu:)) {
		float size = (float)[Preferences paletteFontSize];
		if (tag == 0)
			[aItem setState:size == 9.0f];
		else if (tag == 1)
			[aItem setState:size == 11.0f];
		else if (tag == 2)
			[aItem setState:size == 13.0f];
	} else if (action == @selector(_paletteActionsMenu:)) {
		if (tag == 2) {
			if (![Preferences usesInternet])
				return NO;
		} else if (tag == 1 || tag == 3) {
			return [self _selectedCityIsActive];
		} else if (tag == 6 && [FullCityInfoController isVisible]) {
			return YES;
		}
	} else if (action == @selector(showCityDetails:)) {
		return [self _selectedCityIsActive];
	}
	return [Preferences doShowWeatherOnStartup];
}

- (void)_createTitleView
{
	_citiesPaletteTitleView = [[CIPaletteTitleView new] autorelease];
	[_citiesPaletteTitleView setViewComponents:[self _titleViewComponents]];
	[_citiesPaletteTitleView setVertical:![Preferences verticalStateEnabled]];
	[_citiesPaletteTitleView setHorizontalTitleImage:[NSImage imageNamed:@"title_horisontal"]];
	[_citiesPaletteTitleView setVerticalTitleImage:[NSImage imageNamed:@"title_vertical"]];
	[_citiesPaletteTitleView setTopOffset:0.0];
}

// the title bar buttons: close, minimize (disabled), zoom (flips the
// layout) and the palette menu
- (id)_titleViewComponents
{
	_titleViewComponentRect = NSMakeRect(0.0, 0.0, 11.0, 11.0);
	NSImage *red = [self _buttonImageWithName:@"Red.tif"];
	NSImage *gray = [self _buttonImageWithName:@"Gray.tif"];
	NSImage *green = [self _buttonImageWithName:@"Green.tif"];
	NSImage *triangle = [self _buttonImageWithName:@"Triangle.tif"];
	id menu = [self _buttonWithTitle:_localized(@"Menu") action:@selector(_acceptMenuAction:) image:triangle tag:1 enabled:YES sendActionOn:0];
	id zoom = [self _buttonWithTitle:_localized(@"Zoom") action:@selector(_acceptVerticalAction:) image:green tag:0 enabled:YES sendActionOn:0];
	id minimize = [self _buttonWithTitle:_localized(@"Minimize") action:NULL image:gray tag:0 enabled:NO sendActionOn:0];
	id close = [self _buttonWithTitle:_localized(@"Close") action:@selector(_acceptCloseAction:) image:red tag:0 enabled:YES sendActionOn:0];
	return [NSArray arrayWithObjects:close, minimize, zoom, menu, nil];
}

// the button images; the component rect grows to the largest one
- (id)_buttonImageWithName:(id)aName
{
	NSImage *image = [NSImage imageNamed:aName];
	NSSize size = [image size];
	if ((float)size.width > (float)_titleViewComponentRect.size.width)
		_titleViewComponentRect.size.width = (float)size.width;
	if ((float)size.height > (float)_titleViewComponentRect.size.height)
		_titleViewComponentRect.size.height = (float)size.height;
	return image;
}

- (id)_buttonWithTitle:(id)aTitle action:(SEL)aAction image:(id)aImage tag:(NSInteger)aTag enabled:(BOOL)aEnabled sendActionOn:(NSInteger)aOn
{
	NSButton *button = [[NSButton new] autorelease];
	[button setTarget:self];
	[button setAction:aAction];
	[button setButtonType:NSButtonTypeMomentaryChange];
	[button setTitle:aTitle];
	[button setImage:aImage];
	[button setBordered:NO];
	[button setTag:aTag];
	[button setEnabled:aEnabled];
	[button setFrame:_titleViewComponentRect];
	if (aOn != 0)
		[button sendActionOn:aOn];
	if (floor(NSAppKitVersionNumber) > 1038.0)
		[button setWantsLayer:YES];
	return button;
}

- (void)_setCitiesFromPreferences
{
	NSArray *uids = [Preferences citiesList];
	[_citiesIndexes release];
	_citiesIndexes = [NSMutableArray new];
	AtlasDatabase *database = [AtlasDatabase database];
	NSInteger count = [uids count];
	NSMutableSet *added = [NSMutableSet setWithCapacity:count];
	for (NSInteger i = 0; i < count; i++) {
		id uid = [uids objectAtIndex:i];
		if ([added containsObject:uid])
			continue;
		id entry = [database dbEntryWithUID:uid];
		if (entry == nil)
			continue;
		[_citiesIndexes addObject:[entry uid]];
		[added addObject:[entry uid]];
		[self _addCityInfo:[[[CityInfoController alloc] initWithCityEntry:entry] autorelease]];
	}
	[Preferences setCitiesList:_citiesIndexes];
	[self _addDefaultCityIfNeeded];
}

- (void)_addDefaultCityIfNeeded
{
	if ([_cityInfoControllers count] != 0)
		return;
	[_citiesPalette disableFlushWindow];
	id home = [Preferences homeCity];
	[_citiesPalette enableFlushWindow];
	if (home == nil)
		return;
	[_citiesIndexes addObject:[home uid]];
	[self _addCityInfo:[[[CityInfoController alloc] initWithCityEntry:home] autorelease]];
	[Preferences setCitiesList:_citiesIndexes];
}

- (void)_addCityInfo:(id)aInfo
{
	[aInfo setMenu:_paletteMenu];
	NSUInteger count = [_cityInfoControllers count];
	NSSize size = [aInfo sizeForBestFit];
	if (count == 0) {
		_maxCityViewSize = size;
	} else {
		if ((float)size.width > (float)_maxCityViewSize.width)
			_maxCityViewSize.width = (float)size.width;
		if ((float)size.height > (float)_maxCityViewSize.height)
			_maxCityViewSize.height = (float)size.height;
	}
	[_cityInfoControllers addObject:aInfo];
	[_citiesPaletteView addSubview:[aInfo mainView]];
}

// flips between a row and a column of cities, keeping the palette on screen
- (void)_changeVerticalState
{
	BOOL wasVertical = [Preferences verticalStateEnabled];
	[Preferences setVerticalStateEnabled:!wasVertical];
	[self _reconstructPalette];
	[self _resizePalette];
	NSRect visible = [[self _screen] visibleFrame];
	NSRect frame = [_citiesPalette frame];
	NSPoint origin;
	origin.y = frame.origin.y;
	if (!wasVertical) {
		origin.y = MAX((float)visible.origin.y, (float)frame.origin.y);
		origin.x = frame.origin.x;
	} else {
		origin.x = visible.origin.x;
		if ((float)visible.origin.x <= (float)frame.origin.x) {
			origin.x = frame.origin.x;
			if ((float)visible.origin.x + (float)visible.size.width < (float)frame.size.width + (float)frame.origin.x)
				origin.x = ((float)visible.origin.x + (float)visible.size.width) - (float)frame.size.width;
		}
	}
	[_citiesPalette setFrameOrigin:origin];
}

// the largest city view; returns whether it changed
- (BOOL)_refreshMaxSizeWithNeedReconstruct:(BOOL)aReconstruct
{
	float width = (float)NSZeroSize.width, height = (float)NSZeroSize.height;
	NSInteger count = [_cityInfoControllers count];
	for (NSInteger i = 0; i < count; i++) {
		id controller = [_cityInfoControllers objectAtIndex:i];
		if (aReconstruct)
			[controller reconstructMainView];
		NSSize size = [controller sizeForBestFit];
		width = (float)size.width <= width ? width : (float)size.width;
		height = (float)size.height <= height ? height : (float)size.height;
	}
	NSSize size = NSMakeSize(width, height);
	if (NSEqualSizes(size, _maxCityViewSize))
		return NO;
	_maxCityViewSize = size;
	return YES;
}

// lays the city views out in a grid that fits the screen, with separators
// between the columns
- (void)_reconstructPalette
{
	NSRect visible = [[self _screen] visibleFrame];
	float cellWidth = (float)_maxCityViewSize.width;
	float cellHeight = (float)_maxCityViewSize.height;
	BOOL vertical = [Preferences verticalStateEnabled];
	[_citiesPaletteTitleView setVertical:!vertical];
	_minContentSize = [_citiesPaletteTitleView sizeForBestFit];
	float separatorWidth = (float)[_verticalSeparatorImage size].width;
	int count = (int)[_cityInfoControllers count];
	int columns, rows;
	if (!vertical) {
		columns = (int)(((float)visible.size.width - (float)_minContentSize.width) / (separatorWidth + cellWidth));
		if (columns < 1)
			columns = 1;
		rows = count % columns < 1 ? count / columns : count / columns + 1;
		if (count < columns)
			columns = count;
	} else {
		int fit = (int)(((float)visible.size.height - (float)_minContentSize.height) / (cellHeight + 0.0f));
		if (fit < 1)
			fit = 1;
		columns = count % fit < 1 ? count / fit : count / fit + 1;
		rows = fit <= count ? fit : count;
		if ((float)columns * cellWidth + (float)(columns - 1) * separatorWidth < (float)_minContentSize.width)
			cellWidth = (float)_minContentSize.width;
	}
	int lastColumn = columns - 1;
	NSUInteger separatorIndex = 0;
	for (int i = 0; i < count; i++) {
		id controller = [_cityInfoControllers objectAtIndex:i];
		int column;
		float x, y;
		if (!vertical) {
			column = i % columns;
			y = (float)(i / columns) * (cellHeight + 0.0f) + 0.0f;
			x = (float)column * (separatorWidth + cellWidth) + (float)_minContentSize.width;
		} else {
			column = i / rows;
			x = (float)column * (separatorWidth + cellWidth) + 0.0f;
			y = (float)(i % rows) * (cellHeight + 0.0f) + (float)_minContentSize.height;
		}
		y = y + 0.0f;
		[[controller mainView] setFrame:NSMakeRect(x, y, cellWidth, cellHeight)];
		x = x + cellWidth;
		if (column < lastColumn) {
			NSRect separatorFrame = NSMakeRect(x, y, separatorWidth, cellHeight);
			while ([_separatorViews count] <= separatorIndex) {
				CIBackgroundImageView *separator = [[[CIBackgroundImageView alloc] initWithFrame:separatorFrame] autorelease];
				[separator setImage:_verticalSeparatorImage];
				[separator setImageViewStyle:1];
				[separator setImageScaling:1];
				[_separatorViews addObject:separator];
			}
			id separator = [_separatorViews objectAtIndex:separatorIndex];
			[separator setFrame:separatorFrame];
			[_citiesPaletteView addSubview:separator];
			separatorIndex++;
		}
	}
	NSUInteger separators = [_separatorViews count];
	for (; separatorIndex < separators; separatorIndex++)
		[[_separatorViews objectAtIndex:separatorIndex] removeFromSuperview];
	_contentSize = _minContentSize;
	if (!vertical) {
		_contentSize.width = (float)lastColumn * separatorWidth + (float)columns * cellWidth + (float)_contentSize.width;
		float height = (float)rows * (cellHeight + 0.0f);
		if (height > (float)_contentSize.height)
			_contentSize.height = height;
	} else {
		_contentSize.height = (float)rows * (cellHeight + 0.0f) + (float)_contentSize.height;
		float width = (float)columns * cellWidth + (float)lastColumn * separatorWidth;
		if (width > (float)_contentSize.width)
			_contentSize.width = width;
	}
}

// resizes to the content keeping the top edge in place
- (void)_resizePalette
{
	NSRect frame = [_citiesPalette frame];
	NSRect newFrame;
	newFrame.origin.x = frame.origin.x;
	newFrame.size = _contentSize;
	newFrame.origin.y = ((float)frame.origin.y + (float)frame.size.height) - (float)_contentSize.height;
	[_citiesPalette setFrame:newFrame display:YES];
	[self _adjustPalettePosition];
}

// keeps the palette inside the screen's visible frame
- (void)_adjustPalettePosition
{
	NSRect frame = [_citiesPalette frame];
	NSRect visible = [[self _screen] visibleFrame];
	float y = (float)frame.origin.y;
	float top = (float)frame.size.height + (float)frame.origin.y;
	if (top < (float)visible.origin.y) {
		top = (float)frame.size.height + (float)visible.origin.y;
		y = (float)visible.origin.y;
	}
	float x = (float)visible.origin.x <= (float)frame.size.width + (float)frame.origin.x ? (float)frame.origin.x : (float)visible.origin.x;
	if ((float)visible.origin.x + (float)visible.size.width < x)
		x = ((float)visible.origin.x + (float)visible.size.width) - (float)frame.size.width;
	if ((float)visible.origin.y + (float)visible.size.height < top)
		y = ((float)visible.origin.y + (float)visible.size.height) - (float)frame.size.height;
	[_citiesPalette setFrameOrigin:NSMakePoint(x, y)];
}

- (id)_screen
{
	NSScreen *screen = [_citiesPalette screen];
	if (screen == nil)
		return [NSScreen mainScreen];
	return screen;
}

// tabs through the title bar buttons and the city views
- (void)_constrainKeyViewsChain
{
	NSArray *components = [_citiesPaletteTitleView viewComponents];
	NSInteger count = [components count];
	for (NSInteger i = 0; i < count - 1; i++)
		[[components objectAtIndex:i] setNextKeyView:[components objectAtIndex:i + 1]];
	if (count > 0) {
		[_citiesPaletteView setNextKeyView:[components objectAtIndex:0]];
		[[components lastObject] setNextKeyView:_citiesPaletteView];
	}
}

// renders one city view's cached image per tick
- (void)_cacheNextImageIfNeeded
{
	static NSUInteger index = 0;
	if ([_cityInfoControllers count] <= index) {
		index = 0;
		return;
	}
	NSUInteger current = index++;
	[[[_cityInfoControllers objectAtIndex:current] mainView] createImageIfNeeded];
}

- (void)_loadNibIfNeeded
{
	static BOOL wasHere = NO;
	if (wasHere)
		return;
	wasHere = YES;
	[self awakeFromNib];
}

@end

@implementation NSMenu (Extensions)

// appends copies of the items, submenus included
- (void)addItems:(id)aItems
{
	NSInteger count = [aItems count];
	for (NSInteger i = 0; i < count; i++) {
		NSMenuItem *item = [aItems objectAtIndex:i];
		NSMenuItem *copy;
		if ([item isSeparatorItem]) {
			copy = [NSMenuItem separatorItem];
		} else {
			copy = [[NSMenuItem new] autorelease];
			[copy setTitle:[item title]];
			[copy setTag:[item tag]];
			[copy setTarget:[item target]];
			[copy setAction:[item action]];
			NSMenu *submenu = [item submenu];
			if (submenu != nil) {
				NSMenu *subcopy = [[NSMenu new] autorelease];
				[subcopy addItems:[submenu itemArray]];
				[copy setSubmenu:subcopy];
			}
		}
		[self addItem:copy];
	}
}

- (id)recursiveFindItemWithTag:(NSInteger)aTag
{
	NSMenuItem *item = [self itemWithTag:aTag];
	if (item != nil)
		return item;
	NSArray *items = [self itemArray];
	NSInteger count = [items count];
	for (NSInteger i = 0; i < count; i++) {
		item = [[[items objectAtIndex:i] submenu] recursiveFindItemWithTag:aTag];
		if (item != nil)
			return item;
	}
	return nil;
}

@end
