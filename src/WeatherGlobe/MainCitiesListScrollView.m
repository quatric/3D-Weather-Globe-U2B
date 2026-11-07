#import "MainCitiesListScrollView.h"

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:nil];
}

@implementation MainCitiesListScrollView

- (void)reflectScrolledClipView:(id)aView
{
	NSView *document;
	NSRect visible;

	[super reflectScrolledClipView:aView];
	document = [self documentView];
	visible = [self documentVisibleRect];
	if (!NSEqualRects(visible, _lastDocumentVisibleRect) && [document respondsToSelector:@selector(setNeedsDisplay:)]) {
		_lastDocumentVisibleRect = visible;
		[document setNeedsDisplay:YES];
	}
}

- (void)awakeFromNib
{
	_lastDocumentVisibleRect = [self documentVisibleRect];
}

@end

@implementation MainWindowController

- (void)toggleRemoteControleFocus:(id)aFocus
{
	if (!_isInFullWindowMode)
		return;
	if ([_remoteControlController isActive]) {
		[_mainWindow makeFirstResponder:_glView];
		[_mainWindow makeKeyWindow];
	} else if ([_optionsController drawerIsOpenState] && [_mainWindow firstResponder] == _glView) {
		[_optionsController selectInitialResponder];
	} else {
		[_remoteControlController showRemoteControl];
	}
}

- (void)toggleToolbarFocus:(id)aFocus
{
	if ([_optionsController drawerIsOpenState]) {
		if ([self _isControlInToolbar:[_mainWindow firstResponder]]) {
			[_optionsController selectInitialResponder];
			return;
		}
	} else if ([self _isControlInToolbar:[_mainWindow firstResponder]]) {
		[_mainWindow makeFirstResponder:nil];
		[_mainWindow selectNextKeyView:nil];
		return;
	}
	[_mainWindow makeFirstResponder:[_spaceButt isEnabled] ? (id)_spaceButt : (id)_dayNightButt];
}

- (BOOL)_isControlInToolbar:(id)aToolbar
{
	return aToolbar == _spaceButt || aToolbar == _dayNightButt || aToolbar == _gridButt
		|| aToolbar == _regionHltButt || aToolbar == _cloudsButt || aToolbar == _allCitiesButt
		|| aToolbar == _citiesInfoButt || aToolbar == _optionsButt || aToolbar == _nearestCityButt;
}

- (void)doPrint:(id)aPrint
{
	PrintController *controller = [self printController];
	[controller setMapMode:[self currentMapMode]];
	[controller setPrintAtlas:([aPrint tag] & 1) != 0];
	[controller setPrintCalcList:([aPrint tag] & 2) != 0];
	[controller showPrintOptionsModalForWindow:_mainWindow modalDelegate:self
		didEndSelector:@selector(printOptionsSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)printOptionsSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
	PrintController *controller;
	NSPrintOperation *operation;

	if (aCode != 1)
		return;
	[aEnd orderOut:self];
	controller = [self printController];
	operation = [NSPrintOperation printOperationWithView:[controller containerView] printInfo:[self printInfo]];
	[operation runOperationModalForWindow:_mainWindow delegate:controller
		didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:NULL];
}

- (void)runPageLayout:(id)aLayout
{
	[[NSPageLayout pageLayout] runModal];
}

- (id)printController
{
	if (_printController == nil)
		_printController = [[PrintController alloc] initWithSize:NSZeroSize controller:self];
	return _printController;
}

// Margins are at least 30pt, or the printer's imageable area if that is larger.
- (id)printInfo
{
	NSPrintInfo *info = [NSPrintInfo sharedPrintInfo];
	NSRect bounds = [info imageablePageBounds];
	NSSize paper = [info paperSize];
	CGFloat right = paper.width - (bounds.origin.x + bounds.size.width);
	CGFloat top = paper.height - (bounds.origin.y + bounds.size.height);

	[info setLeftMargin:bounds.origin.x > 30.0 ? bounds.origin.x : 30.0];
	[info setBottomMargin:bounds.origin.y > 30.0 ? bounds.origin.y : 30.0];
	[info setRightMargin:right > 30.0 ? right : 30.0];
	[info setTopMargin:top > 30.0 ? top : 30.0];
	return info;
}

- (BOOL)currentPathNameIsInvalid
{
	return _currentPathNameIsInvalid;
}

- (id)currentRoutePath
{
	return _currentRoutePath;
}

- (void)saveRouteDocumentAtPath:(id)aPath hideExt:(BOOL)aExt
{
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *title, *message;

	if ([manager fileExistsAtPath:aPath] && ![manager isWritableFileAtPath:aPath]) {
		title = _localized(@"Cannot save to file title");
		message = _localized(@"Cannot save to file message");
	} else if (![manager isWritableFileAtPath:[aPath stringByDeletingLastPathComponent]]) {
		title = _localized(@"Cannot save to folder title");
		message = _localized(@"Cannot save to folder message");
	} else {
		NSMutableArray *entries = [NSMutableArray array];
		NSInteger count = [_entriesOnMap count], i;
		NSDictionary *document;

		for (i = 0; i < count; i++)
			[entries addObject:[[_entriesOnMap objectAtIndex:i] entryDictionary]];
		_routeDocRevision++;
		document = [NSDictionary dictionaryWithObjectsAndKeys:entries, @"entries",
			[NSString stringWithFormat:@"%d", _routeDocRevision], @"revision", nil];
		if ([document writeToFile:aPath atomically:YES]) {
			if (aExt)
				[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
					forKey:NSFileExtensionHidden] ofItemAtPath:aPath error:NULL];
			[_currentRoutePath autorelease];
			_currentRoutePath = [[NSString alloc] initWithString:aPath];
			_currentPathNameIsInvalid = NO;
			_hideExtensionInRouteFileName = aExt;
			[_entriesToRevert release];
			_entriesToRevert = [[NSArray alloc] initWithArray:_entriesOnMap];
			[self _clearRoutesUndo];
			return;
		}
		title = _localized(@"Cannot save to full disk title");
		message = _localized(@"Cannot save to full disk message");
	}
	NSRunAlertPanel(title, @"%@", _localized(@"Ok"), nil, nil, message);
}

- (void)openRouteDocumentAtPath:(id)aPath reverting:(BOOL)aReverting
{
	NSString *name, *title, *message;

	[self stopAnyFlying];
	if (aReverting && NSRunAlertPanel(_localized(@"revert title"), @"%@", _localized(@"Revert"),
			_localized(@"Cancel"), nil, _localized(@"revert message")) != NSAlertDefaultReturn)
		return;

	if ([[NSFileManager defaultManager] isReadableFileAtPath:aPath]) {
		NSArray *entries;
		NSDictionary *attributes;

		_routeDocRevision = 0;
		entries = [NSArray arrayWithContentsOfFile:aPath];
		if (entries == nil) {
			NSDictionary *document = [NSDictionary dictionaryWithContentsOfFile:aPath];
			entries = [document objectForKey:@"entries"];
			_routeDocRevision = [[document objectForKey:@"revision"] intValue];
			if (entries == nil) {
				name = [[aPath lastPathComponent] stringByDeletingPathExtension];
				NSRunAlertPanel([NSString stringWithFormat:_localized(@"Cannot open corrupted file title"), name], @"%@",
					_localized(@"Ok"), nil, nil, _localized(@"Cannot open corrupted file message"));
				return;
			}
		}
		[self setSampleRoute:entries andSlideToCenter:YES];
		[_currentRoutePath autorelease];
		_currentRoutePath = [[NSString alloc] initWithString:aPath];
		_currentPathNameIsInvalid = NO;
		attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[_currentRoutePath stringByResolvingSymlinksInPath] error:NULL];
		if (attributes)
			_hideExtensionInRouteFileName = [[attributes objectForKey:NSFileExtensionHidden] boolValue];
		if (aReverting)
			[self _clearRoutesUndo];
		return;
	}

	name = [[aPath lastPathComponent] stringByDeletingPathExtension];
	if (!aReverting) {
		title = [NSString stringWithFormat:_localized(@"Cannot open title"), name];
		message = _localized(@"Cannot open message");
	} else if (![[NSFileManager defaultManager] fileExistsAtPath:aPath]) {
		title = _localized(@"Cannot revert title");
		message = [NSString stringWithFormat:_localized(@"Cannot revert message"), name];
	} else {
		title = [NSString stringWithFormat:_localized(@"Cannot revert bad_privs title"), name];
		message = _localized(@"Cannot revert bad_privs message");
	}
	NSRunAlertPanel(title, @"%@", _localized(@"Ok"), nil, nil, message);
}

- (void)setSampleRoute:(id)aRoute andSlideToCenter:(BOOL)aCenter
{
	NSRect bounds = NSZeroRect;
	NSInteger count, i;

	[_entriesOnMap release];
	_entriesOnMap = [NSMutableArray new];
	count = [aRoute count];
	for (i = 0; i < count; i++) {
		YACityEntry *entry = [YACityEntry entryWithDictionaryRep:[aRoute objectAtIndex:i]];
		NSPoint point;

		if (entry == nil)
			continue;
		[_entriesOnMap addObject:entry];
		point = [entry coordinates];
		// the bounding box of the route's geo points, grown one point at a time
		if (i == 0) {
			bounds.origin = point;
		} else if (!NSPointInRect(point, bounds)) {
			if (point.x < bounds.origin.x)
				bounds.origin.x = point.x;
			else if (bounds.size.width + bounds.origin.x < point.x)
				bounds.size.width = point.x - bounds.origin.x;
			if (point.y < bounds.origin.y)
				bounds.origin.y = point.y;
			else if (bounds.size.height + bounds.origin.y < point.y)
				bounds.size.height = point.y - bounds.origin.y;
		}
	}
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = [[NSMutableSet alloc] initWithArray:_entriesOnMap];
	[_entriesToRevert release];
	_entriesToRevert = [[NSArray alloc] initWithArray:_entriesOnMap];
	[self _adjustAllAfterMapCitiesContainerChange];
	if (aCenter)
		[_currentPanelController slideToMapPoint:_mapPointFromGeoPoint(NSMakePoint(bounds.size.width * 0.5 + bounds.origin.x,
			bounds.size.height * 0.5 + bounds.origin.y))];
	if ([_entriesOnMap count] >= 2) {
		[_routeModeControl selectCellAtRow:0 column:0];
		[self routeModeChanged:_routeModeControl];
	}
}

- (void)newRouteInfo
{
	[self stopAnyFlying];
	[_entriesOnMap release];
	_entriesOnMap = nil;
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = nil;
	_routeDocRevision = 0;
	_currentPathNameIsInvalid = YES;
	[self _adjustAllAfterMapCitiesContainerChange];
}

