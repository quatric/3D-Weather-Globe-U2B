// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/SMKGridControl.m
#import "SMKGridControl.h"

// Draws an image upright with its bottom-left corner at aPoint, as the
// removed -dissolveToPoint:fraction: and -compositeToPoint:operation:fraction: did.
static void SMKDrawImageAtPoint(NSImage *aImage, NSPoint aPoint, NSCompositingOperation aOperation, CGFloat aFraction)
{
	NSRect to;
	to.size = [aImage size];
	to.origin = aPoint;
	if ([[NSGraphicsContext currentContext] isFlipped]) {
		to.origin.y -= to.size.height;
	}
	[aImage drawInRect:to fromRect:NSZeroRect operation:aOperation fraction:aFraction respectFlipped:YES hints:nil];
}

// A browser of items shown three ways: mode 0 a grid of thumbnails, mode 1
// one column of large thumbnails, mode 2 a list (a table) beside a preview
// of the selected items (the draw view in a box). The items come from the
// data source; the grid matrix holds one cell per item.
@implementation SMKGridControl

// grows the grid to the data source's count and loads the new items
- (void)notifyOfAppendedItems
{
	if (dataSource == nil) {
		return;
	}
	NSInteger count = [dataSource numberOfItemsInGridControl:self];
	if ([_gridMatrix count] < (NSUInteger)count) {
		[_gridMatrix setCount:count];
	}
	[self _reloadDataFrom:[_gridMatrix count] to:count];
}

- (void)reloadData
{
	if (dataSource == nil) {
		return;
	}
	[_gridMatrix setCount:[dataSource numberOfItemsInGridControl:self]];
	[self _reloadDataFrom:0 to:[[_gridMatrix cells] count]];
}

// marks the cells aFrom..aTo for reloading from the data source
- (void)_reloadDataFrom:(NSUInteger)aFrom to:(NSUInteger)aTo
{
	if (dataSource == nil) {
		return;
	}
	[_gridMatrix stopThreadedCellUpdating];
	if (aFrom < [_gridMatrix count]) {
		[_gridMatrix setCellTitleAdditionalHeight:0.0];
	}
	for (unsigned int i = (unsigned int)aFrom; i < (unsigned int)aTo; i++) {
		[(SMKGridBaseCell *)[[_gridMatrix cells] objectAtIndex:i] setNeedsUpdateAsItem:i];
	}
	if ([self mode] == 2) {
		[_tableView reloadData];
		[_drawView setNeedsDisplay:YES];
	} else {
		[_gridMatrix sizeToCells];
		[_gridMatrix startThreadedCellUpdating];
		[_scrollView reflectScrolledClipView:[_scrollView contentView]];
	}
	if (aFrom == 0) {
		[_scrollView setNeedsDisplay:YES];
	}
}

- (void)setDataSource:(id)aSource
{
	[aSource retain];
	[dataSource release];
	dataSource = aSource;
	if ([aSource respondsToSelector:@selector(cellClass)]) {
		[_gridMatrix setCellClass:[dataSource cellClass]];
	}
}

- (id)dataSource
{
	return dataSource;
}

- (id)titleForItemAt:(NSInteger)aAt
{
	if (dataSource != nil && (int)aAt < (int)[dataSource numberOfItemsInGridControl:self]) {
		return [dataSource gridControl:self titleForItemAt:aAt];
	}
	return nil;
}

- (void *)imageDataForItemAt:(NSInteger)aAt
{
	if (dataSource != nil && (int)aAt < (int)[dataSource numberOfItemsInGridControl:self]) {
		return [dataSource gridControl:self imageDataForItemAt:aAt];
	}
	return NULL;
}

- (id)imageForItemAt:(NSInteger)aAt
{
	if (dataSource != nil && (int)aAt < (int)[dataSource numberOfItemsInGridControl:self]) {
		return [dataSource gridControl:self imageForItemAt:aAt];
	}
	return nil;
}

- (void)onMouseDown:(id)aDown
{
	if ([aDown clickCount] == 1) {
		[_gridMatrix sendAction];
	} else {
		[_gridMatrix sendDoubleAction];
	}
}

- (void)setTarget:(id)aTarget
{
	[_gridMatrix setTarget:aTarget];
	[_tableView setTarget:aTarget];
}

- (void)setDoubleAction:(SEL)aAction
{
	[_gridMatrix setDoubleAction:aAction];
	[_tableView setDoubleAction:aAction];
}

