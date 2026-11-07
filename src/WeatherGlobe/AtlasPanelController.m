#import "AtlasPanelController.h"

static id _sCurrentCity = nil;
static struct WeatherGlobe_anon7 _hiliteYellow = { 1.0f, 1.0f, 0.0f, 1.0f };

static NSString *_preferenceKey(id anObject, NSString *aSuffix)
{
	return [NSString stringWithFormat:@"%@_%@", NSStringFromClass([anObject class]), aSuffix];
}

@implementation AtlasPanelController

- (void)calculateAutoMoveSpeedForFlyToPosition:(NSPoint)aPosition
{
	CGFloat dx = aPosition.x - _position.x;
	CGFloat wrapDx = (1.0 - aPosition.x) + _position.x;
	CGFloat dy;
	if (fabs(dx) > fabs(wrapDx))
		dx = wrapDx;
	dy = aPosition.y - _position.y;
	if (dx == 0.0) {
		_automoveSpeed.x = 0.0;
		_automoveSpeed.y = 0.03;
	} else if (dy == 0.0) {
		_automoveSpeed.x = 0.04;
		_automoveSpeed.y = 0.0;
	} else {
		CGFloat len = sqrt(dy * dy + dx * dx);
		_automoveSpeed.x = (dx * 0.35) / len;
		_automoveSpeed.y = (dy * 0.35) / len;
	}
}

- (CGFloat)precisionForEntryMarker
{
	return 0.0;
}

- (NSPoint)captionPositionForEntryAtIndex:(NSInteger)aIndex
{
	NSArray *entries = [self routeEntries];
	if (aIndex >= 0 && (NSUInteger)aIndex < [entries count])
		return _mapPointFromGeoPoint([[entries objectAtIndex:aIndex] coordinates]);
	return NSZeroPoint;
}

- (id)routeEntries
{
	return [[self windowController] entriesOnMap];
}

- (void)distCalcSetChangedTo:(id)aTo
{
	[[self scene] distCalcSetChangedTo:aTo];
}

- (void)setCorrectCursor:(id)aCursor
{
	NSUInteger flags = aCursor ? [aCursor modifierFlags] : _lastModifiersFlags;
	BOOL command, option;
	MainWindowController *controller;
	NSInteger behaviour, key;

	if (_mouseIsDown) {
		command = _commandOnMouseDown;
		option = _optionOnMouseDown;
	} else {
		command = (flags & NSEventModifierFlagCommand) != 0;
		option = (flags & NSEventModifierFlagOption) != 0;
	}
	controller = [self windowController];
	behaviour = [Preferences mouseBehaviourOnMap];

	if (command) {
		if (behaviour == 0)
			key = _mouseIsDown ? 3 : 2;
		else if (behaviour == 1)
			key = [[self scene] highlightedAppleStore] ? 5 : (option ? 1 : 0);
		else if (behaviour == 2)
			key = option ? 1 : 0;
		else
			return;
	} else {
		if (behaviour == 0)
			key = option ? 1 : 0;
		else if (behaviour == 1)
			key = [[self scene] highlightedAppleStore] ? 5 : (option ? 1 : 2);
		else if (behaviour == 2)
			key = 4;
		else
			return;
	}
	[controller changeCursorWithKey:key];
}

- (void)zoomToSelectionRect:(NSRect)aRect
{
}

- (void)zoomOutToGeoPoint:(NSPoint)aPoint
{
}

- (void)zoomInToGeoPoint:(NSPoint)aPoint
{
}

- (void)stopFlying
{
	_isFlying = NO;
	[self _setupTimer];
	[[[self scene] routePointsContainer] stopFlying];
}

- (void)startFlying
{
	[[_controller compassButton] setIntValue:0];
	[[_controller compassButton2] setIntValue:0];
	[self compassValueChangedTo:0];
	_slidingIsActive = NO;
	_postmoveIsActive = NO;
	_automoveIsActive = NO;
	_lastRecacheTime = 0.0;
	_isFlying = YES;
	[self _setupTimer];
	[[[self scene] routePointsContainer] startFlying];
	_prevFlyingTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)changeSelectionRect:(NSRect)aRect
{
	[[self scene] setSelectionVisible:YES];
	[(BaseAtlasScene *)[self scene] setSelectionRect:aRect];
}

- (void)recacheAll
{
}

- (void)recacheNeighborsOnly
{
}

- (void)refreshCameraSettings
{
	if (_autoselectedCountryUID == nil && _autoselectedStateUID == nil && _autoselectedTimeZoneUID == nil
		&& [NSApp isActive] && !_mouseIsDown) {
		NSPoint location = [NSEvent mouseLocation];
		MainWindowController *controller = [self windowController];
		NSView *glView;
		NSRect frame;
		NSPoint geoPoint;

		location = [[controller mainWindow] convertPointFromScreen:location];
		glView = [controller glView];
		location = [glView convertPoint:location fromView:nil];
		frame = [glView frame];
		if ([self canConvertNormalizedViewPoint:NSMakePoint(location.x / frame.size.width, location.y / frame.size.height)
									 toGeoPoint:&geoPoint])
			[self mousePositionChanged:geoPoint event:nil countryHightlight:NO];
	}
}

