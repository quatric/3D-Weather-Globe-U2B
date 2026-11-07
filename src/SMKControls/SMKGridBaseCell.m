// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Cells/SMKGridBaseCell.m
#import "SMKGridBaseCell.h"

static SMKStringRenderer *__sStringRenderer;
static NSImage *__kLoadingStatusImage;
static NSString *const __kLoadingStatusString = @"?";

// Draws an image upright with its bottom-left corner at aPoint, as the
// removed -compositeToPoint:operation: did whatever the context's flipping.
static void SMKCompositeImage(NSImage *aImage, NSPoint aPoint, NSCompositingOperation aOperation)
{
	NSRect to;
	to.size = [aImage size];
	to.origin = aPoint;
	if ([[NSGraphicsContext currentContext] isFlipped]) {
		to.origin.y -= to.size.height;
	}
	[aImage drawInRect:to fromRect:NSZeroRect operation:aOperation fraction:1.0 respectFlipped:YES hints:nil];
}

// what NSFont's removed -defaultLineHeightForFont gave
static float SMKDefaultLineHeight(NSFont *aFont)
{
	static NSLayoutManager *layoutManager;
	if (layoutManager == nil) {
		layoutManager = [[NSLayoutManager alloc] init];
	}
	return [layoutManager defaultLineHeightForFont:aFont];
}

// A grid item: a thumbnail with a title under it. The grid matrix it is
// drawn in (its control view) holds the layout settings shared by all cells.
@implementation SMKGridBaseCell

- (void)encodeWithCoder:(id)aCoder
{
	[super encodeWithCoder:aCoder];
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self != nil) {
		[self _initVars];
	}
	return self;
}

- (id)copyWithZone:(NSZone *)aZone
{
	SMKGridBaseCell *copy = [super copyWithZone:aZone];
	[copy _initVars];
	[copy _setAltImage:[[_altImage copy] autorelease]];
	[copy setTitle:[[[self title] copy] autorelease]];
	return copy;
}

- (void)_initVars
{
	_altImage = nil;
	_textImage = nil;
	_textValue = nil;
	_contentSize = NSZeroSize;
	_isGraphicsContentReady = YES;
	_isUpdateNeeded = NO;
}

- (void)_setAltImage:(id)aImage
{
	[_altImage autorelease];
	_altImage = [aImage retain];
}

- (id)_altImage
{
	return _altImage;
}

// The title's rectangle: centered horizontally, at the bottom of the bounds
// less the matrix's title height. With caching on, the title is rendered once
// into _textImage, cut to the matrix's maximum title height.
- (NSRect)textPlacementRectForBounds:(NSRect)aBounds
{
	SMKGridMatrix *matrix = (SMKGridMatrix *)[self controlView];
	NSFont *font = [matrix textFont];
	float maxHeight = [matrix maxTitleHeight];
	NSString *title = [self title];
	if (![matrix isCacheAllowed]) {
		NSRect text = NSZeroRect;
		if (title != nil && [title length] != 0) {
			[__sStringRenderer setContainerWidth:aBounds.size.width];
			[__sStringRenderer setFont:font];
			text = [__sStringRenderer boundingRectOfString:title];
			if (maxHeight > 0.0f && (float)text.size.height > maxHeight) {
				text.size.height = maxHeight;
			}
		}
		return NSMakeRect((float)aBounds.origin.x + (float)text.origin.x,
		                  ((float)aBounds.origin.y + (float)aBounds.size.height) - (float)text.size.height,
		                  text.size.width, text.size.height);
	}

	if (![font isEqual:_textFont]) {
		[_textImage release];
		_textImage = nil;
		[_textFont release];
		_textFont = [font retain];
		[__sStringRenderer setFont:_textFont];
	}
	NSSize textSize;
	if (_textImage == nil) {
		NSRect text = NSZeroRect;
		BOOL fits = YES;
		if (title != nil && [title length] != 0) {
			[__sStringRenderer setContainerWidth:aBounds.size.width];
			[__sStringRenderer setFont:font];
			text = [__sStringRenderer boundingRectOfString:title];
			if (maxHeight > 0.0f && (float)text.size.height > maxHeight) {
				text.size.height = maxHeight;
				fits = NO;
			}
		}
		if (!NSIsEmptyRect(text)) {
			if (!fits) {
				title = [__sStringRenderer stringByFittingString:title toSize:text.size boundingRect:NULL];
			}
			_textImage = [[NSImage alloc] initWithSize:text.size];
			[_textImage setFlipped:YES];
			[_textImage lockFocus];
			[__sStringRenderer setContainerWidth:aBounds.size.width];
			[__sStringRenderer drawString:title atPoint:NSMakePoint(-(float)text.origin.x, 0.0) withColor:nil];
			[_textImage unlockFocus];
			[matrix setCellTitleAdditionalHeight:text.size.height];
		}
		textSize = text.size;
	} else {
		textSize = [_textImage size];
	}
	float additional = [matrix cellTitleAdditionalHeight];
	NSRect result;
	result.origin.y = ((float)aBounds.origin.y + (float)aBounds.size.height) - additional;
	result.origin.x = ceilf((float)((double)(float)aBounds.origin.x +
	                                (double)((float)aBounds.size.width - (float)textSize.width) * 0.5));
	result.size = textSize;
	return result;
}