- (void)setAction:(SEL)aAction
{
	[_gridMatrix setAction:aAction];
	[_tableView setAction:aAction];
}

- (void)setSelectedItem:(id)aItem byExtendingSelection:(BOOL)aSelection
{
	[self selectItemAtIndex:[[_gridMatrix cells] indexOfObject:aItem] byExtendingSelection:aSelection];
}

- (id)selectedItems
{
	return [_gridMatrix selectedCells];
}

- (id)selectedItem
{
	return [_gridMatrix selectedCell];
}

- (void)selectItemAtIndex:(NSUInteger)aIndex byExtendingSelection:(BOOL)aSelection
{
	if (!aSelection) {
		[_gridMatrix deselectAllCells];
	}
	if (aIndex != NSNotFound) {
		[_gridMatrix setSelectionFrom:aIndex to:aIndex anchor:aIndex highlight:YES];
	}
	[self _updateSelection];
}

- (NSUInteger)selectedItemIndex
{
	return [[_gridMatrix cells] indexOfObject:[_gridMatrix selectedCell]];
}

- (NSUInteger)count
{
	return [_gridMatrix count];
}

- (void)setTableViewAutofitTextDuringLiveResize:(BOOL)aResize
{
	[_tableView setAutofitTextDuringLiveResize:aResize];
}

- (void)setThreadedPreloadingEnabled:(BOOL)aEnabled
{
	_isThreadedPreloadingEnabled = aEnabled;
	[_gridMatrix enableThreadUpdater:aEnabled];
}

- (BOOL)isThreadedPreloadingEnabled
{
	return _isThreadedPreloadingEnabled;
}

- (BOOL)isTitlePreloadingEnabled
{
	if (dataSource != nil && [dataSource respondsToSelector:@selector(areTitlesCanBePreloadedInGridControl:)]) {
		return [dataSource areTitlesCanBePreloadedInGridControl:self];
	}
	return NO;
}

- (void)setCellControlSize:(NSInteger)aSize
{
	[_gridMatrix setControlSize:aSize];
}

- (void)setScrollerControlSize:(NSInteger)aSize
{
	[[_scrollView verticalScroller] setControlSize:aSize];
}

- (NSInteger)scrollerControlSize
{
	return (int)[[_scrollView verticalScroller] controlSize];
}

- (void)setSelectionStyle:(NSInteger)aStyle
{
	[_gridMatrix setSelectionStyle:aStyle];
}

- (NSInteger)selectionStyle
{
	return (int)[_gridMatrix selectionStyle];
}

- (void)setAllowsMultipleSelection:(BOOL)aSelection
{
	[_gridMatrix setAllowsMultipleSelection:aSelection];
	[_tableView setAllowsMultipleSelection:aSelection];
}

- (BOOL)allowsMultipleSelection
{
	return [_gridMatrix allowsMultipleSelection];
}

- (void)setThumbnailCachingEnabled:(BOOL)aEnabled
{
	[_gridMatrix setThumbnailCachingEnabled:aEnabled];
}

- (BOOL)isThumbnailCachingEnabled
{
	return [_gridMatrix isThumbnailCachingEnabled];
}

- (void)setMaxTitleHeight:(CGFloat)aHeight
{
	[_gridMatrix setMaxTitleHeight:aHeight];
}

- (void)setThumbnailSize:(NSSize)aSize
{
	[self setThumbnailSize:aSize andIntercellSpacing:NSZeroSize];
}

- (void)setThumbnailSize:(NSSize)aSize andIntercellSpacing:(NSSize)aSpacing
{
	_thumbnailSize = aSize;
	_thumbnailCellSize.height = (float)aSpacing.height + (float)aSize.height + 6.0f;
	_thumbnailCellSize.width = (float)aSpacing.width + (float)aSize.width + 6.0f;
	[_gridMatrix setCellContentSize:_thumbnailSize];
	if ([self mode] == 0) {
		[_gridMatrix setCellSize:_thumbnailCellSize];
		[_gridMatrix sizeToCells];
	}
}