- (void)_clearRoutesUndo
{
	[[[self mainWindow] undoManager] removeAllActionsWithTarget:self];
}

// The original used the pre-10.6 sheet calls; the block versions call the same did-end methods.
static NSString *_routesDirectory(NSString *aCurrentPath)
{
	NSString *directory = [aCurrentPath stringByDeletingLastPathComponent];
	if (directory == nil || [directory hasPrefix:[[NSBundle mainBundle] bundlePath]])
		directory = [[NSFileManager defaultManager] routesFolder];
	return directory;
}

- (void)openRouteInfo
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSString *directory;

	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setCanChooseFiles:YES];
	directory = _routesDirectory(_currentRoutePath);
	if (directory)
		[panel setDirectoryURL:[NSURL fileURLWithPath:directory]];
	[panel setAllowedFileTypes:[NSArray arrayWithObjects:kRouteSetFileExt, kAppleStoresSetFileExt, nil]];
	[panel beginSheetModalForWindow:_mainWindow completionHandler:^(NSModalResponse result) {
		[self _openPanelDidEnd:panel returnCode:result contextInfo:NULL];
	}];
}

- (void)_openPanelDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
	NSArray *urls = [aEnd URLs];
	NSString *path;

	if ([urls count] == 0)
		return;
	path = [[urls objectAtIndex:0] path];
	if (path && aCode == NSModalResponseOK)
		[self openRouteDocumentAtPath:path reverting:NO];
}

- (void)saveCurrentRouteInfo
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *directory, *name;

	[panel setCanSelectHiddenExtension:YES];
	[panel setAllowedFileTypes:[NSArray arrayWithObjects:kRouteSetFileExt, kAppleStoresSetFileExt, nil]];
	[panel setExtensionHidden:YES];
	directory = _routesDirectory(_currentRoutePath);
	name = [[_currentRoutePath lastPathComponent] stringByDeletingPathExtension];
	if (name == nil || _currentPathNameIsInvalid) {
		NSArray *entries = [self entriesOnMap];
		NSUInteger count = [entries count];

		if (count == 1) {
			YACityEntry *entry = [entries objectAtIndex:0];
			if ([entry regionName] == nil)
				name = [NSString stringWithFormat:@"%@", [entry ownName]];
			else
				name = [NSString stringWithFormat:@"%@ (%@)", [entry ownName], [entry regionName]];
		} else if (count >= 2) {
			name = [NSString stringWithFormat:@"%@ - %@ Route", [[entries objectAtIndex:0] ownName], [[entries lastObject] ownName]];
		} else {
			name = @"";
		}
	}
	if (directory)
		[panel setDirectoryURL:[NSURL fileURLWithPath:directory]];
	if (name)
		[panel setNameFieldStringValue:name];
	[panel beginSheetModalForWindow:_mainWindow completionHandler:^(NSModalResponse result) {
		[self _savePanelDidEnd:panel returnCode:result contextInfo:NULL];
	}];
}

- (void)_savePanelDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
	NSString *path = [[aEnd URL] path];
	if (path && aCode == NSModalResponseOK)
		[self saveRouteDocumentAtPath:path hideExt:[aEnd isExtensionHidden]];
}

- (void)reloadRouteButtonMenu
{
	NSMenu *menu = [[[NSApp mainMenu] itemWithTitle:@"Route"] submenu];
	NSInteger count, i;

	if (menu == nil)
		return;
	menu = [[menu copy] autorelease];
	[menu removeItemAtIndex:[menu indexOfItemWithTitle:@"Clear"]];
	count = [menu numberOfItems];
	for (i = 0; i < count; i++)
		[[menu itemAtIndex:i] setKeyEquivalent:@""];
	[_routeButt setMenu:menu];
}

- (void)showCityDetails:(id)aDetails
{
	[FullCityInfoController showWithCityEntry:[_citiesListController selectedItem]];
}

- (void)viewControlMenu:(id)aMenu
{
	NSInteger tag = [aMenu tag];
	id control = nil;

	switch (tag) {
	case 1:
	case 2:
		control = _scaleSlider;
		[control setFloatValue:tag == 1 ? _scaleValue + 0.05f : _scaleValue - 0.05f];
		break;
	case 3:
	case 4:
		control = _viewModeControl;
		[_viewModeControl setSelectedSegment:tag - 3];
		[_viewModeControl2 setSelectedSegment:tag - 3];
		break;
	case 5:
	case 6:
	case 7:
		[_mouseBehaviuorMatrix selectCellWithTag:tag - 5];
		control = [_mouseBehaviuorMatrix selectedCell];
		break;
	case 8:
		[_optionsController toggleOptions];
		_needRestoreDrawer = NO;
		break;
	}
	[[control target] performSelector:[control action] withObject:control];
}

- (void)routeSampleMenu:(id)aMenu
{
	[self setSampleRoute:[[AtlasDatabase database] sampleRouteWithUID:[aMenu representedObject]] andSlideToCenter:YES];
}

- (void)routeMenu:(id)aMenu
{
	switch ([aMenu tag]) {
	case 1:
		[self openRouteInfo];
		break;
	case 2:
		if (!_currentPathNameIsInvalid && _currentRoutePath) {
			[self saveRouteDocumentAtPath:_currentRoutePath hideExt:_hideExtensionInRouteFileName];
			break;
		}
		// fall through
	case 3:
		[self saveCurrentRouteInfo];
		break;
	case 4:
		[self newRouteInfo];
		break;
	case 5:
		[self openRouteDocumentAtPath:_currentRoutePath reverting:YES];
		break;
	case 6:
		[_flyAlongRouteButton setIntValue:1 - [_flyAlongRouteButton intValue]];
		[self flyAlongRoute:_flyAlongRouteButton];
		break;
	}
}

- (void)gridMenu:(id)aMenu
{
	NSInteger tag = [aMenu tag];
	if (tag == 1) {
		[Preferences setGridEnabled:NO];
	} else {
		[Preferences setGridEnabled:YES];
		[Preferences setGridDetalization:tag - 2];
	}
	[_glView setNeedsDisplay:YES];
}

- (void)cloudsMenu:(id)aMenu
{
	NSInteger tag = [aMenu tag];
	if (tag == 1) {
		[Preferences setCloudsEnabled:NO];
		[_cloudsMaterial cleanup];
	} else if (tag >= 2 && tag <= 4) {
		[Preferences setCloudsEnabled:YES];
		[Preferences setCloudsAnimationQuality:tag - 2];
		[_cloudsMaterial restoreAfterCleanup];
	}
	[_glView setNeedsDisplay:YES];
}

- (void)spaceMenu:(id)aMenu
{
	switch ([aMenu tag]) {
	case 0:
		[Preferences setStarsEnabled:![Preferences starsEnabled]];
		break;
	case 1:
		[Preferences setMoonEnabled:![Preferences moonEnabled]];
		break;
	case 2:
		[Preferences setSunEnabled:![Preferences sunEnabled]];
		break;
	case 3:
		if ([Preferences spaceEnabled]) {
			[Preferences setPreviousStarsEnabled:[Preferences starsEnabled]];
			[Preferences setPreviousMoonEnabled:[Preferences moonEnabled]];
			[Preferences setPreviousSunEnabled:[Preferences sunEnabled]];
			[Preferences setSpaceEnabled:NO];
		}
		break;
	}
	[_glView setNeedsDisplay:YES];
}

- (void)drawElementsMenu:(id)aMenu
{
	switch ([aMenu tag]) {
	case 1:
		[Preferences setDayNightEnabled:![Preferences dayNightIsEnabled]];
		break;
	case 3:
		[Preferences setNearestCityEnabled:![Preferences nearestCityEnabled]];
		break;
	case 4:
		[Preferences setDrawAllCities:![Preferences doDrawAllCities]];
		break;
	case 5:
		[Preferences setShowLocationEnabled:![Preferences showLocationEnabled]];
		break;
	case 6:
		[Preferences setShowTimeZoneEnabled:![Preferences showTimeZoneEnabled]];
		break;
	case 7:
		[self toggleFullWindowMode:self];
		break;
	case 8:
		[Preferences setShowAllCountryBorders:![Preferences showAllCountryBorders]];
		break;
	case 9:
		[_routeModeControl selectCellAtRow:0 column:[Preferences showRouteLines] ? 1 : 0];
		[self routeModeChanged:_routeModeControl];
		break;
	case 23:
		[Preferences setEarthTiltedMode:![Preferences earthTiltedMode]];
		[_currentPanelController refreshCameraSettings];
		break;
	}
	[_glView setNeedsDisplay:YES];
}

- (void)regionHighlightMenu:(id)aMenu
{
	NSInteger tag = [aMenu tag];
	if (tag == 1) {
		[Preferences setRegionHighlightEnabled:NO];
	} else if (tag >= 2 && tag <= 4) {
		[Preferences setRegionHighlightEnabled:YES];
		[Preferences setRegionHighLightMode:tag - 2];
	}
	[_glView setNeedsDisplay:YES];
}