// the bounds above the title, made square if wider than tall
- (NSRect)graphicContentPlacementRectForBounds:(NSRect)aBounds
{
	NSRect result = aBounds;
	float titleHeight;
	if (![(SMKGridMatrix *)[self controlView] isCacheAllowed]) {
		titleHeight = [self textPlacementRectForBounds:aBounds].size.height;
	} else {
		titleHeight = [(SMKGridMatrix *)[self controlView] cellTitleAdditionalHeight];
	}
	if (titleHeight > 0.0f) {
		result.size.height = (float)result.size.height - (titleHeight + 6.0f);
	}
	if (result.size.height < aBounds.size.width) {
		result.origin.x = (float)result.origin.x + ((float)aBounds.size.width - (float)result.size.height) * 0.5f;
		result.size.width = result.size.height;
	}
	return result;
}

// the graphic content's size scaled down (never up) to fit aBounds
- (NSSize)cachedImageSizeForBounds:(NSSize)aBounds
{
	NSSize size = [self graphicContentSize];
	if ((float)size.width <= 1.0f || (float)size.height <= 1.0f) {
		return NSZeroSize;
	}
	float scale = (float)aBounds.height / (float)size.height;
	if ((float)aBounds.width / (float)size.width <= scale) {
		scale = (float)aBounds.width / (float)size.width;
	}
	if (scale > 1.0f) {
		scale = 1.0f;
	}
	return NSMakeSize(scale * (float)size.width, (float)size.height * scale);
}

- (NSSize)graphicContentSize
{
	if ([self image] == nil) {
		return NSZeroSize;
	}
	return [[self image] size];
}

- (void)setGraphicsContentReady:(BOOL)aReady
{
	_isGraphicsContentReady = aReady;
}

// drops the caches when the matrix's cell size changes
- (void)updateContentSize
{
	SMKGridMatrix *matrix = (SMKGridMatrix *)[self controlView];
	NSSize size = matrix != nil ? [matrix cellContentSize] : NSZeroSize;
	if (NSEqualSizes(_contentSize, size) && !NSEqualSizes(NSZeroSize, size)) {
		return;
	}
	[self emptyCache];
	if (fabsf((float)_contentSize.width - (float)size.width) > 0.001f) {
		[_textImage release];
		_textImage = nil;
	}
	_contentSize = size;
}

- (void)emptyCache
{
	[_altImage release];
	_altImage = nil;
}

- (void)updateTitleIfNeeded
{
	if (_isUpdateNeeded) {
		[self setTitle:[[(SMKGridMatrix *)[self controlView] owningGridControl] titleForItemAt:_dataNo]];
	}
}

// fetches the item's image and title from the grid control
- (void)updateContentIfNeeded
{
	if (!_isUpdateNeeded) {
		return;
	}
	_isUpdateNeeded = NO;
	SMKGridControl *grid = [(SMKGridMatrix *)[self controlView] owningGridControl];
	if ([self useImageData]) {
		[self setImageData:[grid imageDataForItemAt:_dataNo]];
	} else {
		[self setImage:[grid imageForItemAt:_dataNo]];
	}
	[self setTitle:[[(SMKGridMatrix *)[self controlView] owningGridControl] titleForItemAt:_dataNo]];
}

- (void)setNeedsUpdateAsItem:(NSInteger)aItem
{
	_dataNo = (int)aItem;
	_isUpdateNeeded = YES;
}

- (void)setImageData:(void *)aData
{
	[self setEnabled:aData != NULL];
	if ([self imageData] != aData) {
		[self emptyCache];
	}
}

- (void)setImage:(id)aImage
{
	[self setEnabled:aImage != nil];
	if ([self image] != aImage) {
		[self emptyCache];
		[super setImage:aImage];
		[[self image] setFlipped:YES];
	}
}

- (void *)imageData
{
	return NULL;
}

- (BOOL)hasGraphicComponent
{
	if ([self useImageData]) {
		return [self imageData] != NULL;
	}
	return [self image] != nil;
}

- (void)setTitle:(id)aTitle
{
	if (aTitle != _textValue) {
		[_textValue release];
		_textValue = [aTitle retain];
		[_textImage release];
		_textImage = nil;
	}
}

- (id)title
{
	return _textValue;
}