// Copies the grid's selection to the list. As in the original, current
// systems select the rows one at a time without extending, so only the last
// selected item stays selected in the list.
- (void)_updateSelection
{
	if (_mode != 2) {
		return;
	}
	[_gridMatrix selectedCell];
	if ([_gridMatrix count] == 0) {
		return;
	}
	if (floor(NSAppKitVersionNumber) > 663.0) {
		NSEnumerator *enumerator = [[_gridMatrix selectedCells] objectEnumerator];
		id cell;
		while ((cell = [enumerator nextObject]) != nil) {
			NSUInteger row = [[_gridMatrix cells] indexOfObject:cell];
			[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		}
	} else {
		NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
		NSEnumerator *enumerator = [[_gridMatrix selectedCells] objectEnumerator];
		id cell;
		while ((cell = [enumerator nextObject]) != nil) {
			[rows addIndex:[[_gridMatrix cells] indexOfObject:cell]];
		}
		[_tableView selectRowIndexes:rows byExtendingSelection:NO];
	}
}

- (void)viewDidEndLiveResize
{
}

- (void)viewWillStartLiveResize
{
}

// copies the list's selection to the grid and redraws the preview
- (void)tableViewSelectionDidChange:(id)aChange
{
	if ([_tableView selectedRow] < 0) {
		[_gridMatrix deselectAllCells];
		return;
	}
	[_gridMatrix deselectAllCells];
	NSIndexSet *rows = [_tableView selectedRowIndexes];
	for (NSUInteger row = [rows firstIndex]; row != NSNotFound; row = [rows indexGreaterThanIndex:row]) {
		[(SMKGridBaseCell *)[[_gridMatrix cells] objectAtIndex:row] updateContentIfNeeded];
		[_gridMatrix setSelectionFrom:row to:row anchor:row highlight:YES];
	}
	[_drawView setNeedsDisplay:YES];
}

- (void)setDragEnabled:(BOOL)aEnabled
{
	_isDragEnabled = aEnabled;
}

- (BOOL)isDragEnabled
{
	return _isDragEnabled;
}

// Lazily provides dragged data: the data source's own types, else the
// selected item's image as TIFF or the selected titles, one per line.
- (void)pasteboard:(id)aPasteboard provideDataForType:(id)aType
{
	NSArray *types = nil;
	if ([dataSource respondsToSelector:@selector(pasteboardTypesForGridControl:)]) {
		types = [dataSource pasteboardTypesForGridControl:self];
	}
	if ([dataSource respondsToSelector:@selector(gridControl:pasteboard:provideDataForType:)] &&
	    [types containsObject:aType]) {
		[dataSource gridControl:self pasteboard:aPasteboard provideDataForType:aType];
		return;
	}
	if ([aType isEqual:NSTIFFPboardType] && [[_gridMatrix selectedCells] count] == 1) {
		if ([[_gridMatrix selectedCell] image] == nil) {
			return;
		}
		[aPasteboard setData:[[[_gridMatrix selectedCell] image] TIFFRepresentation] forType:aType];
		return;
	}
	if (![aType isEqual:NSStringPboardType]) {
		return;
	}
	NSString *string;
	if ([[_gridMatrix selectedCells] count] == 1) {
		string = [[_gridMatrix selectedCell] title];
		if (string == nil || [string length] == 0) {
			return;
		}
	} else {
		NSMutableString *titles = [NSMutableString stringWithCapacity:0];
		NSEnumerator *enumerator = [[_gridMatrix selectedCells] objectEnumerator];
		id cell;
		while ((cell = [enumerator nextObject]) != nil) {
			[titles appendFormat:@"%@\n", [cell title]];
		}
		string = titles;
	}
	[aPasteboard setString:string forType:aType];
}

// starts a drag from aSource; a single item drags at half opacity
- (void)dragImage:(id)aImage imageOrigin:(NSPoint)aOrigin source:(id)aSource event:(id)aEvent
{
	if (!_isDragEnabled || aImage == nil) {
		return;
	}
	NSImage *faded = [[[NSImage alloc] initWithSize:[aImage size]] autorelease];
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSImage *image = aImage;
	if ([[_gridMatrix selectedCells] count] == 1) {
		[faded lockFocus];
		SMKDrawImageAtPoint(aImage, NSZeroPoint, NSCompositingOperationCopy, 0.5);
		[faded unlockFocus];
		image = faded;
	}
	[self writeSelectionToPasteboard:pasteboard withImage:aImage];
	[aSource dragImage:image at:aOrigin offset:NSZeroSize event:aEvent pasteboard:pasteboard source:self slideBack:YES];
}

// declares the data source's types plus TIFF (one item with an image) and
// string (titles), then writes the data source's direct types
- (void)writeSelectionToPasteboard:(id)aPasteboard withImage:(id)aImage
{
	NSArray *types = nil;
	if ([dataSource respondsToSelector:@selector(pasteboardTypesForGridControl:)]) {
		types = [dataSource pasteboardTypesForGridControl:self];
	}
	if (types == nil) {
		types = [NSArray array];
	}
	if ([[_gridMatrix selectedCells] count] == 1 && aImage != nil && ![types containsObject:NSTIFFPboardType]) {
		types = [types arrayByAddingObject:NSTIFFPboardType];
	}
	BOOL titles = YES;
	if ([[_gridMatrix selectedCells] count] < 2) {
		NSString *title = [[_gridMatrix selectedCell] title];
		titles = title != nil && [title length] != 0;
	}
	if (titles && ![types containsObject:NSStringPboardType]) {
		types = [types arrayByAddingObject:NSStringPboardType];
	}
	[aPasteboard declareTypes:types owner:self];
	if ([dataSource respondsToSelector:@selector(directPasteboardTypesForGridControl:)] &&
	    [dataSource respondsToSelector:@selector(gridControl:pasteboard:provideDataForType:)]) {
		NSEnumerator *enumerator = [[dataSource directPasteboardTypesForGridControl:self] objectEnumerator];
		id type;
		while ((type = [enumerator nextObject]) != nil) {
			[dataSource gridControl:self pasteboard:aPasteboard provideDataForType:type];
		}
	}
}

// the dragged image faded, with a count badge in its corner
- (id)imageForMultipleDraggedItemsForImage:(id)aImage
{
	int count;
	if ([self mode] == 2) {
		count = (int)[_tableView numberOfSelectedRows];
	} else {
		count = (int)[[_gridMatrix selectedCells] count];
	}
	NSBundle *bundle = [NSBundle bundleForClass:[SMKGridControl class]];
	long digits = lrint(log10((double)count));
	if (digits < 2) {
		digits = 2;
	} else if (digits > 5) {
		digits = 5;
	}
	NSString *name = [NSString stringWithFormat:@"dragBadge_%i", (int)digits];
	NSImage *badge = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:name ofType:@"tiff"]] autorelease];
	SMKStringRenderer *renderer = [SMKStringRenderer sharedRenderer];
	[renderer setAlignment:NSTextAlignmentCenter];
	[renderer setContainerWidth:[badge size].width];
	[renderer setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	NSSize badgeSize = [badge size];
	NSSize imageSize = [aImage size];
	float width = (float)badgeSize.width < (float)imageSize.width ? (float)imageSize.width : (float)badgeSize.width;
	float height = (float)badgeSize.height < (float)imageSize.height ? (float)imageSize.height : (float)badgeSize.height;
	NSImage *result = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
	[result lockFocus];
	SMKDrawImageAtPoint(aImage, NSMakePoint(0.0, height - (float)[aImage size].height), NSCompositingOperationSourceOver, 0.5);
	float x = width - (float)[badge size].width;
	SMKDrawImageAtPoint(badge, NSMakePoint(x, 0.0), NSCompositingOperationSourceOver, 1.0);
	[renderer drawString:[[NSNumber numberWithInt:count] stringValue] atPoint:NSMakePoint(x, -1.0)
	           withColor:[NSColor whiteColor]];
	[result unlockFocus];
	return result;
}