- (BOOL)validateMenuItem:(id)aItem
{
	NSInteger tag = [aItem tag];
	SEL action = [aItem action];

	if (action == @selector(drawElementsMenu:)) {
		switch (tag) {
		case 1:
			[aItem setState:[Preferences dayNightIsEnabled]];
			break;
		case 3:
			[aItem setState:[Preferences nearestCityEnabled]];
			break;
		case 4:
			[aItem setState:[Preferences doDrawAllCities]];
			break;
		case 5:
			[aItem setState:[Preferences showLocationEnabled]];
			break;
		case 6:
			[aItem setState:[Preferences showTimeZoneEnabled]];
			break;
		case 7:
			[aItem setTitle:_localized([self isInFullWindowMode] ? @"Turn Full Screen View Off" : @"Turn Full Screen View On")];
			break;
		case 8:
			[aItem setState:[Preferences showAllCountryBorders]];
			break;
		case 9:
			[aItem setTitle:_localized([Preferences showRouteLines] ? @"Hide Route Lines" : @"Show Route Lines")];
			return [_routeModeControl isEnabled];
		case 23:
			[aItem setState:[Preferences earthTiltedMode]];
			return [self currentMapMode] == 0;
		}
		return YES;
	}

	if (action == @selector(cloudsMenu:)) {
		if (![Preferences cloudsEnabled]) {
			[aItem setState:tag == 1];
		} else {
			NSInteger quality = [Preferences cloudsAnimationQuality];
			if (tag == 1)
				[aItem setState:NO];
			else if (tag >= 2 && tag <= 4)
				[aItem setState:quality == tag - 2];
		}
		return YES;
	}

	if (action == @selector(gridMenu:)) {
		NSInteger detalization = [Preferences gridDetalization];
		if (tag == 1)
			[aItem setState:![Preferences gridEnabled]];
		else if (tag >= 2 && tag <= 5)
			[aItem setState:[Preferences gridEnabled] && detalization == tag - 2];
		return YES;
	}

	if (action == @selector(doPrint:)) {
		if (tag != 2)
			return YES;
		return [[self entriesOnMap] count] != 0;
	}

	if (action == @selector(routeMenu:)) {
		[aItem setState:NO];
		if (tag == 5)
			return _currentRoutePath != nil && ![_entriesToRevert isEqualToArray:[self entriesOnMap]];
		if (tag == 6) {
			[aItem setState:[_flyAlongRouteButton intValue]];
			return [[self entriesOnMap] count] > 1;
		}
		if (tag < 2 || tag > 6)
			return YES;
		return [[self entriesOnMap] count] != 0;
	}

	if (action == @selector(viewControlMenu:)) {
		switch (tag) {
		case 1:
			return _scaleValue != 1.0f;
		case 2:
			return _scaleValue != 0.0f;
		case 3:
			[aItem setState:[_currentPanelController class] == [SphereMapController class]];
			break;
		case 4:
			[aItem setState:[_currentPanelController class] == [FlatMapController class]];
			break;
		case 5:
		case 6:
		case 7:
			[aItem setState:[Preferences mouseBehaviourOnMap] == tag - 5];
			break;
		case 8:
			[aItem setTitle:_localized([_optionsController drawerIsOpenState] ? @"Hide Settings Drawer" : @"Show Settings Drawer")];
			break;
		}
		return YES;
	}

	if (action == @selector(spaceMenu:)) {
		switch (tag) {
		case 0:
			[aItem setState:[Preferences starsEnabled]];
			break;
		case 1:
			[aItem setState:[Preferences moonEnabled]];
			break;
		case 2:
			[aItem setState:[Preferences sunEnabled]];
			break;
		case 3:
			[aItem setState:![Preferences spaceEnabled]];
			break;
		}
		return [_currentPanelController class] == [SphereMapController class];
	}

	if (action == @selector(showCityDetails:))
		return [_mainWindow isKeyWindow] && [_citiesListController selectedItem] != nil;

	if (action == @selector(toggleFullWindowMode:)) {
		[aItem setState:[self isInFullWindowMode]];
		return YES;
	}

	if (action == @selector(regionHighlightMenu:)) {
		BOOL enabled = [Preferences regionHighlightIsEnabled];
		if (tag == 1)
			[aItem setState:!enabled];
		else if (tag >= 2 && tag <= 4)
			[aItem setState:enabled && [Preferences regionHighLightMode] == tag - 2];
		return YES;
	}

	if (action == @selector(delete:)) {
		id responder = [_mainWindow firstResponder];
		return responder == _routeTabView && [responder numberOfSelectedRows] > 0;
	}
	return YES;
}

- (void)openSearchForTerm:(id)aTerm
{
	if ([self isInFullWindowMode])
		[self toggleFullWindowMode:nil];
	[_citiesListController setSearchTerm:aTerm andRefreshResults:YES];
}

- (BOOL)isInFullWindowMode
{
	return _isInFullWindowMode;
}

