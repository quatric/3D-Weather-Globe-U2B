// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridMatrix.m
#import "SMKGridMatrix.h"

// The matrix inside a grid control. Each cell gets a content area of
// _cellContentSize in a slot 6 points larger. With threaded updating on, a
// background thread renders the thumbnails of the visible cells that asked
// for it (setNeedsUpdateCell:) and hands them back to the main thread.
@implementation SMKGridMatrix

- (void)startThreadedCellUpdating
{
	if (_isThreadedCellUpdatingStopped) {
		[_stopUpdatingCellsLock lock];
		_isThreadedCellUpdatingStopped = NO;
		[_stopUpdatingCellsLock unlock];
	}
}

- (void)stopThreadedCellUpdating
{
	if (!_isThreadedCellUpdatingStopped) {
		[_stopUpdatingCellsLock lock];
		_isThreadedCellUpdatingStopped = YES;
		[_stopUpdatingCellsLock unlock];
	}
}

// Runs on the updater thread. Cells that scrolled out of view are only
// marked ready; when updating gets stopped, the rest are marked ready too.
- (void)_updateGraphicContentInCells
{
	if (_isThreadedCellUpdatingStopped) {
		return;
	}
	[_updateCellsLock lock];
	NSArray *cells = [NSArray arrayWithArray:_updateCellsArray];
	[_updateCellsArray removeAllObjects];
	[_updateCellsLock unlock];
	NSEnumerator *enumerator = [cells objectEnumerator];
	NSSize cellSize = [self cellSize];
	SMKGridBaseCell *cell;
	while ((cell = [enumerator nextObject]) != nil) {
		[_stopUpdatingCellsLock lock];
		if (_isThreadedCellUpdatingStopped) {
			[_updateCellsLock lock];
			do {
				[_updateCellsArray addObject:cell];
			} while ((cell = [enumerator nextObject]) != nil);
			NSEnumerator *pending = [_updateCellsArray objectEnumerator];
			while ((cell = [pending nextObject]) != nil) {
				[cell setGraphicsContentReady:YES];
			}
			[_updateCellsArray removeAllObjects];
			[_updateCellsLock unlock];
			[_stopUpdatingCellsLock unlock];
			return;
		}
		[cell updateContentSize];
		NSInteger row, column;
		[self getRow:&row column:&column ofCell:cell];
		NSRect frame = NSMakeRect((float)column * (float)cellSize.width, (float)row * (float)cellSize.height,
		                          cellSize.width, cellSize.height);
		if (!NSIsEmptyRect(NSIntersectionRect([self visibleRect], frame))) {
			[cell updateContentIfNeeded];
			if ([cell hasGraphicComponent] && [cell _altImage] == nil) {
				NSRect bounds = NSMakeRect(0.0, 0.0, _cellContentSize.width, _cellContentSize.height);
				[cell cacheGraphicContentWithSize:[cell graphicContentPlacementRectForBounds:bounds].size];
			}
			[self performSelectorOnMainThread:@selector(_setNeedsDrawAndMakeReadyCell:) withObject:cell waitUntilDone:NO];
		} else {
			[cell setGraphicsContentReady:YES];
		}
		[_stopUpdatingCellsLock unlock];
	}
}

// the updater thread: a run loop whose source drawRect: signals
- (void)_updatingThread:(id)aThread
{
	_isUpdaterThreadActive = YES;
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	updaterRunLoop = CFRunLoopGetCurrent();
	CFRunLoopSourceContext context = { 0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, (void (*)(void *))_updateCells };
	updaterUpdateSource = CFRunLoopSourceCreate(NULL, 0, &context);
	CFRunLoopAddSource(updaterRunLoop, updaterUpdateSource, kCFRunLoopDefaultMode);
	while (_isUpdaterRunning) {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, true);
	}
	[pool release];
	_isUpdaterThreadActive = NO;
}

- (void)_initCellUpdater
{
	_isUpdaterRunning = YES;
	[NSThread detachNewThreadSelector:@selector(_updatingThread:) toTarget:self withObject:nil];
}

- (void)enableThreadUpdater:(BOOL)aUpdater
{
	if (!aUpdater) {
		_isUpdaterRunning = NO;
		while (_isUpdaterThreadActive) {
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		}
	} else if (!_isUpdaterRunning) {
		[self _initCellUpdater];
	}
}