- (void)zoomToCurrentCountry
{
}

- (void)concludeDragOperation:(id)aOperation
{
	id descriptions;
	[[self scene] dragConcludedWithAllEntries];
	descriptions = [[aOperation draggingPasteboard] propertyListForType:kCitiesListPasteboardType];
	[[self windowController] putCitiesOnMapFromDescrArray:descriptions startingFromRow:-1];
}

- (void)draggingExited:(id)aExited
{
	[[self scene] dragExitedWithAllEntries];
}

- (NSUInteger)draggingUpdated:(id)aUpdated
{
	return NSDragOperationCopy;
}

- (NSUInteger)draggingEntered:(id)aEntered
{
	id descriptions;
	[_controller stopAnyFlying];
	descriptions = [[aEntered draggingPasteboard] propertyListForType:kCitiesListPasteboardType];
	[[self scene] dragBringsEntries:descriptions];
	return NSDragOperationCopy;
}

- (void)flagsChanged:(id)aChanged inView:(id)aView
{
	[self setCorrectCursor:aChanged];
	_lastModifiersFlags = (unsigned int)[aChanged modifierFlags];
}

- (void)keyUp:(id)aUp inView:(id)aView
{
}

- (void)keyDown:(id)aDown inView:(id)aView
{
	NSString *characters = [aDown charactersIgnoringModifiers];
	unichar c;

	if ([characters length] != 1)
		return;
	c = [characters characterAtIndex:0];
	if (c == 0x7f || c == NSDeleteFunctionKey) {
		[[self windowController] deleteSelectedEntryFromDistCalcList];
	} else if (c == 0x1b && [[self scene] selectionVisible]) {
		_selectionWasCanceled = YES;
		[[self scene] setSelectionVisible:NO];
		[self setCorrectCursor:aDown];
	}
}

- (BOOL)acceptsFirstResponderInView:(id)aView
{
	return YES;
}

- (void)_finilizeScrollWheel:(id)aWheel
{
	_scrollDelayedPerformer = nil;
	[self scrollWithDiff:_scrollDiff fromViewPoint:_scrollViewPt];
	_scrollDiff = NSZeroPoint;
}

- (void)scrollWheel:(id)aWheel inView:(id)aView
{
	NSTimeInterval timestamp, now;

	if (_mouseIsDown || _scaleTimer != nil)
		return;
	timestamp = [(NSEvent *)aWheel timestamp];
	now = [NSDate timeIntervalSinceReferenceDate];
	[_controller stopAnyFlying];
	_scrollDiff.x += [aWheel deltaX];
	_scrollDiff.y += [aWheel deltaY];
	_scrollViewPt = [aView convertPoint:[aWheel locationInWindow] fromView:nil];
	[_scrollDelayedPerformer invalidate];
	_scrollDelayedPerformer = nil;
	if (round((timestamp - _lastScrollTimestamp) * 100.0) != round((now - _lastScrollTimeInterval) * 100.0)) {
		[[aView window] setViewsNeedDisplay:NO];
		_scrollDelayedPerformer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self
			selector:@selector(_finilizeScrollWheel:) userInfo:nil repeats:NO];
	} else {
		[self scrollWithDiff:_scrollDiff fromViewPoint:_scrollViewPt];
		_scrollDiff = NSZeroPoint;
	}
	_lastScrollTimestamp = timestamp;
	_lastScrollTimeInterval = now;
}

- (void)mouseDragged:(id)aDragged inView:(id)aView
{
	NSPoint point;

	if (!_mouseIsDown)
		return;
	point = [aView convertPoint:[aDragged locationInWindow] fromView:nil];
	if (!_mouseWasDragged) {
		[self startTrackingAtViewPoint:_downLocation];
		_mouseWasDragged = YES;
	}
	[self trackToViewPoint:point];
}

- (void)mouseUp:(id)aUp inView:(id)aView
{
	if (_mouseIsDown) {
		NSPoint point;
		NSInteger clicks;

		_mouseIsDown = NO;
		[[self scene] setSelectionVisible:NO];
		point = [aView convertPoint:[aUp locationInWindow] fromView:nil];
		if (_mouseWasDragged) {
			[self endTrackingAtViewPoint:point];
		} else {
			clicks = [aUp clickCount];
			if (clicks == 1) {
				if (_firstClickDelayedPerformer != nil) {
					[_firstClickDelayedPerformer invalidate];
					_firstClickDelayedPerformer = nil;
				}
				_firstClickDelayedPerformer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self
					selector:@selector(_timerOnFirstClickProcess:) userInfo:[aUp retain] repeats:NO];
			} else {
				[_firstClickDelayedPerformer invalidate];
				_firstClickDelayedPerformer = nil;
				if (clicks == 2) {
					NSRect frame = [aView frame];
					NSPoint geoPoint;
					if ([self canConvertNormalizedViewPoint:NSMakePoint(point.x / frame.size.width, point.y / frame.size.height)
												 toGeoPoint:&geoPoint])
						[self doubleActionOnGeoPoint:geoPoint];
				}
			}
		}
	}
	[self setCorrectCursor:aUp];
}