// Full window mode takes the GL view out of the splitter, fills the window
// (which fills the screen) with it, and shows the floating remote control.
- (void)toggleFullWindowMode:(id)aMode
{
	NSView *content = [_mainWindow contentView];

	_isInFullWindowMode = !_isInFullWindowMode;
	if (_isInFullWindowMode) {
		NSRect frame;
		CGFloat dx, dy, y;

		_prevWindowSize = [content frame].size;
		_prevGLViewRect = [_glViewFrame frame];
		frame = [_listWSGLViewSplitter convertRect:_prevGLViewRect toView:content];
		y = frame.origin.y;
		dx = frame.origin.x - _fullWindowGLViewOrigin.x;
		dy = y - _fullWindowGLViewOrigin.y;
		frame.origin.x -= dx;
		frame.size.width += dx;
		frame.size.height += dy;
		[_bottomControlsContainer removeFromSuperview];
		[_listWSGLViewSplitter removeFromSuperview];
		[content addSubview:_glViewFrame];
		frame.origin.y = y - dy;
		[_glViewFrame setFrame:frame];
		// it has to grow with the window; inside the split view it had no mask
		_prevGLViewAutoresizingMask = [_glViewFrame autoresizingMask];
		[_glViewFrame setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[_mainWindow makeFirstResponder:_glView];
		_needRestoreDrawer = [_optionsController drawerIsOpenState];
		if (_needRestoreDrawer) {
			[_optionsController setNeedsChangeParentWindowFrame:NO];
			[_optionsController hideOptions];
		}
		_prevFrame = [_mainWindow frame];
		_fullWindowFrame = [[NSScreen mainScreen] visibleFrame];
		[_mainWindow setFrame:_fullWindowFrame display:YES];
		_restoreFrame = YES;
		[content displayIfNeeded];
		[_remoteControlController showRemoteControl];
	} else {
		NSRect frame;
		CGFloat dw, dh;

		[_remoteControlController hideRemoteControl];
		[_glViewFrame setAutoresizingMask:_prevGLViewAutoresizingMask];
		[_glViewFrame setFrame:_prevGLViewRect];
		[_listWSGLViewSplitter addSubview:_glViewFrame];
		frame = [content frame];
		dw = frame.size.width - _prevWindowSize.width;
		dh = frame.size.height - _prevWindowSize.height;
		frame = [_listWSGLViewSplitter frame];
		frame.size.width += dw;
		frame.size.height += dh;
		[_listWSGLViewSplitter setFrame:frame];
		frame = [_bottomControlsContainer frame];
		frame.size.width += dw;
		[_bottomControlsContainer setFrame:frame];
		[content addSubview:_listWSGLViewSplitter];
		[content addSubview:_bottomControlsContainer];
		[content setNeedsDisplay:YES];
		if (_restoreFrame)
			[_mainWindow setFrame:_prevFrame display:YES];
		if (_needRestoreDrawer) {
			[_optionsController setNeedsChangeParentWindowFrame:NO];
			[_optionsController showOptions];
		}
	}
	[_glView mouseEntered:nil];
	if (floor(NSAppKitVersionNumber) > 1038.0) {
		[_currentPanelController flagsChanged:nil inView:_glView];
		switch ([Preferences mouseBehaviourOnMap]) {
		case 0:
			[self changeCursorWithKey:0];
			break;
		case 1:
			[self changeCursorWithKey:2];
			break;
		case 2:
			[self changeCursorWithKey:4];
			break;
		}
	}
}

- (void)hideWindow
{
	[_mainWindow close];
}

- (void)showWindow
{
	NSInteger mode;
	Class controllerClass = Nil;

	[self _loadNibIfNeeded];
	[self _restoreBeforeWindowShow];
	mode = [Preferences mapMode];
	if (mode == 0)
		controllerClass = [SphereMapController class];
	else if (mode == 1)
		controllerClass = [FlatMapController class];
	[self _openPanelWithControllerOfClass:controllerClass];
	[_viewModeControl setSelectedSegment:mode];
	[_viewModeControl2 setSelectedSegment:mode];
	[Preferences setShowMainWindow:YES];
	[_mainWindow makeKeyAndOrderFront:self];
	if ([Preferences openFullScreenByDefault] && ![self isInFullWindowMode])
		[self toggleFullWindowMode:nil];
	switch ([Preferences mouseBehaviourOnMap]) {
	case 0:
		[self changeCursorWithKey:0];
		break;
	case 1:
		[self changeCursorWithKey:2];
		break;
	case 2:
		[self changeCursorWithKey:4];
		break;
	}
	if ([Preferences retainLastView]) {
		id route = [Preferences lastRoute];
		if (route)
			[self setSampleRoute:route andSlideToCenter:NO];
	}
}

// 0 zoom in, 1 zoom out, 2 open hand, 3 closed hand, 4 push pin, 5 Apple Store.
// The zoom cursors come from NSCursor+AtlasCustomCursors, whose methods replace
// the same-named ones macOS 15 added.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
- (void)changeCursorWithKey:(NSInteger)aKey
{
	NSCursor *cursor = nil;

	switch (aKey) {
	case 0:
		if (_zoomInCursor == nil)
			_zoomInCursor = [[NSCursor zoomInCursor] retain];
		cursor = _zoomInCursor;
		break;
	case 1:
		if (_zoomOutCursor == nil)
			_zoomOutCursor = [[NSCursor zoomOutCursor] retain];
		cursor = _zoomOutCursor;
		break;
	case 2:
		if (_handOpenCursor == nil)
			_handOpenCursor = [[NSCursor handOpenCursor] retain];
		cursor = _handOpenCursor;
		break;
	case 3:
		if (_handCloseCursor == nil)
			_handCloseCursor = [[NSCursor handCloseCursor] retain];
		cursor = _handCloseCursor;
		break;
	case 4:
		if (_pushPinCursor == nil)
			_pushPinCursor = [[NSCursor pushPinCursor] retain];
		cursor = _pushPinCursor;
		break;
	case 5:
		if (_appleStoreCursor == nil)
			_appleStoreCursor = [[NSCursor appleStoreCursor] retain];
		cursor = _appleStoreCursor;
		break;
	}
	[_glView setCursor:cursor];
}
#pragma clang diagnostic pop

- (BOOL)windowShouldZoom:(id)aZoom toFrame:(NSRect)aFrame
{
	[_remoteControlController checkWindowPosition];
	return YES;
}

- (void)windowDidEndSheet:(id)aSheet
{
	if (_isInFullWindowMode)
		[_remoteControlController showRemoteControl];
}

- (void)windowWillBeginSheet:(id)aSheet
{
	[_remoteControlController hideRemoteControl];
}

- (void)windowDidDeminiaturize:(id)aDeminiaturize
{
	if (_isInFullWindowMode)
		[_remoteControlController showRemoteControl];
}

- (void)windowWillMiniaturize:(id)aMiniaturize
{
	[_remoteControlController hideRemoteControl];
}

// once the user moves or resizes the full window, leaving full window mode
// keeps that frame; the notifications for our own setFrame: can now arrive
// late, so only a frame other than the one we set counts
- (void)windowDidResize:(id)aResize
{
	if (_isInFullWindowMode && !NSEqualRects([_mainWindow frame], _fullWindowFrame))
		_restoreFrame = NO;
}

- (void)windowDidMove:(id)aMove
{
	if (_isInFullWindowMode && !NSEqualRects([_mainWindow frame], _fullWindowFrame))
		_restoreFrame = NO;
}

static SMK_GL_2DTexture *_loadTexture(SMK_GL_ObjectsContainer *aContainer, NSString *aName)
{
	SMK_GL_2DTexture *texture;
	[aContainer beginAccumulationBlock];
	texture = [[SMK_GL_2DTexture alloc] initWithContainer:aContainer flags:0 usage:0
		filePath:[[NSBundle mainBundle] pathForResource:aName ofType:@"tiff"]];
	[aContainer endAccumulationBlock];
	return texture;
}

static SMK_GL_Font *_loadFont(SMK_GL_ObjectsContainer *aContainer, NSFont *aFont)
{
	SMK_GL_Font *font;
	[aContainer beginAccumulationBlock];
	font = [[SMK_GL_Font alloc] initWithContainer:aContainer font:aFont];
	[aContainer endAccumulationBlock];
	return font;
}

- (id)weatherIconsTexture
{
	if (_weatherIconsTexture == nil) {
		id container = [_glView objectsContainer];
		if (container)
			_weatherIconsTexture = _loadTexture(container, @"weather_icons_all");
	}
	return _weatherIconsTexture;
}

- (id)textBackground
{
	if (_txtBackground == nil) {
		id container = [_glView objectsContainer];
		if (container)
			_txtBackground = _loadTexture(container, @"kartinka");
	}
	return _txtBackground;
}

- (id)largeFont
{
	if (_largeFont == nil) {
		id container = [_glView objectsContainer];
		if (container)
			_largeFont = _loadFont(container, [NSFont boldSystemFontOfSize:18.0]);
	}
	return _largeFont;
}

- (id)normalFont
{
	if (_normalFont == nil) {
		id container = [_glView objectsContainer];
		if (container)
			_normalFont = _loadFont(container, [NSFont boldSystemFontOfSize:13.0]);
	}
	return _normalFont;
}

- (id)smallFont
{
	if (_smallFont == nil) {
		id container = [_glView objectsContainer];
		if (container)
			_smallFont = _loadFont(container, [NSFont systemFontOfSize:11.0]);
	}
	return _smallFont;
}

// the engine sound loops while flying
- (void)sound:(id)aSound didFinishPlaying:(BOOL)aPlaying
{
	if (aSound == _planeSound)
		[_planeSound play];
}

- (void)delete:(id)aDelete
{
	if ([_routeTabView respondsToSelector:@selector(deleteForward:)])
		[_routeTabView deleteForward:aDelete];
}

- (void)flyAlongRoute:(id)aRoute
{
	if ([aRoute intValue] == 0) {
		[_currentPanelController stopFlying];
		[_planeSound setDelegate:nil];
		[_planeSound stop];
		[[NSSound soundNamed:@"SamoletStart"] stop];
	} else {
		[_routeModeControl selectCellAtRow:0 column:0];
		[self routeModeChanged:_routeModeControl];
		[_currentPanelController startFlying];
		if (![Preferences playSoundOnRouteFly])
			return;
		[_planeSound play];
		[_planeSound setDelegate:(id)self];
		[[NSSound soundNamed:@"SamoletStart"] play];
	}
}

- (void)routeSetsAction:(id)aAction
{
	if ([aAction tag] == 3)
		[self newRouteInfo];
}

- (void)minimapAction:(id)aAction
{
	[self stopAnyFlying];
	[_currentPanelController worldRectChangedTo:[aAction worldRect]];
}

- (void)compassAction:(id)aAction
{
	int value;

	[self stopAnyFlying];
	value = [aAction intValue];
	[_compassButt setIntValue:value];
	[_compassButt2 setIntValue:value];
	[_currentPanelController compassValueChangedTo:value];
}

- (void)mouseBehaviourChanged:(id)aChanged
{
	NSInteger behaviour;

	_disableButtonsUpdate = YES;
	behaviour = [[_mouseBehaviuorMatrix selectedCell] tag];
	[Preferences setMouseBehaviourOnMap:behaviour];
	[self changeCursorWithKey:behaviour == 0 ? 0 : (behaviour == 2 ? 4 : 2)];
	[_glView setNeedsDisplay:YES];
	_disableButtonsUpdate = NO;
}

- (void)scaleButtonAction:(id)aAction
{
	[_scaleSlider setFloatValue:[aAction tag] == 0 ? 0.0f : 1.0f];
	[[_scaleSlider target] performSelector:[_scaleSlider action] withObject:_scaleSlider];
	[_currentPanelController setPosition:[_currentPanelController position]];
}

- (void)scaleWasChanged:(id)aChanged
{
	[self setScaleValue:[aChanged floatValue]];
	[_currentPanelController adjustToScale:_scaleValue];
	[[_currentPanelController scene] recalculateCountryHilite];
	[_glView setNeedsDisplay:YES];
}

- (void)routeModeChanged:(id)aChanged
{
	[Preferences setShowRouteLines:[aChanged selectedColumn]];
}

// Sets one draw option from a toolbar button (tag % 100) and keeps its twin
// in the other toolbar (the remote control) in step.
static void _syncToggle(id aSender, NSButton *aButton, NSButton *aTwin)
{
	[aButton setState:[aSender state]];
	[aTwin setState:[aSender state]];
}

static void _syncPopUp(id aSender, SMKBackgroundPopUpButton *aButton, SMKBackgroundPopUpButton *aTwin,
	RemoteControlController *aRemote, NSString *aOnImage, NSString *aOffImage, BOOL aOn)
{
	[aButton setState:[[aSender cell] state]];
	[[aButton cell] setDisplayedImage:[NSImage imageNamed:aOn ? aOnImage : aOffImage]];
	[aButton setNeedsDisplay:YES];
	[aTwin setState:[[aSender cell] state]];
	[[aTwin cell] setDisplayedImage:[aRemote buttonImageWithTag:[aTwin tag] isPressed:aOn]];
	[aTwin setNeedsDisplay:YES];
}

- (void)viewOptionsChanged:(id)aChanged
{
	BOOL on;

	_disableButtonsUpdate = YES;
	switch ([aChanged tag] % 100) {
	case 1:
		_syncToggle(aChanged, _dayNightButt, _dayNightButt2);
		[Preferences setDayNightEnabled:[aChanged state] == NSControlStateValueOn];
		break;
	case 2:
		on = [[aChanged cell] state] == NSControlStateValueOn;
		_syncPopUp(aChanged, _gridButt, _gridButt2, _remoteControlController, @"showgrid_s.tiff", @"grid.tiff", on);
		[Preferences setGridEnabled:on];
		break;
	case 3:
		on = [[aChanged cell] state] == NSControlStateValueOn;
		_syncPopUp(aChanged, _regionHltButt, _regionHltButt2, _remoteControlController, @"countries_s.tiff", @"countries.tiff", on);
		[Preferences setRegionHighlightEnabled:on];
		break;
	case 4:
		on = [[aChanged cell] state] == NSControlStateValueOn;
		_syncPopUp(aChanged, _cloudsButt, _cloudsButt2, _remoteControlController, @"clouds_s.tiff", @"clouds.tiff", on);
		[Preferences setCloudsEnabled:on];
		if (on)
			[_cloudsMaterial restoreAfterCleanup];
		else
			[_cloudsMaterial cleanup];
		break;
	case 5:
		[Preferences setDrawAllCities:[aChanged state] == NSControlStateValueOn];
		break;
	case 6:
		_syncToggle(aChanged, _nearestCityButt, _nearestCityButt2);
		[Preferences setNearestCityEnabled:[aChanged state] == NSControlStateValueOn];
		break;
	case 7:
		// space on restores the stars, moon and sun as they were (all on if that would leave nothing)
		if (![Preferences spaceEnabled]) {
			[Preferences setStarsEnabled:[Preferences previousStarsEnabled]];
			[Preferences setMoonEnabled:[Preferences previousMoonEnabled]];
			[Preferences setSunEnabled:[Preferences previousSunEnabled]];
			if ([Preferences spaceEnabled]) {
				[self _updateDrawOptionsButtons];
				break;
			}
			[Preferences setPreviousStarsEnabled:YES];
			[Preferences setPreviousMoonEnabled:YES];
			[Preferences setPreviousSunEnabled:YES];
			[Preferences setSpaceEnabled:YES];
		} else {
			[Preferences setPreviousStarsEnabled:[Preferences starsEnabled]];
			[Preferences setPreviousMoonEnabled:[Preferences moonEnabled]];
			[Preferences setPreviousSunEnabled:[Preferences sunEnabled]];
			[Preferences setSpaceEnabled:NO];
		}
		[self _updateDrawOptionsButtons];
		break;
	case 8:
		_syncToggle(aChanged, _citiesInfoButt, _citiesInfoButt2);
		if ([aChanged state] == NSControlStateValueOn)
			[_atlasController showCitiesInfoPalette:self];
		else
			[_atlasController hideCitiesInfoPalette:self];
		break;
	case 9:
		if ([aChanged state] == NSControlStateValueOn)
			[_optionsController showOptions];
		else
			[_optionsController hideOptions];
		_needRestoreDrawer = NO;
		break;
	case 10:
		[Preferences setShowTimeZoneEnabled:[aChanged state] == NSControlStateValueOn];
		break;
	}
	[_glView setNeedsDisplay:YES];
	_disableButtonsUpdate = NO;
}

- (void)viewModeChanged:(id)aChanged
{
	NSInteger mode = [aChanged selectedSegment];

	[_viewModeControl setSelectedSegment:mode];
	[_viewModeControl2 setSelectedSegment:mode];
	if (mode == 0)
		[self _openPanelWithControllerOfClass:[SphereMapController class]];
	else if (mode == 1)
		[self _openPanelWithControllerOfClass:[FlatMapController class]];
	[Preferences setMapMode:[self currentMapMode]];
}

// Each map controller is created once and kept in _allCreatedControllers.
- (void)_openPanelWithControllerOfClass:(Class)aClass
{
	NSInteger count, i;
	int compass;
	CGFloat scale;

	if ([_currentPanelController class] == aClass)
		return;
	[self stopAnyFlying];
	[_currentPanelController sceneWasUninstalled];
	[_currentPanelController release];
	_currentPanelController = nil;

	count = [_allCreatedControllers count];
	for (i = 0; i < count; i++) {
		if ([[_allCreatedControllers objectAtIndex:i] class] == aClass) {
			_currentPanelController = [[_allCreatedControllers objectAtIndex:i] retain];
			break;
		}
	}
	if (_currentPanelController == nil) {
		_currentPanelController = [[aClass alloc] initWithMainWindowController:self];
		[_allCreatedControllers addObject:_currentPanelController];
		_distCalcSetWasChangedForCurrentPanel = [_entriesOnMap count] != 0;
	}

	compass = [_currentPanelController compassValue];
	[_compassButt setIntValue:compass];
	[_compassButt2 setIntValue:compass];
	[self refreshAnimationFlag];
	[_currentPanelController sceneWillBeInstalled];
	[_glView setScene:[_currentPanelController scene]];
	[_glView setNeedsDisplay:YES];
	if (_distCalcSetWasChangedForCurrentPanel) {
		[_currentPanelController distCalcSetChangedTo:[self entriesOnMap]];
		_distCalcSetWasChangedForCurrentPanel = NO;
	}
	scale = [_currentPanelController defaultScale];
	if (scale < 0.0)
		scale = [_currentPanelController scale];
	else
		[_currentPanelController adjustToScale:scale];
	[self setScaleValue:scale];
	[self _updateDrawOptionsButtons];
	[_optionsController mainViewControllerClassWasChangedTo:aClass];
}

- (void)cityListDoubleAction:(id)aAction
{
	[FullCityInfoController showWithCityEntry:[_citiesListController selectedItem]];
}

- (void)cityListAction:(id)aAction
{
}

- (void)routeTableDoubleAction:(id)aAction
{
	NSInteger row = [_routeTabView clickedRow];
	id entry;

	if (row < 0)
		return;
	entry = [[self entriesOnMap] objectAtIndex:row];
	if (entry && [entry isKindOfClass:[AppleStoreEntry class]])
		[AppleStoreEditController showAppleStoreEditPanelWithEntry:entry mainController:self];
}

- (void)setDraggedEntries:(id)aEntries
{
	[aEntries retain];
	[_draggedEntries release];
	_draggedEntries = aEntries;
}

- (id)draggedEntries
{
	return _draggedEntries;
}

- (void)pasteboard:(id)aPasteboard provideDataForType:(id)aType
{
	[self provideCityEntriesDataForType:aType toPasteboard:aPasteboard];
}

- (void)deleteCitiesFromDistCalcList:(id)aList
{
	NSInteger count = [aList count], i;
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:count];

	for (i = 0; i < count; i++) {
		NSUInteger index = [_entriesOnMap indexOfObject:[aList objectAtIndex:i]];
		if (index != NSNotFound)
			[rows addObject:[NSNumber numberWithInteger:index]];
	}
	[self tableView:_routeTabView requestedToDeleteRows:rows];
}