// The grid's list view is a table whose data source is this matrix; rows are
// the matrix's cells in order.
- (BOOL)tableView:(id)aView writeRows:(id)aRows toPasteboard:(id)aPasteboard
{
	NSEnumerator *enumerator = [aRows objectEnumerator];
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	BOOL extend = NO;
	id row;
	while ((row = [enumerator nextObject]) != nil) {
		if (floor(NSAppKitVersionNumber) > 663.0) {
			[indexes addIndex:[row intValue]];
		} else {
			[aView selectRowIndexes:[NSIndexSet indexSetWithIndex:[row intValue]] byExtendingSelection:extend];
			extend = YES;
		}
	}
	// as in the original, current systems only collect the rows
	if (floor(NSAppKitVersionNumber) <= 663.0) {
		[aView selectRowIndexes:indexes byExtendingSelection:extend];
	}
	[[self owningGridControl] writeSelectionToPasteboard:aPasteboard withImage:nil];
	return YES;
}

- (id)tableView:(id)aView objectValueForTableColumn:(id)aColumn row:(NSInteger)aRow
{
	SMKGridBaseCell *cell = (SMKGridBaseCell *)[[self cells] objectAtIndex:aRow];
	[cell updateTitleIfNeeded];
	if ([cell title] != nil && [[cell title] length] != 0) {
		return [[[cell title] copy] autorelease];
	}
	return [_owningGridControl stringForEmptyTitle];
}

- (NSInteger)numberOfRowsInTableView:(id)aView
{
	return (int)[self numberOfRows] * (int)[self numberOfColumns] - _extraCellCount;
}

- (BOOL)sendAction:(SEL)aAction to:(id)aTo
{
	[_stopUpdatingCellsLock lock];
	BOOL result = [super sendAction:aAction to:aTo];
	[_stopUpdatingCellsLock unlock];
	return result;
}

- (void)setSelectionStyle:(NSInteger)aStyle
{
	if (_selectionStyle != aStyle) {
		_selectionStyle = (int)aStyle;
		[self _setNeedsDrawCells:[self selectedCells]];
	}
}

- (NSInteger)selectionStyle
{
	return _selectionStyle;
}

- (void)setAllowsMultipleSelection:(BOOL)aSelection
{
	[self setMode:aSelection ? NSListModeMatrix : NSRadioModeMatrix];
}

- (BOOL)allowsMultipleSelection
{
	return [self mode] == NSListModeMatrix;
}

// cells always touch; the spacing is inside them
- (void)setIntercellSpacing:(NSSize)aSpacing
{
	[super setIntercellSpacing:NSZeroSize];
}

- (void)setDefaultResize:(BOOL)aResize
{
	_useDefaultResize = aResize;
}

- (NSUInteger)fittingNumberOfColumns
{
	NSRect visible = [[self superview] visibleRect];
	NSSize content = [self cellContentSize];
	unsigned int columns = (unsigned int)(long long)trunc((double)(float)visible.size.width /
	                                                      ((double)(float)content.width + 6.0));
	if (columns == 0) {
		columns = 1;
	}
	return columns;
}

// as many columns as fit, widening the cells to share out the leftover width
- (void)fitByWidth
{
	NSUInteger columns = [self fittingNumberOfColumns];
	float count = (float)(int)columns;
	float extra = (float)[[self superview] visibleRect].size.width -
	              count * ((float)[self cellContentSize].width + 6.0f);
	float width = [[self superview] visibleRect].size.width;
	float slack = truncf((width - (float)[self cellSize].width * count) / count);
	if (extra >= 0.0f && slack != 0.0f) {
		float height = [self cellSize].height;
		[self setCellSize:NSMakeSize((float)((double)(float)[self cellContentSize].width + 6.0 + (double)truncf(extra / count)),
		                             height)];
	}
	[self setColumnCount:columns];
	[self sizeToCells];
}