- (void)setStringForEmptyTitle:(id)aTitle
{
	if (_stringForEmptyTitle != aTitle) {
		[_stringForEmptyTitle release];
		_stringForEmptyTitle = [aTitle retain];
	}
}

- (id)stringForEmptyTitle
{
	return _stringForEmptyTitle;
}

// the placeholder in light gray 20 pt, centered in aRect
- (void)drawPlaceholderStringInRect:(NSRect)aRect
{
	NSString *placeholder = [self placeholderString];
	NSFont *font = [NSFont systemFontOfSize:20.0];
	float y = aRect.origin.y;
	float height = aRect.size.height;
	SMKStringRenderer *renderer = [SMKStringRenderer sharedRenderer];
	[renderer setContainerWidth:aRect.size.width];
	[renderer setFont:font];
	[renderer setAlignment:NSTextAlignmentCenter];
	NSRect bounds = [renderer boundingRectOfString:placeholder];
	if (ceilf(((float)aRect.size.height - (float)bounds.size.height) * 0.5f) > 0.0f) {
		float offset = (float)ceil((double)((float)aRect.size.height - (float)bounds.size.height) * 0.5);
		y = (float)aRect.origin.y + offset;
		height = (float)aRect.size.height - offset;
	}
	NSString *fitted = [renderer stringByFittingString:placeholder toSize:NSMakeSize(aRect.size.width, height) boundingRect:NULL];
	[renderer drawString:fitted atPoint:NSMakePoint(aRect.origin.x, y) withColor:[NSColor lightGrayColor]];
}