static NSArray *_selectedRows(NSTableView *aTable)
{
	NSMutableArray *rows = [NSMutableArray array];
	NSIndexSet *indexes = [aTable selectedRowIndexes];
	NSUInteger index;

	for (index = [indexes firstIndex]; index != NSNotFound; index = [indexes indexGreaterThanIndex:index])
		[rows addObject:[NSNumber numberWithInteger:index]];
	return rows;
}

static void _selectRow(NSTableView *aTable, NSInteger aRow)
{
	if (aRow < 0)
		[aTable deselectAll:nil];
	else
		[aTable selectRowIndexes:[NSIndexSet indexSetWithIndex:aRow] byExtendingSelection:NO];
}

- (void)deleteSelectedEntryFromDistCalcList
{
	[self tableView:_routeTabView requestedToDeleteRows:_selectedRows(_routeTabView)];
}

- (void)tableView:(id)aView requestedToEditRows:(id)aRows
{
	if (aView != _routeTabView || [aRows count] != 1)
		return;
	[_routeTabView editColumn:[_routeTabView columnWithIdentifier:@"City"]
		row:[[aRows objectAtIndex:0] intValue] withEvent:nil select:YES];
}

- (void)tableView:(id)aView requestedToDeleteRows:(id)aRows
{
	NSInteger count, i, first = 0;
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];

	[self stopAnyFlying];
	count = [aRows count];
	for (i = 0; i < count; i++) {
		NSInteger row = [[aRows objectAtIndex:i] intValue];
		if (i == 0)
			first = row;
		[indexes addIndex:row];
	}
	[_entriesOnMap removeObjectsAtIndexes:indexes];
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = [[NSMutableSet alloc] initWithArray:_entriesOnMap];
	_selectRow(aView, -1);
	if (first == 0) {
		_selectRow(aView, 0);
		if ([_entriesOnMap count])
			[_currentPanelController setCurrentCity:[_entriesOnMap objectAtIndex:0]];
	} else {
		_selectRow(aView, first - 1);
	}
	[_citiesListController reloadTableData];
	count = [_entriesOnMap count];
	[self _adjustAllAfterMapCitiesContainerChange];
	_selectRow(_routeTabView, count - 1);
	[_routeTabView scrollRowToVisible:count - 1];
}

- (BOOL)tableView:(id)aView writeRows:(id)aRows toPasteboard:(id)aPasteboard
{
	NSInteger count = [aRows count], i;
	NSMutableArray *entries;
	NSArray *types;

	if (count < 1)
		return NO;
	entries = [NSMutableArray arrayWithCapacity:count];
	for (i = 0; i < count; i++)
		[entries addObject:[_entriesOnMap objectAtIndex:[[aRows objectAtIndex:i] intValue]]];
	types = [NSArray arrayWithObject:@"com.WorldBook2005.__selectedRowsArray_dist_calc_"];
	[self declareCitiesEntries:entries inPasteboard:aPasteboard withAdditionTypes:types];
	[aPasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:aRows]
		forType:@"com.WorldBook2005.__selectedRowsArray_dist_calc_"];
	return YES;
}

// current AppKit asks the index set version first
- (BOOL)tableView:(NSTableView *)aView writeRowsWithIndexes:(NSIndexSet *)aIndexes toPasteboard:(NSPasteboard *)aPasteboard
{
	NSMutableArray *rows = [NSMutableArray array];
	NSUInteger index;

	for (index = [aIndexes firstIndex]; index != NSNotFound; index = [aIndexes indexGreaterThanIndex:index])
		[rows addObject:[NSNumber numberWithInteger:index]];
	return [self tableView:aView writeRows:rows toPasteboard:aPasteboard];
}

// A drop from the route table itself moves the dragged rows to the drop row;
// anything else brings cities from the cities list.
- (BOOL)tableView:(id)aView acceptDrop:(id)aDrop row:(NSInteger)aRow dropOperation:(NSInteger)aOperation
{
	NSPasteboard *pasteboard = [aDrop draggingPasteboard];
	NSData *data = [pasteboard dataForType:@"com.WorldBook2005.__selectedRowsArray_dist_calc_"];

	if (data && [aDrop draggingSource] == aView) {
		NSArray *rows;
		NSMutableArray *entries;
		NSMutableData *flags;
		char *dragged;
		NSInteger count, total, i, last = 0;

		[self stopAnyFlying];
		rows = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		total = [_entriesOnMap count];
		entries = [[NSMutableArray alloc] initWithCapacity:total];
		flags = [NSMutableData dataWithLength:total];
		dragged = [flags mutableBytes];
		count = [rows count];
		for (i = 0; i < count; i++)
			dragged[[[rows objectAtIndex:i] intValue]] = 1;
		for (i = 0; i < aRow; i++)
			if (!dragged[i])
				[entries addObject:[_entriesOnMap objectAtIndex:i]];
		for (i = 0; i < count; i++) {
			[entries addObject:[_entriesOnMap objectAtIndex:[[rows objectAtIndex:i] intValue]]];
			if (i == count - 1)
				last = [entries count] - 1;
		}
		for (i = aRow; i < total; i++)
			if (!dragged[i])
				[entries addObject:[_entriesOnMap objectAtIndex:i]];
		[_entriesOnMap release];
		_entriesOnMap = entries;
		[_entriesOnMapAsSet release];
		_entriesOnMapAsSet = [[NSMutableSet alloc] initWithArray:_entriesOnMap];
		[aView reloadData];
		[self _adjustAllAfterMapCitiesContainerChange];
		[_routeTabView scrollRowToVisible:last];
		return YES;
	}
	[self putCitiesOnMapFromDescrArray:[pasteboard propertyListForType:kCitiesListPasteboardType] startingFromRow:aRow];
	return YES;
}

- (NSUInteger)tableView:(id)aView validateDrop:(id)aDrop proposedRow:(NSInteger)aRow proposedDropOperation:(NSInteger)aOperation
{
	NSInteger count = [_entriesOnMap count];

	if (count)
		[aView setDropRow:aRow < count ? aRow : count dropOperation:NSTableViewDropAbove];
	return [aDrop draggingSource] == aView ? NSDragOperationMove : NSDragOperationCopy;
}

// renaming a route entry replaces it with a new entry at the same point
- (void)tableView:(id)aView setObjectValue:(id)aValue forTableColumn:(id)aColumn row:(NSInteger)aRow
{
	id entry;

	if (aView != _routeTabView)
		return;
	entry = aRow < (NSInteger)[_entriesOnMap count] ? [_entriesOnMap objectAtIndex:aRow] : nil;
	if (![[aColumn identifier] isEqual:@"City"] || entry == nil)
		return;
	[self stopAnyFlying];
	if (![[entry shortCaption] isEqualToString:aValue]) {
		YACityEntry *renamed = [YACityEntry entryWithGeoPoint:[entry coordinates]];
		[renamed setShortCaption:aValue];
		[_entriesOnMap replaceObjectAtIndex:aRow withObject:renamed];
	}
	[self _adjustAllAfterMapCitiesContainerChange];
}

- (id)tableView:(id)aView objectValueForTableColumn:(id)aColumn row:(NSInteger)aRow
{
	id entry;

	if (aView != _routeTabView)
		return nil;
	entry = [_entriesOnMap objectAtIndex:aRow];
	if ([[aColumn identifier] isEqual:@"City"])
		return [entry shortCaption];
	if ([[aColumn identifier] isEqual:@"Distance"]) {
		BOOL metric;
		float distance;

		if (aRow == 0)
			return @"";
		metric = [Preferences usesMetricSystem];
		distance = [entry distanceToEntry:[_entriesOnMap objectAtIndex:aRow - 1]];
		if (!metric)
			distance = _milesFromKilometers(distance);
		return [NSString stringWithFormat:_localized(metric ? @"TotalDistanceKmFormat" : @"TotalDistanceMiFormat"), (double)distance];
	}
	return nil;
}

- (NSInteger)numberOfRowsInTableView:(id)aView
{
	if (aView == _routeTabView)
		return [_entriesOnMap count];
	return 0;
}

- (void)putCitiesOnMapFromDescrArray:(id)aArray startingFromRow:(NSInteger)aRow
{
	NSInteger count, i;
	NSMutableArray *entries;

	[self stopAnyFlying];
	count = [aArray count];
	if (count == 0) {
		[_entriesOnMap release];
		_entriesOnMap = nil;
		[_entriesOnMapAsSet release];
		_entriesOnMapAsSet = nil;
		[self _adjustAllAfterMapCitiesContainerChange];
		return;
	}
	entries = [NSMutableArray arrayWithCapacity:count];
	for (i = 0; i < count; i++) {
		id uid = [[aArray objectAtIndex:i] objectForKey:kCityEntryUID];
		id entry = [[AtlasDatabase database] dbEntryWithUID:uid];
		if (entry == nil)
			continue;
		if (aRow < 0) {
			NSInteger selected = [_routeTabView selectedRow];
			aRow = selected < 0 ? 0 : selected + 1;
		}
		[entries addObject:entry];
	}
	[self _appendCityEntries:entries toDistCalcListAfterRow:aRow];
}