// re-flows the same items into aCount columns, keeping the selection
- (void)setColumnCount:(NSUInteger)aCount
{
	if ([[self cells] count] == 0) {
		return;
	}
	unsigned int total = (unsigned int)([self numberOfColumns] * [self numberOfRows]);
	if (aCount == (NSUInteger)[self numberOfColumns] || aCount == 0 || aCount >= 100) {
		return;
	}
	unsigned int columns = (unsigned int)aCount;
	if (total < columns) {
		columns = total;
	}
	unsigned int items = total - _extraCellCount;
	int rows = (int)(items / columns);
	int newRows = rows + 1;
	_extraCellCount = newRows * columns - items;
	if (_extraCellCount == columns) {
		newRows = rows;
		_extraCellCount = 0;
	}
	NSEnumerator *selected = [[self selectedCells] objectEnumerator];
	[self renewRows:newRows columns:columns];
	[self sizeToCells];
	id cell;
	while ((cell = [selected nextObject]) != nil) {
		NSUInteger index = [[self cells] indexOfObject:cell];
		if (index != NSNotFound) {
			[self setSelectionFrom:index to:index anchor:index highlight:YES];
		}
	}
}

// with autosizing: the visible width split between the columns, the visible height
- (NSSize)_calcCellSize
{
	NSInteger columns = [self numberOfColumns];
	[self cellSize];
	if (columns == 0) {
		return NSMakeSize(0.0, 0.0);
	}
	float width = (float)[[self superview] visibleRect].size.width / (float)(int)columns;
	return NSMakeSize(width, [[self superview] visibleRect].size.height);
}

- (void)setMaxTitleHeight:(CGFloat)aHeight
{
	_maxTitleHeight = aHeight;
}

- (CGFloat)maxTitleHeight
{
	return _maxTitleHeight;
}

- (void)setCellContentSize:(NSSize)aSize
{
	NSSize cellSize = [self cellSize];
	if (NSEqualSizes(_cellContentSize, aSize)) {
		return;
	}
	float width = (float)aSize.width >= 0.0f ? (float)aSize.width : 0.0f;
	float height = (float)aSize.height >= 0.0f ? (float)aSize.height : 0.0f;
	_cellContentSize.height = height;
	_cellContentSize.width = width;
	if ((float)cellSize.width - width < 6.0f) {
		cellSize.width = width + 6.0f;
	}
	if ((float)cellSize.height - height < 6.0f) {
		cellSize.height = height + 6.0f;
	}
	[self setCellSize:cellSize];
}

- (NSSize)cellContentSize
{
	return _cellContentSize;
}

// grows the cells to fit the tallest title; drawing waits for the relayout
- (void)setCellTitleAdditionalHeight:(CGFloat)aHeight
{
	float height = aHeight;
	if (_cellTitleAdditionalHeight <= height && height != _cellTitleAdditionalHeight) {
		NSSize content = [self cellContentSize];
		float gap = height <= 0.001f ? 0.0f : 6.0f;
		[self setCellContentSize:NSMakeSize(content.width, ((float)content.height - _cellTitleAdditionalHeight) + height + gap)];
		_cellTitleAdditionalHeight = height;
		[self sizeToCells];
		_isDrawingPermitted = NO;
		[self performSelectorOnMainThread:@selector(_setNeedsDisplay) withObject:nil waitUntilDone:NO];
	}
}

- (CGFloat)cellTitleAdditionalHeight
{
	return _cellTitleAdditionalHeight;
}