- (void)mouseDown:(id)aDown inView:(id)aView
{
	NSUInteger flags;

	[_controller stopAnyFlying];
	if (_scaleTimer != nil)
		return;
	_mouseWasDragged = NO;
	_selectionWasCanceled = NO;
	_mouseIsDown = YES;
	flags = [aDown modifierFlags];
	_ctrlOnMouseDown = (flags & NSEventModifierFlagControl) != 0;
	_commandOnMouseDown = (flags & NSEventModifierFlagCommand) != 0;
	_optionOnMouseDown = (flags & NSEventModifierFlagOption) != 0;
	_downLocation = [aView convertPoint:[aDown locationInWindow] fromView:nil];
	[self setCorrectCursor:aDown];
}

- (void)mouseExited:(id)aExited inView:(id)aView
{
	_mouseIsInside = NO;
	[self _disableCountryHighlight];
	[[self scene] highlightCity:_sCurrentCity];
	[self refreshView];
}

- (void)mouseEntered:(id)aEntered inView:(id)aView
{
	_mouseIsInside = YES;
	[self refreshView];
}

- (void)mouseMoved:(id)aMoved inView:(id)aView
{
	static BOOL _needToCallMouseLost = NO;
	NSPoint point, geoPoint;
	NSRect bounds;

	if (_firstClickDelayedPerformer != nil) {
		[self _firstClickProcess:aMoved];
		return;
	}
	if (_scaleTimer != nil)
		return;
	point = [aView convertPoint:[aMoved locationInWindow] fromView:nil];
	bounds = [aView bounds];
	if (NSMouseInRect(point, bounds, [aView isFlipped])
		&& [self canConvertNormalizedViewPoint:NSMakePoint(point.x / bounds.size.width, point.y / bounds.size.height)
									toGeoPoint:&geoPoint]) {
		[self mousePositionChanged:geoPoint event:aMoved countryHightlight:YES];
		_needToCallMouseLost = YES;
		return;
	}
	if (_needToCallMouseLost) {
		[self mouseLost];
		_needToCallMouseLost = NO;
	}
}

- (void)scrollWithDiff:(NSPoint)aDiff fromViewPoint:(NSPoint)aPoint
{
	_downLocation = aPoint;
	[self startTrackingAtViewPoint:aPoint];
	[self mouseDraggedWithDiff:aDiff];
	[self _resumeAutoMove];
}

- (void)endTrackingAtViewPoint:(NSPoint)aPoint
{
	NSInteger behaviour = [Preferences mouseBehaviourOnMap];
	NSRect selection = [self _selectionRectForPoint:aPoint];
	BOOL zoom;

	if (!_commandOnMouseDown) {
		if (behaviour == 0)
			zoom = !_selectionWasCanceled;
		else
			zoom = behaviour == 1 && _optionOnMouseDown;
	} else {
		zoom = (behaviour == 1 || behaviour == 2) && !_selectionWasCanceled;
	}
	if (zoom)
		[self zoomToSelectionRect:selection];

	[self _resumeAutoMove];
	if (_scaleTimer == nil) {
		NSRect frame = [[_controller glView] frame];
		NSPoint geoPoint;
		if ([self canConvertNormalizedViewPoint:NSMakePoint(aPoint.x / frame.size.width, aPoint.y / frame.size.height)
									 toGeoPoint:&geoPoint]
			&& [self _highlightCountryAtGeoPoint:geoPoint])
			[self refreshView];
	}
}

- (void)mouseDraggedWithDiff:(NSPoint)aDiff
{
	CGFloat x = aDiff.x + _downLocation.x;
	CGFloat y = aDiff.y + _downLocation.y;
	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	NSRect frame = [[_controller glView] frame];
	double dt = now - _prevMouseDragTime;

	_postMoveVelocity.x = ((x - _prevMouseDragPos.x) / frame.size.width) / dt;
	_postMoveVelocity.y = ((y - _prevMouseDragPos.y) / frame.size.height) / dt;
	_slidingIsActive = NO;
	_postmoveIsActive = YES;
	[self _setupTimer];
	_prevMouseDragPos.y = y;
	_prevMouseDragPos.x = x;
	_prevMouseDragTime = now;
}

- (void)trackToViewPoint:(NSPoint)aPoint
{
	NSInteger behaviour = [Preferences mouseBehaviourOnMap];
	NSPoint diff = NSMakePoint(aPoint.x - _downLocation.x, aPoint.y - _downLocation.y);
	NSRect selection = [self _selectionRectForPoint:aPoint];
	BOOL select;

	if (!_commandOnMouseDown) {
		if (behaviour == 1) {
			select = _optionOnMouseDown;
		} else if (behaviour == 0) {
			if (_selectionWasCanceled)
				return;
			select = YES;
		} else if (behaviour == 2) {
			select = NO;
		} else {
			return;
		}
	} else {
		if (behaviour == 0) {
			select = NO;
		} else if (behaviour <= 2) {
			if (_selectionWasCanceled)
				return;
			select = YES;
		} else {
			return;
		}
	}
	if (select)
		[self changeSelectionRect:selection];
	else
		[self mouseDraggedWithDiff:diff];
}