- (void)setPlaceholderString:(id)aString
{
	if (_placeholderString != aString) {
		[_placeholderString release];
		_placeholderString = [aString retain];
	}
}

- (id)placeholderString
{
	return _placeholderString;
}

- (NSInteger)mode
{
	return _mode;
}

// Switches between the grid (0), the single column (1, only with items) and
// the list with its preview (2).
- (void)setMode:(NSInteger)aMode
{
	if (_mode == aMode) {
		return;
	}
	if (aMode == 1 && [[_gridMatrix cells] count] == 0) {
		return;
	}
	if (_mode == 2) {
		[[_drawView superview] removeFromSuperview];
		[_scrollView setFrameSize:[self bounds].size];
		BOOL listWasFocused = [_tableView isEqual:[[self window] firstResponder]];
		[_scrollView setDocumentView:_gridMatrix];
		if (listWasFocused) {
			[[self window] makeFirstResponder:_gridMatrix];
		}
		[self adjustSubviews];
	}
	if (_mode == 0) {
		_thumbnailSize = [_gridMatrix cellContentSize];
		_thumbnailCellSize = [_gridMatrix cellSize];
		[_gridMatrix stopThreadedCellUpdating];
	}
	_mode = (int)aMode;
	if (aMode == 0) {
		[_gridMatrix setAutosizesCells:NO];
		[self setThumbnailSize:_thumbnailSize];
		[_gridMatrix setCellSize:_thumbnailCellSize];
		[_gridMatrix fitByWidth];
		[_gridMatrix startThreadedCellUpdating];
	}
	if (_mode == 1) {
		[_gridMatrix setColumnCount:1];
		[_gridMatrix setAutosizesCells:YES];
		[_gridMatrix resizeWithOldSuperviewSize:NSZeroSize];
		[_scrollView setVerticalLineScroll:[_gridMatrix cellSize].height];
		if ([[_gridMatrix cells] count] != 0) {
			NSUInteger index = [[_gridMatrix cells] indexOfObject:[_gridMatrix selectedCell]];
			if (index != 0) {
				[_gridMatrix scrollCellToVisibleAtRow:index column:0];
			}
		}
		[_gridMatrix setNeedsDisplay:YES];
	}
	if (_mode == 2) {
		NSRect bounds = [self bounds];
		[_scrollView setFrameSize:NSMakeSize((float)bounds.size.width * 0.33f, bounds.size.height)];
		BOOL gridWasFocused = [_gridMatrix isEqual:[[self window] firstResponder]];
		[_scrollView setDocumentView:_tableView];
		if (gridWasFocused) {
			[[self window] makeFirstResponder:_tableView];
		}
		[_tableView sizeLastColumnToFit];
		[self addSubview:[_drawView superview]];
		[self adjustSubviews];
		[self _updateSelection];
		if ([_tableView selectedRow] >= 0 && [_tableView selectedRow] < [_tableView numberOfRows]) {
			[_tableView scrollRowToVisible:[_tableView selectedRow]];
		}
	}
}

- (id)tableView
{
	return _tableView;
}

- (id)gridMatrix
{
	return _gridMatrix;
}

- (id)scrollView
{
	return _scrollView;
}

- (void)makeFirstResponder
{
	[[self window] makeFirstResponder:[_scrollView documentView]];
}

- (BOOL)acceptsFirstMouse:(id)aMouse
{
	return YES;
}