- (id)imageFrameColor
{
	return [[NSColor controlShadowColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
}

// the selection color, gray in an inactive window
- (id)textFrameColor
{
	if (![[self window] isKeyWindow]) {
		return [[NSColor alternateSelectedControlColor] colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
	}
	return [[NSColor alternateSelectedControlColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
}

- (id)textFont
{
	CGFloat size = _controlSize == NSControlSizeRegular ? [NSFont systemFontSize] : [NSFont smallSystemFontSize];
	return [NSFont systemFontOfSize:(float)size];
}

- (void)setControlSize:(NSInteger)aSize
{
	_controlSize = (int)aSize;
}

- (NSInteger)controlSize
{
	return _controlSize;
}

// keeps the content area at least 6 points smaller than the cell
- (void)setCellSize:(NSSize)aSize
{
	if (NSEqualSizes([self cellSize], aSize)) {
		return;
	}
	float width = (float)aSize.width >= 0.0f ? (float)aSize.width : 0.0f;
	float height = (float)aSize.height >= 0.0f ? (float)aSize.height : 0.0f;
	[super setCellSize:NSMakeSize(width, height)];
	[[self enclosingScrollView] setLineScroll:[self cellSize].height];
	NSSize content = [self cellContentSize];
	float contentWidth = content.width;
	if (width - contentWidth < 6.0f) {
		contentWidth = width > 6.0f ? width - 6.0f : width;
	}
	float contentHeight = content.height;
	if (height - contentHeight < 6.0f) {
		contentHeight = height > 6.0f ? height - 6.0f : height;
	}
	[self setCellContentSize:NSMakeSize(contentWidth, contentHeight)];
}

// lays out aCount items in as many columns as fit, keeping the selection and
// the scroll position
- (void)setCount:(NSUInteger)aCount
{
	unsigned int count = (unsigned int)aCount;
	unsigned int columns = (unsigned int)[self fittingNumberOfColumns];
	int rows;
	if (columns < count) {
		double fullRows = (double)(count / columns);
		rows = (int)fullRows + 1;
		_extraCellCount = columns * rows - count;
		if (_extraCellCount == columns) {
			_extraCellCount = 0;
			rows = (int)fullRows;
		}
	} else {
		_extraCellCount = 0;
		rows = 1;
		columns = count;
	}
	NSEnumerator *selected = [[self selectedCells] objectEnumerator];
	NSRect visible = NSZeroRect;
	if ([self superview] != nil) {
		visible = [self visibleRect];
	}
	[self renewRows:rows columns:columns];
	id cell;
	while ((cell = [selected nextObject]) != nil) {
		NSUInteger index = [[self cells] indexOfObject:cell];
		if (index != NSNotFound) {
			[self setSelectionFrom:index to:index anchor:index highlight:YES];
		}
	}
	if ([self superview] != nil) {
		[self scrollRectToVisible:visible];
	}
}

- (NSUInteger)count
{
	return (int)[self numberOfRows] * (int)[self numberOfColumns] - _extraCellCount;
}

- (void)_setNeedsDisplay
{
	_isDrawingPermitted = YES;
	[self setNeedsDisplay:YES];
}

// queues a cell for the updater thread
- (void)setNeedsUpdateCell:(id)aCell
{
	if (_isUpdaterRunning && !_isThreadedCellUpdatingStopped) {
		NSInteger row, column;
		[self getRow:&row column:&column ofCell:aCell];
		[_updateCellsLock lock];
		[aCell setGraphicsContentReady:NO];
		[_updateCellsArray addObject:aCell];
		[_updateCellsLock unlock];
	}
}

- (void)_setNeedsDrawAndMakeReadyCell:(id)aCell
{
	[aCell setGraphicsContentReady:YES];
	[self _setNeedsDrawCell:aCell];
}

- (void)_setNeedsDrawCell:(id)aCell
{
	NSInteger row, column;
	[self getRow:&row column:&column ofCell:aCell];
	NSSize size = [self cellSize];
	[self setNeedsDisplayInRect:NSMakeRect((float)column * (float)size.width, (float)row * (float)size.height,
	                                       size.width, size.height)];
}

// redraws the selected cells (aCells is ignored, as in the original)
- (void)_setNeedsDrawCells:(id)aCells
{
	NSEnumerator *enumerator = [[self selectedCells] objectEnumerator];
	id cell;
	while ((cell = [enumerator nextObject]) != nil) {
		[self _setNeedsDrawCell:cell];
	}
}

// drawing queues cells; this wakes the updater to render them
- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	if (_isUpdaterRunning) {
		CFRunLoopSourceSignal(updaterUpdateSource);
		if (CFRunLoopIsWaiting(updaterRunLoop)) {
			CFRunLoopWakeUp(updaterRunLoop);
		}
	}
}

- (BOOL)isDrawingPermitted
{
	return _isDrawingPermitted;
}

- (BOOL)isTitlePreloading
{
	BOOL preloading = [[self owningGridControl] isTitlePreloadingEnabled];
	if ([self superview] != nil) {
		preloading = preloading & [self isCacheAllowed];
	}
	return preloading;
}

- (BOOL)isThreadedCellUpdatingEnabled
{
	return [self isCacheAllowed] && _isUpdaterRunning;
}

- (void)setThumbnailCachingEnabled:(BOOL)aEnabled
{
	_isThumbnailCachingEnabled = aEnabled;
}

- (BOOL)isThumbnailCachingEnabled
{
	return _isThumbnailCachingEnabled;
}

- (BOOL)isCacheAllowed
{
	return ![self autosizesCells] && [self superview] != nil;
}

- (void)setOwningGridControl:(id)aControl
{
	_owningGridControl = aControl;
}

- (id)owningGridControl
{
	return _owningGridControl;
}

// drags the clicked item's thumbnail (or the grid control's stack image for
// several), placed where the cell draws it
- (void)mouseDragged:(id)aDragged
{
	NSPoint point = [self convertPoint:[aDragged locationInWindow] fromView:nil];
	NSInteger row, column;
	[self getRow:&row column:&column forPoint:point];
	SMKGridBaseCell *cell = (SMKGridBaseCell *)[self cellAtRow:row column:column];
	NSSize content = [self cellContentSize];
	if (cell == nil || ![cell isEnabled]) {
		return;
	}
	NSRect bounds = NSMakeRect(0.0, 0.0, content.width, content.height);
	NSImage *image = [cell cachedImageWithSize:[cell graphicContentPlacementRectForBounds:bounds].size];
	NSRect frame = [self cellFrameAtRow:row column:column];
	NSRect area;
	area.origin.x = truncf((float)((double)(float)frame.origin.x +
	                               (double)((float)frame.size.width - (float)_cellContentSize.width) * 0.5));
	area.origin.y = truncf((float)((double)(float)frame.origin.y +
	                               (double)((float)frame.size.height - (float)_cellContentSize.height) * 0.5));
	area.size = _cellContentSize;
	NSRect graphic = [cell graphicContentPlacementRectForBounds:area];
	NSSize size = [cell cachedImageSizeForBounds:graphic.size];
	float x = (float)(trunc((double)((float)graphic.size.width - (float)size.width) * 0.5)) + (float)graphic.origin.x;
	float y = (float)(trunc((double)((float)graphic.size.height - (float)size.height) * 0.5)) + (float)graphic.origin.y;
	if ([[self selectedCells] count] > 1) {
		image = [[self owningGridControl] imageForMultipleDraggedItemsForImage:image];
		NSSize stack = [image size];
		if ((float)size.width < (float)stack.width) {
			size.width = stack.width;
		}
		if ((float)size.height < (float)stack.height) {
			size.height = stack.height;
		}
	}
	[[self owningGridControl] dragImage:image imageOrigin:NSMakePoint(x, y + (float)size.height) source:self event:aDragged];
}

// Single selection keeps the scroll position when selecting; multiple
// selection leaves modifier clicks to NSMatrix. A click on an already
// selected item in multiple selection sends nothing.
- (void)mouseDown:(id)aDown
{
	NSInteger row, column;
	if ([self mode] == NSRadioModeMatrix) {
		NSPoint point = [self convertPoint:[aDown locationInWindow] fromView:nil];
		[self getRow:&row column:&column forPoint:point];
		NSCell *cell = [self cellAtRow:row column:column];
		if (![cell isEnabled]) {
			return;
		}
		if (![cell isEqual:[self selectedCell]]) {
			NSPoint origin = [[[self enclosingScrollView] contentView] documentVisibleRect].origin;
			[self selectCellAtRow:row column:column];
			[[[self enclosingScrollView] contentView] scrollToPoint:origin];
		}
	} else {
		NSEventModifierFlags flags = NSEventModifierFlagShift | NSEventModifierFlagCommand | NSEventModifierFlagOption;
		if ([aDown modifierFlags] & flags) {
			[super mouseDown:aDown];
			return;
		}
		NSPoint point = [self convertPoint:[aDown locationInWindow] fromView:nil];
		[self getRow:&row column:&column forPoint:point];
		if (![[self cellAtRow:row column:column] isEnabled]) {
			return;
		}
		if ([[self selectedCells] containsObject:[self cellAtRow:row column:column]]) {
			return;
		}
		[self selectCellAtRow:row column:column];
	}
	if ([aDown clickCount] == 1) {
		[self sendAction];
	} else {
		[self sendDoubleAction];
	}
}

// Selects every item: the full rows, then the last row up to the item count.
- (void)selectAll:(id)aAll
{
	if ([self mode] != NSListModeMatrix) {
		return;
	}
	[[self cells] makeObjectsPerformSelector:@selector(updateContentIfNeeded)];
	[self deselectAllCells];
	int lastRowStart = ((int)[self numberOfRows] - 1) * (int)[self numberOfColumns];
	[self setSelectionFrom:0 to:lastRowStart - 1 anchor:0 highlight:YES];
	[self setSelectionFrom:lastRowStart to:(int)[self count] - 1 anchor:lastRowStart highlight:YES];
}

- (void)resizeWithOldSuperviewSize:(NSSize)aSize
{
	if (![self autosizesCells]) {
		[self fitByWidth];
	} else if (!_useDefaultResize) {
		NSRect visible = [[self enclosingScrollView] documentVisibleRect];
		NSInteger row, column;
		[self getRow:&row column:&column forPoint:visible.origin];
		NSSize size = [self _calcCellSize];
		[self setCellSize:size];
		[self setCellContentSize:NSMakeSize((float)size.width - 6.0f, (float)size.height - 6.0f)];
		[self sizeToCells];
		[self scrollCellToVisibleAtRow:row column:column];
	} else {
		[super resizeWithOldSuperviewSize:aSize];
	}
}

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal
{
	return NSDragOperationCopy;
}

- (void)onWindowBecomeResignKey:(id)aKey
{
	[self _setNeedsDrawCells:[self selectedCells]];
}

- (void)viewDidMoveToWindow
{
	if ([self window] != nil) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWindowBecomeResignKey:)
		                                             name:NSWindowDidBecomeKeyNotification object:[self window]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWindowBecomeResignKey:)
		                                             name:NSWindowDidResignKeyNotification object:[self window]];
	}
}