- (NSRect)_selectionRectForPoint:(NSPoint)aPoint
{
	CGFloat originX = _downLocation.x, originY = _downLocation.y;
	CGFloat width = aPoint.x - originX, height = aPoint.y - originY;
	NSRect frame;

	if (width < 0.0) {
		width = -width;
		originX = aPoint.x;
	}
	if (height < 0.0) {
		height = -height;
		originY = aPoint.y;
	}
	frame = [[_controller glView] frame];
	return NSMakeRect(originX / frame.size.width, originY / frame.size.height,
		width / frame.size.width, height / frame.size.height);
}

- (void)startTrackingAtViewPoint:(NSPoint)aPoint
{
	[self _pauseAutoMove];
	_prevMouseDragTime = [NSDate timeIntervalSinceReferenceDate] - 0.001;
	_prevMouseDragPos = aPoint;
	_positionOnDown = _position;
	[self _disableCountryHighlight];
}

- (void)mouseLost
{
	BOOL changed = NO;

	if ([Preferences nearestCityEnabled] && _prevCityObj != nil) {
		[[self scene] highlightCity:nil];
		_prevCityObj = nil;
		changed = YES;
	}
	if (([Preferences regionHighlightIsEnabled] && (_prevCountryUID != nil || _prevStateUID != nil))
		|| ([Preferences showTimeZoneEnabled] && _prevTimeZoneUID != nil)) {
		[self _disableCountryHighlight];
		changed = YES;
	}
	if ([Preferences showLocationEnabled]) {
		[[self scene] setStatusLine:nil];
		changed = YES;
	}
	if (changed)
		[self refreshView];
}

- (void)mousePositionChanged:(NSPoint)aChanged event:(id)aEvent countryHightlight:(BOOL)aHightlight
{
	BOOL changed = NO;

	if (!_mouseIsInside)
		return;
	if (!_slidingIsActive) {
		if ([Preferences nearestCityEnabled]) {
			id city = [[AtlasDatabase database] cityNearestToGeoPoint:aChanged];
			if (_prevCityObj != city) {
				[[self scene] highlightCity:city];
				_prevCityObj = city;
				changed = YES;
			}
		}
		if (!_slidingIsActive && aHightlight)
			changed |= [self _highlightCountryAtGeoPoint:aChanged];
	}
	if ([Preferences showLocationEnabled]) {
		[[self scene] setStatusLine:[self _currentLocationDescriptionForGeoPoint:aChanged withCountryName:YES]];
		changed = YES;
	}
	if (!_slidingIsActive) {
		NSInteger behaviour = [Preferences mouseBehaviourOnMap];
		if (behaviour == 1) {
			if ([[self windowController] showsApples]) {
				CGFloat size = [[self scene] appleStoreMarkerSize];
				NSArray *stores = [self _findLastAppleStoresForGeoPoint:aChanged toWithin:size];
				if (stores)
					[[self scene] highlightAppleStore:[stores objectAtIndex:0] hiliteColor:&_hiliteYellow];
				else
					[[self scene] highlightAppleStore:nil hiliteColor:NULL];
				[self setCorrectCursor:aEvent];
			}
		} else if (behaviour == 2 && ![Preferences nearestCityEnabled]) {
			id entry = [self _findLastEntryOnMapForGeoPoint:aChanged toWithin:[self precisionForEntryMarker]];
			[[self scene] highlightCity2:entry hiliteColor:entry ? &_hiliteYellow : NULL];
		}
	}
	if (changed)
		[self refreshView];
}

- (id)_currentLocationDescriptionForGeoPoint:(NSPoint)aPoint withCountryName:(BOOL)aName
{
	static NSString *_shortLatitude = nil;
	static NSString *_shortLongitude = nil;
	NSString *place = nil;

	if (aName) {
		NSString *state = [[[AtlasDatabase database] infoWithShapeUID:_prevStateUID lod:0] ownShapeName];
		NSString *country = [[[AtlasDatabase database] infoWithShapeUID:_prevCountryUID lod:0] ownShapeName];
		if (country != nil)
			place = state ? [state stringByAppendingFormat:@", %@", country] : country;
		else
			place = state;
	}
	if (place == nil)
		place = @"";
	if (_shortLatitude == nil)
		_shortLatitude = [[NSBundle mainBundle] localizedStringForKey:@"Short name for 'Latitude'" value:@"" table:nil];
	if (_shortLongitude == nil)
		_shortLongitude = [[NSBundle mainBundle] localizedStringForKey:@"Short name for 'Longitude'" value:@"" table:nil];
	return [NSString stringWithFormat:@"%@=%@ %@=%@ %@", _shortLatitude, [NSString latitudeDesription:aPoint.y],
		_shortLongitude, [NSString longitudeDesription:aPoint.x], place];
}

