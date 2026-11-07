// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKEngravedTextFieldCell.m
#import "SMKEngravedTextFieldCell.h"

// A text field cell that draws its text a second time, one point lower, in a
// lighter color.
@implementation SMKEngravedTextFieldCell

- (void)encodeWithCoder:(id)aCoder
{
	[super encodeWithCoder:aCoder];
	if ([aCoder respondsToSelector:@selector(allowsKeyedCoding)] && [aCoder allowsKeyedCoding]) {
		[aCoder encodeObject:_secondaryTextColor forKey:@"smk_secondaryTextColor"];
	}
	else {
		int version = 0;
		[aCoder encodeValueOfObjCType:"i" at:&version];
		[aCoder encodeObject:_secondaryTextColor];
	}
}

- (id)initWithCoder:(id)aCoder
{
	self = [super initWithCoder:aCoder];
	if (self == nil) {
		return nil;
	}
	id color;
	if ([aCoder respondsToSelector:@selector(allowsKeyedCoding)] && [aCoder allowsKeyedCoding]) {
		color = [aCoder containsValueForKey:@"smk_secondaryTextColor"]
			? [aCoder decodeObjectForKey:@"smk_secondaryTextColor"] : nil;
	}
	else {
		int version;
		[aCoder decodeValueOfObjCType:"i" at:&version];
		color = [aCoder decodeObject];
	}
	[self setSecondaryTextColor:color];
	return self;
}

- (id)initWithTextFieldCell:(id)aCell
{
	self = [self initTextCell:[aCell title]];
	if (self != nil) {
		[self _acceptPropertiesFromTextFieldCell:aCell];
	}
	return self;
}

- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView
{
	NSColor *color = [[self textColor] retain];
	NSRect shadowFrame = aFrame;
	[self setTextColor:[self _secondaryTextColor]];
	shadowFrame.origin.y = ([aView isFlipped] ? 1.0f : -1.0f) + (float)shadowFrame.origin.y;
	[super drawInteriorWithFrame:shadowFrame inView:aView];
	[self setTextColor:color];
	[super drawInteriorWithFrame:aFrame inView:aView];
	[color release];
}

- (void)_acceptPropertiesFromTextFieldCell:(id)aCell
{
	[self setBezeled:[aCell isBezeled]];
	[self setEditable:[aCell isEditable]];
	[self setTarget:[aCell target]];
	[self setAction:[aCell action]];
	[self setControlSize:[aCell controlSize]];
	[self setFont:[aCell font]];
	[self setBackgroundColor:[aCell backgroundColor]];
	[self setDrawsBackground:[aCell drawsBackground]];
	[self setTextColor:[aCell textColor]];
	[self setTitle:[aCell title]];
	[self setAlignment:[aCell alignment]];
}

- (id)_secondaryTextColor
{
	return _secondaryTextColor != nil ? _secondaryTextColor : [NSColor whiteColor];
}

- (id)secondaryTextColor
{
	return _secondaryTextColor;
}

- (void)setSecondaryTextColor:(id)aColor
{
	[aColor retain];
	[_secondaryTextColor release];
	_secondaryTextColor = aColor;
	id view = [self controlView];
	if ([view isKindOfClass:[NSControl class]]) {
		[view updateCell:self];
	}
}

- (void)dealloc
{
	[_secondaryTextColor release];
	_secondaryTextColor = nil;
	[super dealloc];
}

@end