// new entries go after a single selected row, else at the end
static NSInteger _insertionRow(NSTableView *aTable, NSArray *aEntries)
{
	if ([aTable numberOfSelectedRows] == 1)
		return [aTable selectedRow] + 1;
	return [aEntries count];
}

- (BOOL)appendCitiesToDistCalcList:(id)aList
{
	return [self _appendCityEntries:aList toDistCalcListAfterRow:_insertionRow(_routeTabView, _entriesOnMap)];
}

- (BOOL)appendCityToDistCalcList:(id)aList
{
	NSInteger row = _insertionRow(_routeTabView, _entriesOnMap);
	BOOL appended = [self _appendCityEntries:[NSArray arrayWithObject:aList] toDistCalcListAfterRow:row];

	if (appended)
		[self selectRouteEntryAt:row < (NSInteger)[_entriesOnMap count] ? row : row - 1];
	return appended;
}

- (void)selectRouteEntryAt:(NSInteger)aAt
{
	_disableAutoscrollOnListSelectionChange = YES;
	_selectRow(_routeTabView, aAt);
	[_routeTabView scrollRowToVisible:aAt];
	[_routeTabView setNeedsDisplay:YES];
	_disableAutoscrollOnListSelectionChange = NO;
}

- (id)entriesOnMap
{
	return _entriesOnMap;
}

// A route holds at most 200 entries.
- (BOOL)_appendCityEntries:(id)aEntries toDistCalcListAfterRow:(NSInteger)aRow
{
	NSUInteger count, existing, i, row, last = 0;

	[self stopAnyFlying];
	if ([aEntries count] + [_entriesOnMap count] > 200) {
		NSRunAlertPanel(_localized(@"Limit items number in rout. Main text."), @"%@", _localized(@"Ok"), nil, nil,
			[NSString stringWithFormat:_localized(@"Limit items number in rout. Informative text."), 200]);
		return NO;
	}
	count = [aEntries count];
	if (_entriesOnMap == nil)
		_entriesOnMap = [[NSMutableArray alloc] initWithCapacity:count];
	existing = [_entriesOnMap count];
	row = aRow;
	for (i = 0; i < count; i++, row++) {
		id entry = [aEntries objectAtIndex:i];
		// a negative row compares as huge, so it appends
		if ((NSUInteger)aRow < existing) {
			[_entriesOnMap insertObject:entry atIndex:row];
			if (i == count - 1)
				last = row;
		} else {
			[_entriesOnMap addObject:entry];
			if (i == count - 1)
				last = [_entriesOnMap count] - 1;
		}
	}
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = [[NSMutableSet alloc] initWithArray:_entriesOnMap];
	[self _adjustAllAfterMapCitiesContainerChange];
	[_routeTabView scrollRowToVisible:last];
	_disableAutoscrollOnListSelectionChange = YES;
	_selectRow(_routeTabView, last);
	_disableAutoscrollOnListSelectionChange = NO;
	return YES;
}

// keeps the cities list between its minimum and maximum width
- (void)splitView:(id)aView resizeSubviewsWithOldSize:(NSSize)aSize
{
	NSArray *subviews;
	NSView *list, *other;
	NSRect listFrame, otherFrame;
	CGFloat delta;

	if (NSEqualSizes([aView frame].size, aSize))
		return;
	[aView adjustSubviews];
	if (aView != _listWSGLViewSplitter)
		return;
	subviews = [aView subviews];
	list = [subviews objectAtIndex:0];
	listFrame = [list frame];
	if (listFrame.size.width < _minCitiesListWidth) {
		delta = _minCitiesListWidth - listFrame.size.width;
		listFrame.size.width = _minCitiesListWidth;
		[list setFrame:listFrame];
		other = [subviews objectAtIndex:1];
		otherFrame = [other frame];
		otherFrame.origin.x += delta;
		otherFrame.size.width -= delta;
	} else if (listFrame.size.width > _maxCitiesListWidth) {
		delta = listFrame.size.width - _maxCitiesListWidth;
		listFrame.size.width = _maxCitiesListWidth;
		[list setFrame:listFrame];
		other = [subviews objectAtIndex:1];
		otherFrame = [other frame];
		otherFrame.origin.x -= delta;
		otherFrame.size.width += delta;
	} else {
		return;
	}
	[other setFrame:otherFrame];
}

- (BOOL)splitView:(id)aView canCollapseSubview:(id)aSubview
{
	return aSubview == _distCalcFrame;
}

- (CGFloat)splitView:(id)aView constrainMaxCoordinate:(CGFloat)aCoordinate ofSubviewAt:(NSInteger)aAt
{
	if (aView == _citiesListSplitter)
		return [aView frame].size.height - 180.0;
	if (aView == _listWSGLViewSplitter)
		return _maxCitiesListWidth;
	return 10000.0;
}

- (CGFloat)splitView:(id)aView constrainMinCoordinate:(CGFloat)aCoordinate ofSubviewAt:(NSInteger)aAt
{
	if (aView == _citiesListSplitter)
		return 80.0;
	if (aView == _listWSGLViewSplitter)
		return _minCitiesListWidth;
	return 0.0;
}

// the marker column in the cities list adds a city to the route or removes it
- (BOOL)markerColumnAction:(id)aAction forCity:(id)aCity
{
	BOOL changed;

	if (aCity == nil)
		return NO;
	[self stopAnyFlying];
	if ([aAction intValue] == 0) {
		while ([_entriesOnMap containsObject:aCity])
			[_entriesOnMap removeObject:aCity];
		[_entriesOnMapAsSet removeObject:aCity];
		[self _adjustAllAfterMapCitiesContainerChange];
		changed = YES;
	} else {
		NSUInteger count;
		if (_entriesOnMap == nil)
			_entriesOnMap = [NSMutableArray new];
		if (_entriesOnMapAsSet == nil)
			_entriesOnMapAsSet = [NSMutableSet new];
		count = [_entriesOnMap count];
		[self appendCityToDistCalcList:aCity];
		changed = [_entriesOnMap count] != count;
	}
	[self _citiesListSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
		object:[_citiesListController citiesTableView]]];
	return changed;
}

- (void)_citiesListSelectionDidChange:(id)aChange
{
	id table, entry = nil;

	if (_disableAutoscrollOnListSelectionChange)
		return;
	table = [aChange object];
	if (table == [_citiesListController citiesTableView]) {
		entry = [_citiesListController selectedItem];
	} else if (table == _routeTabView) {
		NSInteger row = [table numberOfSelectedRows] > 1 ? -1 : [table selectedRow];
		NSInteger count = [_entriesOnMap count];

		if (row >= 0 && count > 0 && row < count) {
			entry = [_entriesOnMap objectAtIndex:row];
			if (entry && [entry isKindOfClass:[AppleStoreEntry class]] && [AppleStoreEditController isAppleStoreEditPanelVisible])
				[AppleStoreEditController showAppleStoreEditPanelWithEntry:entry mainController:self];
		}
	}
	if (entry != _previouslySelectedEntry)
		[_currentPanelController setCurrentCity:entry slideEntryToCenter:entry != nil];
	_previouslySelectedEntry = entry;
}

- (BOOL)cityIsMarked:(id)aMarked
{
	return [_entriesOnMapAsSet containsObject:aMarked];
}

- (BOOL)dragIsSupportedForController:(id)aController
{
	return YES;
}

// Every change to the route is undoable: the undo restores the previous entries.
- (void)_adjustAllAfterMapCitiesContainerChange
{
	[AppleStoreEditController hideAppleStoreEditPanel];
	[self _refreshInterfaceAfterMapCitiesContainerChange];
	if (![_previousEntriesOnMap isEqual:_entriesOnMap]) {
		NSArray *previous = _previousEntriesOnMap ? [NSArray arrayWithArray:_previousEntriesOnMap] : [NSArray array];
		NSUndoManager *undo = [[self mainWindow] undoManager];

		[undo registerUndoWithTarget:self selector:@selector(_applyRouteTableViewUndo:) object:previous];
		[undo setActionName:_localized(@"Route changing")];
		[_previousEntriesOnMap release];
		_previousEntriesOnMap = _entriesOnMap ? [[NSArray alloc] initWithArray:_entriesOnMap] : [[NSArray alloc] init];
	}
}

- (void)_applyRouteTableViewUndo:(id)aUndo
{
	NSArray *previous;

	[self stopAnyFlying];
	[_entriesOnMap release];
	_entriesOnMap = [[NSMutableArray alloc] initWithArray:aUndo];
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = [[NSMutableSet alloc] initWithArray:_entriesOnMap];
	previous = _previousEntriesOnMap ? [NSArray arrayWithArray:_previousEntriesOnMap] : [NSArray array];
	[[[self mainWindow] undoManager] registerUndoWithTarget:self selector:@selector(_applyRouteTableViewUndo:) object:previous];
	[_previousEntriesOnMap release];
	_previousEntriesOnMap = [[NSArray alloc] initWithArray:_entriesOnMap];
	[self _refreshInterfaceAfterMapCitiesContainerChange];
}

static NSString *_totalDistanceString(float aKilometers)
{
	BOOL metric = [Preferences usesMetricSystem];
	float distance = metric ? aKilometers : _milesFromKilometers(aKilometers);
	return [_localized(@"TotalDistance") stringByAppendingFormat:_localized(metric ? @"TotalDistanceKmFormat" : @"TotalDistanceMiFormat"), (double)distance];
}

- (void)_refreshInterfaceAfterMapCitiesContainerChange
{
	NSInteger count, i;
	id previous = nil;

	[_glView setNeedsDisplay:YES];
	[_routeTabView reloadData];
	[_citiesListController reloadTableData];
	[_currentPanelController distCalcSetChangedTo:[self entriesOnMap]];
	_distCalcSetWasChangedForCurrentPanel = YES;
	_totalDistance = 0.0f;
	count = [_entriesOnMap count];
	for (i = 0; i < count; i++) {
		id entry = [_entriesOnMap objectAtIndex:i];
		if (i > 0)
			_totalDistance += [previous distanceToEntry:entry];
		previous = entry;
	}
	[_totalDistanceText setStringValue:count < 2 ? @"" : _totalDistanceString(_totalDistance)];
	[_clearRouteButt setEnabled:count > 0];
	[_flyAlongRouteButton setEnabled:count > 1];
	[_routeModeControl setEnabled:count > 1];
	[self _adjustRouteModeControl];
}