- (void)encodeWithCoder:(id)aCoder
{
	[aCoder encodeFloat:(float)_mode forKey:@"mode"];
	[aCoder encodeSize:_thumbnailSize forKey:@"thumbnailSize"];
	[aCoder encodeSize:_thumbnailCellSize forKey:@"thumbnailCellSize"];
	[aCoder encodeBool:_isThreadedPreloadingEnabled forKey:@"isThreadedPreloadingEnabled"];
	[aCoder encodeConditionalObject:dataSource forKey:@"dataSource"];
	[aCoder encodeObject:_scrollView forKey:@"scrollView"];
	[aCoder encodeObject:_gridMatrix forKey:@"gridMatrix"];
	[aCoder encodeObject:_tableView forKey:@"tableView"];
	[aCoder encodeObject:_drawView forKey:@"drawView"];
	[aCoder encodeObject:_placeholderString forKey:@"placeholderString"];
	[aCoder encodeObject:_stringForEmptyTitle forKey:@"stringForEmptyTitle"];
	[aCoder encodeBool:_isDragEnabled forKey:@"isDragEnabled"];
	[super encodeWithCoder:aCoder];
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self == nil) {
		return nil;
	}
	_mode = (int)[aCoder decodeFloatForKey:@"mode"];
	_thumbnailSize = [aCoder decodeSizeForKey:@"thumbnailSize"];
	_thumbnailCellSize = [aCoder decodeSizeForKey:@"thumbnailCellSize"];
	_isThreadedPreloadingEnabled = [aCoder decodeBoolForKey:@"isThreadedPreloadingEnabled"];
	dataSource = [[aCoder decodeObjectForKey:@"dataSource"] retain];
	_scrollView = [[aCoder decodeObjectForKey:@"scrollView"] retain];
	_gridMatrix = [[aCoder decodeObjectForKey:@"gridMatrix"] retain];
	_tableView = [[aCoder decodeObjectForKey:@"tableView"] retain];
	_drawView = [[aCoder decodeObjectForKey:@"drawView"] retain];
	_placeholderString = [[aCoder decodeObjectForKey:@"placeholderString"] retain];
	_stringForEmptyTitle = [[aCoder decodeObjectForKey:@"stringForEmptyTitle"] retain];
	_isDragEnabled = [aCoder decodeBoolForKey:@"isDragEnabled"];
	return self;
}

- (void)dealloc
{
	[_placeholderString release];
	[_gridMatrix enableThreadUpdater:NO];
	[_gridMatrix stopThreadedCellUpdating];
	[[_drawView superview] release];
	[_tableView release];
	[_gridMatrix release];
	[dataSource autorelease];
	dataSource = nil;
	[super dealloc];
}

- (void)awakeFromNib
{
	if (dataSource != nil) {
		[self reloadData];
	}
}

// builds the scroll view with the grid matrix, the list table, and the
// preview box (added in mode 2)
- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	if (self == nil) {
		return nil;
	}
	dataSource = nil;
	_mode = -1;
	_isDragEnabled = YES;
	_placeholderString = [[NSBundle bundleForClass:[SMKGridControl class]]
	                         localizedStringForKey:@"Grid Control Empty" value:@"" table:nil];
	[_placeholderString retain];
	_stringForEmptyTitle = @"??";
	[self setThumbnailSize:NSMakeSize(64.0, 64.0)];
	[self setMaxTitleHeight:48.0];

	_scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
	_gridMatrix = [[SMKGridMatrix alloc] initWithFrame:[self bounds]];
	_tableView = [[SMKGridTableView alloc] initWithFrame:[_scrollView bounds]];
	_drawView = [[SMKGridDrawView alloc] initWithFrame:[self bounds]];
	NSBox *box = [[NSBox alloc] initWithFrame:[self bounds]];
	[box setTitlePosition:NSBelowBottom];
	[box setBorderType:NSLineBorder];
	[box setBoxType:NSBoxOldStyle];
	[_drawView autorelease];
	[box setContentView:_drawView];
	[box setTitle:@""];
	[_drawView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[_scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[_scrollView setContentView:[SMKGridClipView contentViewWithFrame:NSZeroRect]];
	[_scrollView setHasVerticalScroller:YES];
	[_scrollView setBorderType:NSGrooveBorder];
	[_scrollView setDocumentView:_gridMatrix];
	[self setScrollerControlSize:NSControlSizeRegular];
	[self setVertical:YES];
	[_scrollView autorelease];
	[self addSubview:_scrollView];
	[self setMode:0];
	[_scrollView setVerticalLineScroll:[_gridMatrix cellSize].height];
	[_scrollView setVerticalPageScroll:0.0];
	[_gridMatrix sizeToCells];
	[_gridMatrix setOwningGridControl:self];

	NSTableColumn *column = [NSTableColumn new];
	[column setDataCell:[SMKGridTextFieldCell new]];
	[column setMinWidth:0.0];
	[_tableView setHeaderView:nil];
	[_tableView addTableColumn:column];
	[_tableView setDataSource:(id)_gridMatrix];
	[_tableView setDelegate:(id)self];
	[_tableView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[_tableView sizeLastColumnToFit];
	[self setThreadedPreloadingEnabled:NO];
	return self;
}

@end