- (BOOL)_highlightCountryAtGeoPoint:(NSPoint)aPoint
{
	BOOL changed = NO;
	id country = nil, state = nil, timeZone = nil;

	if ([Preferences regionHighlightIsEnabled]) {
		country = [[AtlasDatabase database] shapeUIDOfType:0 underGeoPoint:aPoint];
		state = [[AtlasDatabase database] shapeUIDOfType:1 underGeoPoint:aPoint];
		if (!_slidingIsActive) {
			if ((country != _prevCountryUID && ![_prevCountryUID isEqualToString:country])
				|| (state != _prevStateUID && ![_prevStateUID isEqualToString:state]))
				changed = YES;
		}
		[_prevCountryUID release];
		_prevCountryUID = [country retain];
		[_prevStateUID release];
		_prevStateUID = [state retain];
	}
	if ([Preferences showTimeZoneEnabled]) {
		timeZone = [[AtlasDatabase database] shapeUIDOfType:3 underGeoPoint:aPoint];
		if (!_slidingIsActive && timeZone != _prevTimeZoneUID && ![_prevTimeZoneUID isEqualToString:timeZone])
			changed = YES;
		[_prevTimeZoneUID release];
		_prevTimeZoneUID = [timeZone retain];
	}
	if (changed) {
		AtlasDatabase *database = [AtlasDatabase database];
		id countryInfo = [database infoWithShapeUID:country lod:[self countryBoundariesLOD]];
		id stateInfo = [database infoWithShapeUID:state lod:[self countryBoundariesLOD]];
		id timeZoneInfo = [database infoWithShapeUID:timeZone lod:[self countryBoundariesLOD]];
		[[self scene] highlightCountry:countryInfo state:stateInfo timeZone:timeZoneInfo];
	}
	return changed;
}

- (void)doubleActionOnGeoPoint:(NSPoint)aPoint
{
	[self zoomToCurrentCountry];
}

- (void)singleActionOnGeoPoint:(NSPoint)aPoint
{
	NSInteger behaviour = [Preferences mouseBehaviourOnMap];

	if (!_commandOnMouseDown) {
		if (behaviour == 2) {
			id city;
			if ([Preferences nearestCityEnabled]) {
				city = [[AtlasDatabase database] cityNearestToGeoPoint:aPoint];
			} else {
				NSInteger index = [self _entryIndexFromArray:[[self windowController] entriesOnMap]
												nearGeoPoint:aPoint inRadius:[self precisionForEntryMarker]];
				if (index != NSNotFound) {
					[_controller selectRouteEntryAt:index];
					return;
				}
				city = [YACityEntry entryWithGeoPoint:aPoint];
			}
			[_controller appendCityToDistCalcList:city];
			return;
		}
		if (behaviour == 1) {
			if ([[self windowController] showsApples]) {
				CGFloat size = [[self scene] appleStoreMarkerSize];
				NSArray *stores = [self _findLastAppleStoresForGeoPoint:aPoint toWithin:size];
				if (stores != nil) {
					[[self scene] highlightAppleStore:[stores objectAtIndex:0] hiliteColor:&_hiliteYellow];
					[AppleStoreInfoPaletteController showAppleStoresInfo:stores];
					return;
				}
			}
			if (!_optionOnMouseDown)
				return;
			[self zoomOutToGeoPoint:aPoint];
			return;
		}
		if (behaviour != 0)
			return;
	} else if (behaviour != 1 && behaviour != 2) {
		return;
	}
	if (_optionOnMouseDown)
		[self zoomOutToGeoPoint:aPoint];
	else
		[self zoomInToGeoPoint:aPoint];
}

- (id)_findLastEntryOnMapForGeoPoint:(NSPoint)aPoint toWithin:(CGFloat)aWithin
{
	NSArray *entries = [[self windowController] entriesOnMap];
	NSInteger index = [self _entryIndexFromArray:entries nearGeoPoint:aPoint inRadius:aWithin];
	if (index != NSNotFound)
		return [entries objectAtIndex:index];
	return nil;
}

- (id)_findLastAppleStoresForGeoPoint:(NSPoint)aPoint toWithin:(CGFloat)aWithin
{
	return [self _findLastEntriesFromEnties:[[AtlasDatabase database] appleStores] forGeoPoint:aPoint toWithin:aWithin];
}

// YES when an entry's first on-screen position lies within the elliptic pixel radius of any target point
static BOOL _entryIsNear(AtlasPanelController *self, id anEntry, NSArray *targets, NSSize aSize, CGFloat aRadius)
{
	NSArray *points = [self normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint([anEntry coordinates])];
	NSPoint entryPoint;
	NSUInteger i, count;

	if ([points count] == 0)
		return NO;
	entryPoint = [[points objectAtIndex:0] pointValue];
	count = [targets count];
	for (i = 0; i < count; i++) {
		NSPoint target = [[targets objectAtIndex:i] pointValue];
		CGFloat dx = fabs(target.x - entryPoint.x) * aSize.width;
		CGFloat dy = fabs(target.y - entryPoint.y) * aSize.height;
		if ((dx * dx) / (aRadius * aRadius) + (dy * dy) / (aRadius * aRadius) <= 1.0)
			return YES;
	}
	return NO;
}