- (void)refreshAnimationFlag
{
	[_glView refreshAutoAnimationFlag];
}

- (BOOL)requiresAnimation
{
	return [_currentPanelController requiresAnimation];
}

- (BOOL)showsApples
{
	return [Preferences showAppleStores];
}

- (void)setShowApples:(BOOL)aApples
{
	[Preferences setShowAppleStores:aApples];
	[[[self currentPanelController] scene] highlightAppleStore:nil hiliteColor:nil];
	[AppleStoreInfoPaletteController hideAppleStoresInfo];
	[self changeCursorWithKey:2];
	[_glView setNeedsDisplay:YES];
}

- (void)setMinimapWorldRect:(NSRect)aRect
{
	[_minimapCell setWorldRect:aRect];
	if ([_minimapCell controlView] == nil)
		[_minimapView setNeedsDisplay:YES];
}

- (id)zoomingSliders
{
	return [NSArray arrayWithObjects:_scaleSlider, _scaleSlider2, nil];
}

- (void)setScaleValue:(CGFloat)aValue
{
	[_scaleSlider setFloatValue:aValue];
	[_scaleSlider2 setFloatValue:aValue];
	_scaleValue = [_scaleSlider floatValue];
	[_glView setNeedsDisplay:YES];
}

- (CGFloat)scaleValue
{
	return _scaleValue;
}

// 0 globe, 1 flat map
- (NSInteger)currentMapMode
{
	return ![[self currentPanelController] isKindOfClass:[SphereMapController class]];
}

- (id)infoDrawerController
{
	if (_infoDrawerController == nil)
		_infoDrawerController = [[InfoDrawerController alloc] init];
	return _infoDrawerController;
}

- (id)currentPanelController
{
	return _currentPanelController;
}

- (id)compassButton2
{
	return _compassButt2;
}

- (id)compassButton
{
	return _compassButt;
}

- (id)glView
{
	return _glView;
}

- (id)cloudsMaterial
{
	return _cloudsMaterial;
}

- (id)mapPartsLoader
{
	return _loader;
}

- (id)mainListController
{
	return _citiesListController;
}

- (id)mainWindow
{
	return _mainWindow;
}

- (id)atlasController
{
	return _atlasController;
}

- (void)_globeTranspWasChanged:(id)aChanged
{
	[_glView setNeedsDisplay:YES];
}

- (void)drawerStateDidChange:(id)aChange
{
	[_optionsButt setState:[_optionsController drawerIsOpenState]];
}

- (void)_unitsOfMeasureWereChanged:(id)aChanged
{
	[_routeTabView reloadData];
	if ([[_totalDistanceText stringValue] length])
		[_totalDistanceText setStringValue:_totalDistanceString(_totalDistance)];
}

- (void)_prefsWereChanged:(id)aChanged
{
	if (_disableButtonsUpdate)
		return;
	[self _updateDrawOptionsButtons];
	[_glView setNeedsDisplay:YES];
}

// the route is kept for the next launch when "retain last view" is on
static NSArray *_routeToRetain(NSArray *aEntries)
{
	NSInteger count = [aEntries count], i;
	NSMutableArray *route;

	if (![Preferences retainLastView] || count < 1)
		return nil;
	route = [NSMutableArray array];
	for (i = 0; i < count; i++)
		[route addObject:[[aEntries objectAtIndex:i] entryDictionary]];
	return route;
}

- (void)_windowWillBeClosed:(id)aClosed
{
	[Preferences setShowMainWindow:NO];
	[Preferences setLastRoute:_routeToRetain(_entriesOnMap)];
	[self _cleanupOnWindowClose];
}

- (void)_textureWasLoaded:(id)aLoaded
{
	[_glView setNeedsDisplay:YES];
}

- (void)_loadNibIfNeeded
{
	NSAutoreleasePool *pool;

	if (_nibWasLoaded)
		return;
	pool = [NSAutoreleasePool new];
	[NSBundle loadNibNamed:@"MainWindow" owner:self];
	_nibWasLoaded = YES;
	_isInFullWindowMode = NO;
	[pool release];
}

- (void)dealloc
{
	[_glView setMainWindowController:nil];
	if ([_mainWindow isVisible])
		[Preferences setLastRoute:_routeToRetain(_entriesOnMap)];
	[self _cleanupOnWindowClose];
	[_cloudsMaterial release];
	_cloudsMaterial = nil;
	[_citiesListController release];
	[_listWSGLViewSplitter release];
	[_bottomControlsContainer release];
	[_entriesOnMap release];
	[_entriesOnMapAsSet release];
	[_draggedEntries release];
	[_smallFont release];
	[_normalFont release];
	[_largeFont release];
	[_txtBackground release];
	[_weatherIconsTexture release];
	[_appleStoreEntries release];
	[_normalAppleStoreEntries release];
	[_miniAppleStoreEntries release];
	[_openingAppleStoreEntries release];
	[_currentRoutePath release];
	[_printController release];
	[_infoDrawerController release];
	[_handOpenCursor release];
	[_handCloseCursor release];
	[_zoomInCursor release];
	[_zoomOutCursor release];
	[_pushPinCursor release];
	[_appleStoreCursor release];
	[_planeSound release];
	[super dealloc];
}

- (void)awakeFromNib
{
	NSScreen *screen;
	NSRect visible, frame;
	NSNotificationCenter *center;

	_fitClippedLabels([[_mainWindow contentView] superview]);
	[_routeModeControl setEnabled:NO];
	[self _adjustRouteModeControl];
	[self setScaleValue:0.33f];
	[self _updateDrawOptionsButtons];
	[self _updateMouseBehaviourButtons];
	[self _setImagesForRemoteControlButton:_dayNightButt2];
	[self _setImagesForRemoteControlButton:_regionHltButt2];
	[self _setImagesForRemoteControlButton:_nearestCityButt2];
	[self _setImagesForRemoteControlButton:_citiesInfoButt2];
	[[_gridButt2 cell] setDrawsArrow:NO];
	[[_cloudsButt2 cell] setDrawsArrow:NO];
	[[_regionHltButt2 cell] setDrawsArrow:NO];
	[_compassButt setIntValue:3];
	[_compassButt2 setIntValue:3];
	[_distCalcFrame setDrawBackground:YES];

	_minimapCell = [[[MinimapCell alloc] initWithImage:[[_minimapView cell] image]] autorelease];
	[_minimapCell setTarget:self];
	[_minimapCell setAction:@selector(minimapAction:)];
	[_minimapView setCell:_minimapCell];
	[_minimapView setNeedsDisplay:YES];

	[[_citiesListController citiesTableView] setDoubleAction:@selector(cityListDoubleAction:)];
	center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_citiesListSelectionDidChange:)
		name:NSTableViewSelectionDidChangeNotification object:[_citiesListController citiesTableView]];
	[center addObserver:self selector:@selector(_citiesListSelectionDidChange:)
		name:NSTableViewSelectionDidChangeNotification object:_routeTabView];
	[center addObserver:self selector:@selector(_unitsOfMeasureWereChanged:) name:kUnitsOfMeasureWereChanged object:nil];

	// the status line is kept out of the window until something is loading
	[_statusText setStringValue:@""];
	[_progressIndicator setDisplayedWhenStopped:NO];
	[[_progressIndicator retain] removeFromSuperview];
	[[_statusText retain] removeFromSuperview];
	[_routeTabView registerForDraggedTypes:[NSArray arrayWithObjects:kCitiesListPasteboardType,
		@"com.WorldBook2005.__selectedRowsArray_dist_calc_", nil]];

	// fit the window on its screen; the first launch zooms it to most of the screen
	screen = [_mainWindow screen];
	if (screen == nil)
		screen = [NSScreen mainScreen];
	visible = [screen visibleFrame];
	frame = [_mainWindow frame];
	if (frame.size.width > visible.size.width) {
		frame.size.width = visible.size.width;
		frame.origin.x = visible.origin.x;
	}
	if (frame.size.height > visible.size.height) {
		frame.origin.y += frame.size.height - visible.size.height;
		frame.size.height = visible.size.height;
	}
	if ([Preferences shouldZoomMainWindow]) {
		CGFloat dx = visible.size.width - 1024.0f, dy = visible.size.height - 768.0f;
		NSRect zoomed = NSInsetRect(visible, dx < 0.0 ? 0.0 : dx * 0.3f, dy < 0.0 ? 0.0 : dy * 0.3f);
		if (!NSEqualSizes(zoomed.size, [_mainWindow frame].size))
			[_mainWindow setFrame:zoomed display:YES];
		[Preferences setZoomMainWindow:NO];
	} else {
		[_mainWindow setFrame:frame display:YES];
	}

	// full window mode takes these out of the window, so they're kept
	[_listWSGLViewSplitter retain];
	[_bottomControlsContainer retain];
	_fullWindowGLViewOrigin = [_listWSGLViewSplitter convertPoint:[_citiesListContainer frame].origin toView:[_mainWindow contentView]];
	_fullWindowGLViewOrigin.y = [_bottomControlsContainer frame].origin.y;
	[_routeTabView setDoubleAction:@selector(routeTableDoubleAction:)];
	if ([_citiesListContextMenu numberOfItems] == 5 && [[AtlasController atlasController] isBoxVersion]) {
		[_citiesListContextMenu removeItemAtIndex:2];
		[_citiesListContextMenu removeItemAtIndex:2];
		[_citiesListContextMenu removeItemAtIndex:2];
	}
	[_totalDistanceText setStringValue:@""];
	[self reloadRouteButtonMenu];
	[self stopAnyFlying];
}

- (id)initWithAtlasController:(id)aController
{
	self = [super init];
	if (self) {
		_atlasController = aController;
		_maxCitiesListWidth = 470;
		_minCitiesListWidth = 244;
		_planeSound = [[NSSound soundNamed:@"SamaletFly"] retain];
	}
	return self;
}

- (void)_setImagesForRemoteControlButton:(id)aButton
{
	[aButton setImage:[_remoteControlController buttonImageWithTag:[aButton tag] isPressed:NO]];
	[aButton setAlternateImage:[_remoteControlController buttonImageWithTag:[aButton tag] isPressed:YES]];
}

- (void)_updateMouseBehaviourButtons
{
	[_mouseBehaviuorMatrix selectCellWithTag:[Preferences mouseBehaviourOnMap]];
}

static void _updatePopUp(SMKBackgroundPopUpButton *aButton, SMKBackgroundPopUpButton *aTwin,
	RemoteControlController *aRemote, NSString *aOnImage, NSString *aOffImage, BOOL aOn)
{
	[aButton setState:aOn];
	[[aButton cell] setDisplayedImage:[NSImage imageNamed:aOn ? aOnImage : aOffImage]];
	[aButton setNeedsDisplay:YES];
	[aTwin setState:aOn];
	[[aTwin cell] setDisplayedImage:[aRemote buttonImageWithTag:[aTwin tag] isPressed:aOn]];
	[aTwin setNeedsDisplay:YES];
}