- (void)drawCachingGraphicContentInRect:(NSRect)aRect
{
	if ([self image] != nil) {
		NSRect from = NSZeroRect;
		from.size = [[self image] size];
		[[self image] drawInRect:aRect fromRect:from operation:NSCompositingOperationSourceOver fraction:1.0];
	}
}

// Renders the thumbnail at aSize. A newly rendered image is returned
// retained and _altImage keeps what it held before, as in the original.
- (id)cachedImageWithSize:(NSSize)aSize
{
	[self updateContentIfNeeded];
	NSImage *previous = _altImage;
	if (![self hasGraphicComponent]) {
		return nil;
	}
	SMKGridMatrix *matrix = (SMKGridMatrix *)[self controlView];
	if (_altImage == nil || ![matrix isCacheAllowed] || ![matrix isThumbnailCachingEnabled]) {
		[self cacheGraphicContentWithSize:aSize];
	}
	NSImage *result = _altImage;
	_altImage = previous;
	return result;
}

- (void)cacheGraphicContentWithSize:(NSSize)aSize
{
	NSSize size = [self cachedImageSizeForBounds:aSize];
	if (NSEqualSizes(size, NSZeroSize)) {
		return;
	}
	NSImage *image = [[NSImage alloc] initWithSize:size];
	[image setScalesWhenResized:YES];
	[image setFlipped:YES];
	[image lockFocus];
	[self drawCachingGraphicContentInRect:NSMakeRect(0.0, 0.0, size.width, size.height)];
	[image unlockFocus];
	_altImage = image;
}

// draws the thumbnail centered in aFrame, from the cache when caching is on
- (void)drawGraphicContentInFrame:(NSRect)aFrame
{
	if (![self hasGraphicComponent]) {
		return;
	}
	SMKGridMatrix *matrix = (SMKGridMatrix *)[self controlView];
	BOOL caching = [matrix isCacheAllowed] && [matrix isThumbnailCachingEnabled];
	if (_altImage == nil) {
		if (caching) {
			if ([(SMKGridMatrix *)[self controlView] isThreadedCellUpdatingEnabled]) {
				[(SMKGridMatrix *)[self controlView] setNeedsUpdateCell:self];
			} else {
				[self cacheGraphicContentWithSize:aFrame.size];
			}
		}
		if (_altImage == nil && caching) {
			return;
		}
	}
	NSSize size;
	if (caching && _altImage != nil) {
		size = [_altImage size];
	} else {
		size = [self cachedImageSizeForBounds:aFrame.size];
	}
	NSRect rect;
	rect.origin.x = (float)(trunc((double)((float)aFrame.size.width - (float)size.width) * 0.5) + (double)(float)aFrame.origin.x);
	rect.origin.y = (float)(trunc((double)((float)aFrame.size.height - (float)size.height) * 0.5) + (double)(float)aFrame.origin.y);
	rect.size = size;
	if (caching && _altImage != nil) {
		SMKCompositeImage(_altImage, NSMakePoint(rect.origin.x, (float)rect.origin.y + (float)rect.size.height),
		                  NSCompositingOperationSourceOver);
	} else {
		[self drawCachingGraphicContentInRect:rect];
	}
}

// Selection styles 1 and 2 frame the selected title (a rounded rectangle for
// several lines, a pill for one) and the thumbnail (filled for 1, outlined
// for 2).
- (void)drawSelectionInRect:(NSRect)aRect cellFrame:(NSRect)aFrame
{
	SMKGridMatrix *matrix = (SMKGridMatrix *)[self controlView];
	NSInteger style = [matrix selectionStyle];
	NSRect text = [self textPlacementRectForBounds:aRect];
	if ([self state] == NSControlStateValueOff || ![matrix isDrawingPermitted] || (NSUInteger)(style - 1) > 1) {
		return;
	}
	if ([self title] != nil) {
		[(NSColor *)[matrix textFrameColor] set];
		float textHeight = text.size.height;
		NSBezierPath *path;
		if (SMKDefaultLineHeight([matrix textFont]) < textHeight) {
			text = NSInsetRect(NSIntersectionRect(aFrame, NSInsetRect(text, -3.0, 0.0)), 1.0, 0.0);
			path = [NSBezierPath smkRoundedBorderPathWithRect:text cornerRadius:3.0];
		} else {
			text = NSInsetRect(NSIntersectionRect(aFrame, NSInsetRect(text, -6.0, 0.0)), 1.0, 0.0);
			path = [NSBezierPath smkRolloverStyleBorderPathWithRect:text];
		}
		[path fill];
	}
	NSRect graphic = NSInsetRect([self graphicContentPlacementRectForBounds:aRect], -3.0, -3.0);
	float inset = style == 1 ? -1.0f : 1.0f;
	graphic = NSInsetRect(graphic, inset, inset);
	[(NSColor *)[matrix imageFrameColor] set];
	NSBezierPath *path = [NSBezierPath smkFinderSelectionStyleBorderPathWithRect:graphic];
	if (style == 1) {
		[path fill];
	} else {
		[path stroke];
	}
}

- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView
{
	if ([self title] != nil && [[self title] length] != 0) {
		NSRect text = [self textPlacementRectForBounds:aFrame];
		if (![aView isCacheAllowed] || [self state] != NSControlStateValueOff) {
			NSString *title = [__sStringRenderer stringByFittingString:[self title]
			                                                    toSize:NSMakeSize(aFrame.size.width, text.size.height)
			                                              boundingRect:NULL];
			[__sStringRenderer setContainerWidth:aFrame.size.width];
			NSColor *color = nil;
			if ([self state] != NSControlStateValueOff && [aView selectionStyle] != 0) {
				color = [NSColor whiteColor];
			}
			[__sStringRenderer drawString:title atPoint:NSMakePoint(aFrame.origin.x, text.origin.y) withColor:color];
		} else {
			SMKCompositeImage(_textImage, NSMakePoint(text.origin.x, (float)text.origin.y + (float)text.size.height),
			                  NSCompositingOperationSourceOver);
		}
	}
	NSRect graphic = [self graphicContentPlacementRectForBounds:aFrame];
	if (_isGraphicsContentReady) {
		[self drawGraphicContentInFrame:[self graphicContentPlacementRectForBounds:aFrame]];
		return;
	}
	if (!NSEqualSizes([__kLoadingStatusImage size], graphic.size) && !NSEqualSizes(NSZeroSize, graphic.size)) {
		[__kLoadingStatusImage release];
		__kLoadingStatusImage = [[self _makeLoadingStatusImageWithSize:graphic.size] retain];
	}
	SMKCompositeImage(__kLoadingStatusImage,
	                  NSMakePoint(graphic.origin.x, (float)graphic.origin.y + (float)graphic.size.height),
	                  NSCompositingOperationSourceOver);
}

// draws the cell's content area, the matrix's cell content size centered in aFrame
- (void)drawWithFrame:(NSRect)aFrame inView:(id)aView
{
	if (_isGraphicsContentReady) {
		[self updateContentSize];
		if (_isUpdateNeeded) {
			if ([aView isThreadedCellUpdatingEnabled]) {
				[self updateTitleIfNeeded];
				[aView setNeedsUpdateCell:self];
			} else {
				[self updateContentIfNeeded];
			}
		}
	}
	NSSize size = aView != nil ? [(SMKGridMatrix *)aView cellContentSize] : NSZeroSize;
	NSRect content;
	content.origin.x = truncf((float)((double)(float)aFrame.origin.x + (double)((float)aFrame.size.width - (float)size.width) * 0.5));
	content.origin.y = truncf((float)((double)(float)aFrame.origin.y + (double)((float)aFrame.size.height - (float)size.height) * 0.5));
	content.size = size;
	if (NSIsEmptyRect(content)) {
		return;
	}
	[self drawSelectionInRect:content cellFrame:aFrame];
	if ([aView isDrawingPermitted]) {
		[self drawInteriorWithFrame:content inView:aView];
	}
}

// A "?" in the middle of an image of aSize. The original swaps the inset
// rectangle's x and y when centering it; that is kept.
- (id)_makeLoadingStatusImageWithSize:(NSSize)aSize
{
	NSRect rect = NSZeroRect;
	rect.size = aSize;
	rect = NSInsetRect(rect, (float)aSize.width * 0.25f, (float)aSize.height * 0.25f);
	NSImage *image = [[[NSImage alloc] initWithSize:aSize] autorelease];
	NSSize textSize = [__kLoadingStatusString sizeWithAttributes:nil];
	NSPoint point;
	point.y = (float)((double)(float)rect.origin.x + (double)((float)rect.size.height - (float)textSize.height) * 0.5);
	point.x = (float)((double)(float)rect.origin.y + (double)((float)rect.size.width - (float)textSize.width) * 0.5);
	[image lockFocus];
	[__kLoadingStatusString drawAtPoint:point withAttributes:nil];
	[image unlockFocus];
	[image setFlipped:YES];
	return image;
}

- (BOOL)useImageData
{
	return NO;
}

- (id)controlView
{
	return [super controlView];
}

- (void)dealloc
{
	[_textValue release];
	[_textImage release];
	[_textFont release];
	[self emptyCache];
	[super dealloc];
}

- (id)init
{
	if (__sStringRenderer == nil) {
		__sStringRenderer = [SMKStringRenderer new];
		[__sStringRenderer setAlignment:NSTextAlignmentCenter];
	}
	self = [super init];
	if (self != nil) {
		[self _initVars];
		[self setImage:nil];
		[self setTitle:nil];
		[self setEnabled:NO];
	}
	return self;
}

@end