- (BOOL)becomeFirstResponder
{
	return YES;
}

- (BOOL)needsPanelToBecomeKey
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)encodeWithCoder:(id)aCoder
{
	[aCoder encodeFloat:_cellTitleAdditionalHeight forKey:@"cellTitleAdditionalHeight"];
	[aCoder encodeSize:_cellContentSize forKey:@"cellContentSize"];
	[aCoder encodeInt:_extraCellCount forKey:@"extraCellCount"];
	[aCoder encodeBool:_useDefaultResize forKey:@"useDefaultResize"];
	[aCoder encodeFloat:_maxTitleHeight forKey:@"maxTitleHeight"];
	[aCoder encodeInt:_controlSize forKey:@"controlSize"];
	[aCoder encodeInt:_selectionStyle forKey:@"selectionStyle"];
	[aCoder encodeBool:_isThumbnailCachingEnabled forKey:@"isThumbnailCachingEnabled"];
	[super encodeWithCoder:aCoder];
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self == nil) {
		return nil;
	}
	[self _initVars];
	_cellTitleAdditionalHeight = [aCoder decodeFloatForKey:@"cellTitleAdditionalHeight"];
	_cellContentSize = [aCoder decodeSizeForKey:@"cellContentSize"];
	_extraCellCount = [aCoder decodeIntForKey:@"extraCellCount"];
	_useDefaultResize = [aCoder decodeBoolForKey:@"useDefaultResize"];
	_maxTitleHeight = [aCoder decodeFloatForKey:@"maxTitleHeight"];
	_controlSize = [aCoder decodeIntForKey:@"controlSize"];
	_selectionStyle = [aCoder decodeIntForKey:@"selectionStyle"];
	_isThumbnailCachingEnabled = [aCoder decodeBoolForKey:@"isThumbnailCachingEnabled"];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_updateCellsArray removeAllObjects];
	[_updateCellsArray release];
	[_updateCellsLock release];
	[_stopUpdatingCellsLock release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	if (self != nil) {
		[self _initVars];
		[self setMode:NSRadioModeMatrix];
		[self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self setCellClass:[SMKGridBaseCell class]];
		[self setCellContentSize:NSMakeSize(150.0, 150.0)];
		[self setCellSize:[self cellContentSize]];
		[self setIntercellSpacing:NSZeroSize];
	}
	return self;
}

- (void)_initVars
{
	_useDefaultResize = NO;
	_extraCellCount = 0;
	_maxTitleHeight = 0.0f;
	_cellTitleAdditionalHeight = 0.0f;
	_controlSize = 0;
	_selectionStyle = 1;
	_isDrawingPermitted = YES;
	_isThumbnailCachingEnabled = YES;
	_isUpdaterRunning = NO;
	_isThreadedCellUpdatingStopped = YES;
	_isUpdaterThreadActive = NO;
	_owningGridControl = nil;
	_updateCellsLock = [[NSConditionLock alloc] initWithCondition:1];
	_stopUpdatingCellsLock = [NSLock new];
	_updateCellsArray = [NSMutableArray new];
}

@end