- (NSInteger)_entryIndexFromArray:(id)aArray nearGeoPoint:(NSPoint)aPoint inRadius:(CGFloat)aRadius
{
	NSInteger index = [aArray count];
	NSArray *targets = [self normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint(aPoint)];
	NSSize size = [[[self windowController] glView] frame].size;

	while (--index >= 0) {
		if (_entryIsNear(self, [aArray objectAtIndex:index], targets, size, aRadius))
			return index;
	}
	return NSNotFound;
}

- (id)_findLastEntriesFromEnties:(id)aEnties forGeoPoint:(NSPoint)aPoint toWithin:(CGFloat)aWithin
{
	NSMutableArray *found = [NSMutableArray arrayWithCapacity:8];
	NSInteger index = [aEnties count];
	NSArray *targets = [self normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint(aPoint)];
	NSSize size = [[[self windowController] glView] frame].size;

	while (--index >= 0) {
		id entry = [aEnties objectAtIndex:index];
		if (_entryIsNear(self, entry, targets, size, aWithin)) {
			[found addObject:entry];
			while (--index >= 0) {
				id other = [aEnties objectAtIndex:index];
				if (![[other shortCaption] isEqualTo:[entry shortCaption]])
					break;
				[found addObject:other];
			}
			return found;
		}
	}
	return nil;
}

- (void)_timerOnFirstClickProcess:(id)aProcess
{
	[[aProcess userInfo] autorelease];
	[self _firstClickProcess:[aProcess userInfo]];
}

- (void)_firstClickProcess:(id)aProcess
{
	NSView *glView;
	NSRect frame;
	NSPoint point, geoPoint;

	[_firstClickDelayedPerformer invalidate];
	_firstClickDelayedPerformer = nil;
	glView = [[self windowController] glView];
	frame = [glView frame];
	point = [glView convertPoint:[aProcess locationInWindow] fromView:nil];
	if ([self canConvertNormalizedViewPoint:NSMakePoint(point.x / frame.size.width, point.y / frame.size.height)
								 toGeoPoint:&geoPoint])
		[self singleActionOnGeoPoint:geoPoint];
	[self setCorrectCursor:aProcess];
}

- (struct WeatherGlobe_anon2)drawedSpacePointFromGeoPoint:(NSPoint)aPoint
{
	return [(BaseAtlasScene *)[self scene] get3DCoordinatesFromGeoPoint:aPoint];
}

- (NSInteger)countryBoundariesLOD
{
	return 0;
}

- (NSPoint)mapPointFromPositionPoint:(NSPoint)aPoint
{
	return NSZeroPoint;
}

- (NSPoint)positionPointFromMapPoint:(NSPoint)aPoint
{
	return NSZeroPoint;
}

- (id)normalizedViewPointsFromMapPoint:(NSPoint)aPoint
{
	return nil;
}

- (BOOL)canConvertNormalizedViewPoint:(NSPoint)aPoint toGeoPoint:(NSPoint *)aPoint2
{
	return NO;
}

- (CGFloat)viewAspect
{
	NSRect frame = [[_controller glView] frame];
	return frame.size.width / frame.size.height;
}

- (void)refreshAnimationFlag
{
	[_controller refreshAnimationFlag];
}

- (BOOL)requiresAnimation
{
	return [[self scene] requiresAnimation];
}

- (NSInteger)degreesGridStep
{
	return 1;
}

- (void)slideToMapPoint:(NSPoint)aPoint
{
	CGFloat dx;

	_slideStartPos = _position;
	_slideTargetPos = [self positionPointFromMapPoint:aPoint];
	dx = _slideTargetPos.x - _slideStartPos.x;
	if (dx > 0.55)
		_slideTargetPos.x -= 1.0;
	else if (dx < -0.55)
		_slideTargetPos.x += 1.0;
	_slideStartTime = [NSDate timeIntervalSinceReferenceDate];
	[[_controller compassButton] setIntValue:0];
	[[_controller compassButton2] setIntValue:0];
	[self compassValueChangedTo:0];
	_slidingIsActive = YES;
	[self _setupTimer];
}

- (void)setCurrentCity:(id)aCity slideEntryToCenter:(BOOL)aCenter
{
	[[self scene] highlightCity:aCity];
	[aCity retain];
	[_sCurrentCity release];
	_sCurrentCity = aCity;
	[_currentCityDelayedSelector invalidate];
	if (aCity != nil && aCenter) {
		_currentCityDelayedSelector = [NSTimer timerWithTimeInterval:0.35 target:self
			selector:@selector(_delayedCurrentCitySelect:) userInfo:nil repeats:NO];
		[[NSRunLoop currentRunLoop] addTimer:_currentCityDelayedSelector forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_currentCityDelayedSelector forMode:NSEventTrackingRunLoopMode];
	} else {
		_currentCityDelayedSelector = nil;
	}
}