- (void)_updateDrawOptionsButtons
{
	[_spaceButt setState:[Preferences spaceEnabled]];
	[[_spaceButt cell] setDisplayedImage:[NSImage imageNamed:[Preferences spaceEnabled] ? @"SunMoon3_on.tif" : @"SunMoon3_off.tif"]];
	[_spaceButt setEnabled:[[self currentPanelController] class] == [SphereMapController class]];
	[_dayNightButt setState:[Preferences dayNightIsEnabled]];
	[_dayNightButt2 setState:[_dayNightButt state]];
	_updatePopUp(_gridButt, _gridButt2, _remoteControlController, @"showgrid_s.tiff", @"grid.tiff", [Preferences gridEnabled]);
	_updatePopUp(_regionHltButt, _regionHltButt2, _remoteControlController, @"countries_s.tiff", @"countries.tiff",
		[Preferences regionHighlightIsEnabled]);
	_updatePopUp(_cloudsButt, _cloudsButt2, _remoteControlController, @"clouds_s.tiff", @"clouds.tiff", [Preferences cloudsEnabled]);
	[_nearestCityButt setState:[Preferences nearestCityEnabled]];
	[_nearestCityButt2 setState:[_nearestCityButt state]];
	[_allCitiesButt setState:[Preferences doDrawAllCities]];
	[_optionsButt setState:[_optionsController drawerIsOpenState]];
	[_timezonesButt setState:[Preferences showTimeZoneEnabled]];
	[_citiesInfoButt setState:[Preferences doShowWeatherOnStartup]];
	[_citiesInfoButt2 setState:[_citiesInfoButt state]];
}

// column 0 shows the route lines, column 1 hides them; nothing is selected while disabled
- (void)_adjustRouteModeControl
{
	[_routeModeControl setAllowsEmptySelection:YES];
	[_routeModeControl deselectAllCells];
	if ([_routeModeControl isEnabled]) {
		[_routeModeControl setAllowsEmptySelection:NO];
		[_routeModeControl selectCellAtRow:0 column:1 - [Preferences showRouteLines]];
	}
}

- (void)_restoreBeforeWindowShow
{
	NSNotificationCenter *center;

	if (_wasRestored)
		return;
	_wasRestored = YES;
	_allCreatedControllers = [NSMutableArray new];
	if (_loader == nil)
		_loader = [MapPartsLoader new];
	if ([Preferences cloudsEnabled]) {
		[CWManager scheduleCloudsUpdateTask];
		if (![Preferences usesInternet])
			[[CWManager cloudsManager] restoreAfterCleanup];
	}
	if (_cloudsMaterial == nil)
		_cloudsMaterial = [[CloudsMaterial alloc] initWithContainer:[_glView objectsContainer] cloudsManager:[CWManager cloudsManager]];
	if (_countryHiliterTexturesStorage == nil)
		_countryHiliterTexturesStorage = [[CountryHiliterTexturesStorage alloc] initWithContainer:[_glView objectsContainer]];
	center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(_textureWasLoaded:) name:kMapPartWasLoadedNotification object:_loader];
	[center addObserver:self selector:@selector(_windowWillBeClosed:) name:NSWindowWillCloseNotification object:_mainWindow];
	[center addObserver:self selector:@selector(_prefsWereChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
	[center addObserver:self selector:@selector(drawerStateDidChange:) name:NSDrawerDidCloseNotification object:nil];
	[center addObserver:self selector:@selector(drawerStateDidChange:) name:NSDrawerDidOpenNotification object:nil];
	[center addObserver:self selector:@selector(_globeTranspWasChanged:) name:kGlobeTransparencyWasChanged object:nil];
	[_glView setMainWindowController:self];
}

// Closing the window throws away everything the nib and the scenes made;
// showWindow loads it all again.
- (void)_cleanupOnWindowClose
{
	NSTableView *citiesTable;

	[_optionsController hideOptions];
	[_optionsController forceRestoreParentWindowFrame];
	[self stopAnyFlying];
	_flyAlongRouteButton = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_currentPanelController sceneWasUninstalled];
	[_currentPanelController invalidate];
	[_allCreatedControllers release];
	[_loader invalidate];
	[_cloudsMaterial release];
	_cloudsMaterial = nil;
	[CWManager unscheduleCloudsUpdateTask];
	[_countryHiliterTexturesStorage release];
	_countryHiliterTexturesStorage = nil;
	[_remoteControlController release];
	_remoteControlController = nil;
	[_infoDrawerController release];
	_infoDrawerController = nil;
	[_listWSGLViewSplitter release];
	_listWSGLViewSplitter = nil;
	[_bottomControlsContainer release];
	_bottomControlsContainer = nil;
	citiesTable = [_citiesListController citiesTableView];
	[citiesTable setDoubleAction:NULL];
	[citiesTable setDataSource:nil];
	[citiesTable setDelegate:nil];
	[_citiesListController release];
	_citiesListController = nil;
	[_routeTabView setDataSource:nil];
	[_routeTabView setDelegate:nil];
	[_mainWindow autorelease];
	_mainWindow = nil;
	_nibWasLoaded = NO;
	[_routeContextMenu release];
	_routeContextMenu = nil;
	[_atlasContextMenu release];
	_atlasContextMenu = nil;
	[_citiesListContextMenu release];
	_citiesListContextMenu = nil;
	_currentPanelController = nil;
	_allCreatedControllers = nil;
	_loader = nil;
	_wasRestored = NO;
	[_entriesOnMap release];
	_entriesOnMap = nil;
	[_entriesOnMapAsSet release];
	_entriesOnMapAsSet = nil;
	[_entriesToRevert release];
	_entriesToRevert = nil;
	[_glView cleanupOnWindowClose];
	[_glView setScene:nil];
	[_optionsController release];
	_optionsController = nil;
	[_draggedEntries release];
	_draggedEntries = nil;
	[_smallFont release];
	[_normalFont release];
	[_largeFont release];
	[_txtBackground release];
	[_weatherIconsTexture release];
	_smallFont = nil;
	_normalFont = nil;
	_largeFont = nil;
	_txtBackground = nil;
	_weatherIconsTexture = nil;
	[_printController autorelease];
	_printController = nil;
	[_currentRoutePath release];
	_currentRoutePath = nil;
	[_progressIndicator release];
	_progressIndicator = nil;
	[_statusText release];
	_statusText = nil;
	_glView = nil;
	_compassButt = nil;
	_compassButt2 = nil;
	_minimapView = nil;
	_minimapCell = nil;
	_dayNightButt = nil;
	_dayNightButt2 = nil;
	_spaceButt = nil;
	_gridButt = nil;
	_gridButt2 = nil;
	_regionHltButt = nil;
	_regionHltButt2 = nil;
	_citiesInfoButt = nil;
	_citiesInfoButt2 = nil;
	_cloudsButt = nil;
	_cloudsButt2 = nil;
	_allCitiesButt = nil;
	_nearestCityButt = nil;
	_nearestCityButt2 = nil;
	_timezonesButt = nil;
	_mouseBehaviuorMatrix = nil;
	_routeTabView = nil;
	_scaleSlider = nil;
	_scaleSlider2 = nil;
	_viewModeControl = nil;
	_viewModeControl2 = nil;
	_routeModeControl = nil;
	[_highlightedCity release];
	_highlightedCity = nil;
	[[AtlasDatabase database] cleanupOnWindowClose];
}

- (void)stopAnyFlying
{
	if ([_flyAlongRouteButton intValue]) {
		[_flyAlongRouteButton setIntValue:0];
		[self flyAlongRoute:_flyAlongRouteButton];
	}
	[_flyAlongRouteButton setEnabled:[_entriesOnMap count] > 1];
}

- (BOOL)isFlying
{
	return [_flyAlongRouteButton intValue] != 0;
}

@end

@implementation MainWindow

// Command-Option-F focuses the search field; Tab and Shift-Tab leave the map view.
- (void)sendEvent:(id)aEvent
{
	if ([(NSEvent *)aEvent type] == NSEventTypeKeyDown) {
		NSString *characters = [aEvent charactersIgnoringModifiers];
		NSUInteger optionCommand = NSEventModifierFlagOption | NSEventModifierFlagCommand;

		if (([characters isEqualToString:@"f"] || [characters isEqualToString:@"F"])
				&& ([aEvent modifierFlags] & optionCommand) == optionCommand && [_searchField window] == self) {
			[self makeFirstResponder:_searchField];
			return;
		}
		if ([aEvent keyCode] == 0x30) {
			id responder = [self firstResponder];
			NSUInteger flags = [aEvent modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagOption);

			if ([responder isKindOfClass:[AtlasGLView class]] && (flags == 0 || flags == NSEventModifierFlagShift)) {
				id next = flags == 0 ? [responder nextValidKeyView] : [responder previousValidKeyView];
				if (next) {
					[self makeFirstResponder:next];
					return;
				}
			}
		}
	}
	[super sendEvent:aEvent];
}

// a sheet's own undo manager wins while it is up
- (void)redo:(id)aRedo
{
	NSWindow *window = [self attachedSheet] ? [self attachedSheet] : self;
	NSUndoManager *undo = [window undoManager];

	if (undo && [undo canRedo])
		[undo redo];
}

- (void)undo:(id)aUndo
{
	NSWindow *window = [self attachedSheet] ? [self attachedSheet] : self;
	NSUndoManager *undo = [window undoManager];

	if (undo && [undo canUndo])
		[undo undo];
}

- (BOOL)validateMenuItem:(id)aItem
{
	SEL action = [aItem action];
	BOOL valid = [super validateMenuItem:aItem];
	NSWindow *sheet = [self attachedSheet];
	NSUndoManager *undo;

	if (sheet == nil)
		return valid;
	undo = [sheet undoManager];
	if (action == @selector(undo:)) {
		valid = [undo canUndo];
		[aItem setTitleWithMnemonic:[undo undoMenuItemTitle]];
	} else if (action == @selector(redo:)) {
		valid = [undo canRedo];
		[aItem setTitleWithMnemonic:[undo redoMenuItemTitle]];
	}
	return valid;
}

// grows the window to its minimum size downwards, without the screen constraint
- (NSRect)constrainFrameRect:(NSRect)aRect toScreen:(id)aScreen
{
	NSSize minimum = [self minSize];

	if (aRect.size.height < minimum.height) {
		aRect.origin.y -= minimum.height - aRect.size.height;
		aRect.size.height = minimum.height;
	}
	if (aRect.size.width < minimum.width)
		aRect.size.width = minimum.width;
	return aRect;
}

@end