- (void)setCurrentCity:(id)aCity
{
	[self setCurrentCity:aCity slideEntryToCenter:YES];
}

- (void)_delayedCurrentCitySelect:(id)aSelect
{
	NSPoint geoPoint = _sCurrentCity ? [_sCurrentCity coordinates] : NSZeroPoint;
	[self slideToMapPoint:_mapPointFromGeoPoint(geoPoint)];
	_currentCityDelayedSelector = nil;
}

- (void)worldRectChangedTo:(NSRect)aTo
{
	[self slideToMapPoint:aTo.origin];
}

- (void)compassValueChangedTo:(NSInteger)aTo
{
	_compassValue = (int)aTo;
	[[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d", _compassValue]
											  forKey:_preferenceKey(self, @"compass")];
	if ((NSUInteger)aTo < 2) {
		_slidingIsActive = NO;
		_postmoveIsActive = NO;
		_automoveIsActive = NO;
		[self _setupTimer];
		return;
	}
	[self setCurrentCity:nil];
	_automoveIsActive = YES;
	[self _setupTimer];
	switch (aTo) {
	case 2:
		_automoveSpeed = NSMakePoint(-0.04, 0.0);
		break;
	case 3:
		_automoveSpeed = NSMakePoint(0.04, 0.0);
		break;
	case 4:
		_automoveSpeed = NSMakePoint(0.0, 0.03);
		break;
	case 5:
		_automoveSpeed = NSMakePoint(0.0, -0.03);
		break;
	}
}

- (BOOL)getDefaultCompassValue:(int *)aValue
{
	id value;

	if (![Preferences retainLastView])
		return NO;
	value = [[NSUserDefaults standardUserDefaults] objectForKey:_preferenceKey(self, @"compass")];
	if (value != nil && aValue != NULL)
		*aValue = [value intValue];
	return value != nil;
}

- (NSInteger)compassValue
{
	return _compassValue;
}

- (void)setPosition:(NSPoint)aPosition
{
	_position = aPosition;
}

- (BOOL)getDefaultPosition:(NSPoint *)aPosition
{
	id value;

	if (![Preferences retainLastView])
		return NO;
	value = [[NSUserDefaults standardUserDefaults] objectForKey:_preferenceKey(self, @"position")];
	if (value != nil && aPosition != NULL)
		*aPosition = NSPointFromString(value);
	return value != nil;
}

- (NSPoint)position
{
	return _position;
}

- (CGFloat)defaultScale
{
	id value = [[NSUserDefaults standardUserDefaults] objectForKey:_preferenceKey(self, @"scale")];
	if (value != nil)
		return [value floatValue];
	return -1.0;
}

- (CGFloat)scale
{
	return 0.0;
}

- (void)adjustToScale:(CGFloat)aScale
{
	[_prevCountryUID release];
	[_prevStateUID release];
	[_prevTimeZoneUID release];
	_prevTimeZoneUID = nil;
	_prevCountryUID = nil;
	_prevStateUID = nil;
	_prevCityObj = nil;
	[[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%f", (double)aScale]
											  forKey:_preferenceKey(self, @"scale")];
}

- (void)glViewFrameDidChange:(id)aChange
{
}

- (void)sceneWasUninstalled
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[_controller zoomingSliders] makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
	_slidingIsActive = NO;
	_postmoveIsActive = NO;
	_automoveIsActive = NO;
	[self _setupTimer];
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromPoint(_position)
											  forKey:_preferenceKey(self, @"position")];
}

- (void)sceneWillBeInstalled
{
	MainWindowController *controller;

	[[_controller zoomingSliders] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	[self _disableCountryHighlight];
	_prevCityObj = nil;
	[self compassValueChangedTo:_compassValue];
	controller = [self windowController];
	[[controller mainWindow] setAcceptsMouseMovedEvents:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(glViewFrameDidChange:)
		name:NSViewFrameDidChangeNotification object:[controller glView]];
	_mouseIsInside = YES;
	[[self scene] highlightCity:_sCurrentCity];
}

- (void)refreshView
{
	[[_controller glView] setNeedsDisplay:YES];
}

- (id)scene
{
	return nil;
}

- (id)windowController
{
	return _controller;
}

- (void)_disableCountryHighlight
{
	[[self scene] highlightCountry:nil state:nil timeZone:nil];
	[_prevCountryUID release];
	[_prevStateUID release];
	[_prevTimeZoneUID release];
	_prevCountryUID = nil;
	_prevStateUID = nil;
	_prevTimeZoneUID = nil;
}

- (void)_onTimer:(id)aTimer
{
	BOOL refresh = _isFlying && !_moveIsPaused;

	if (_automoveIsActive && (_automoveSpeed.x != 0.0 || _automoveSpeed.y != 0.0) && !_moveIsPaused) {
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		CGFloat dt, speed;
		if (_lastTime > 0.0) {
			dt = now - _lastTime;
			if (dt > 0.2)
				dt = 0.2;
		} else {
			dt = 0.01;
		}
		_lastTime = now;
		if (now - 2.0999999046325684 > _lastRecacheTime) {
			[self recacheNeighborsOnly];
			_lastRecacheTime = now;
		}
		speed = [Preferences automoveSpeedUIValue];
		_position.x += dt * _automoveSpeed.x * speed;
		_position.y += speed * dt * _automoveSpeed.y;
		[self setPosition:_position];
		refresh = YES;
	}
	if (_slidingIsActive && !_moveIsPaused) {
		CGFloat t = ([NSDate timeIntervalSinceReferenceDate] - _slideStartTime) / 0.699999988079071;
		t = t <= 1.0 ? 1.0 - t : 0.0;
		t = 1.0 - pow(t, 4.0);
		_position.x = (1.0 - t) * _slideStartPos.x + t * _slideTargetPos.x;
		_position.y = (1.0 - t) * _slideStartPos.y + t * _slideTargetPos.y;
		[self setPosition:_position];
		if (t == 1.0) {
			_slidingIsActive = NO;
			[self _setupTimer];
			[self recacheAll];
		}
		refresh = YES;
	}
	if (_postmoveIsActive) {
		CGFloat t = ([NSDate timeIntervalSinceReferenceDate] - _prevMouseDragTime) / 1.5;
		t = t <= 1.0 ? 1.0 - t : 0.0;
		t = pow(t, 8.0);
		_position.x += t * _postMoveVelocity.x * 0.01;
		_position.y += t * _postMoveVelocity.y * 0.01;
		[self setPosition:_position];
		_positionOnDown.x += t * _postMoveVelocity.x * 0.01;
		_positionOnDown.y += t * _postMoveVelocity.y * 0.01;
		if (t < 0.01) {
			_postmoveIsActive = NO;
			[self _setupTimer];
			[self recacheAll];
		}
		refresh = YES;
	}
	if (_isFlying) {
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
		NSTimeInterval previous = _prevFlyingTime;
		CGFloat speed = [Preferences automoveSpeedUIValue];
		CGFloat scale = [self scale];
		RoutePointsContainer *route;
		double delta;

		_prevFlyingTime = now;
		route = [[self scene] routePointsContainer];
		delta = (double)(float)(speed / (scale + 0.1)) * (now - previous);
		if (![route flyStepWithDeltaTime:delta]) {
			[_controller stopAnyFlying];
		} else {
			NSPoint mapPoint = [[[self scene] routePointsContainer] currentFlyMapPoint];
			[self setPosition:[self positionPointFromMapPoint:mapPoint]];
			if (now - 2.0999999046325684 > _lastRecacheTime) {
				[self recacheNeighborsOnly];
				_lastRecacheTime = now;
			}
		}
	} else if (!refresh) {
		return;
	}
	[self refreshCameraSettings];
}

- (void)_resumeAutoMove
{
	_moveIsPaused = NO;
	_lastTime = 0.0;
	_lastRecacheTime = 0.0;
}

- (void)_pauseAutoMove
{
	_moveIsPaused = YES;
}

- (void)_setupTimer
{
	if (!_automoveIsActive && !_slidingIsActive && !_postmoveIsActive && !_isFlying) {
		[_allInOneMoveTimer invalidate];
		_allInOneMoveTimer = nil;
		[[self scene] highlightCity:_sCurrentCity];
	} else if (_allInOneMoveTimer == nil) {
		_allInOneMoveTimer = [NSTimer timerWithTimeInterval:0.029999999329447746 target:self
			selector:@selector(_onTimer:) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_allInOneMoveTimer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:_allInOneMoveTimer forMode:NSEventTrackingRunLoopMode];
	}
}

- (void)invalidate
{
	[_allInOneMoveTimer invalidate];
	_allInOneMoveTimer = nil;
	[_currentCityDelayedSelector invalidate];
	_currentCityDelayedSelector = nil;
	[_scaleTimer invalidate];
	_scaleTimer = nil;
	[_firstClickDelayedPerformer invalidate];
	_firstClickDelayedPerformer = nil;
	[_scrollDelayedPerformer invalidate];
	_scrollDelayedPerformer = nil;
	[self release];
}

- (void)dealloc
{
	NSView *glView;

	[[_controller zoomingSliders] makeObjectsPerformSelector:@selector(setDelegate:) withObject:nil];
	glView = [_controller glView];
	if ([(AtlasGLView *)glView scene] == [self scene])
		[(AtlasGLView *)glView setScene:nil];
	[_sCurrentCity release];
	_sCurrentCity = nil;
	[_allInOneMoveTimer invalidate];
	[_scaleTimer invalidate];
	[_autoselectedCountryUID release];
	[_autoselectedStateUID release];
	[_autoselectedTimeZoneUID release];
	[super dealloc];
}

- (id)initWithMainWindowController:(id)aController
{
	self = [super init];
	if (self != nil) {
		_controller = aController;
		_compassValue = 0;
	}
	return self;
}

@end
