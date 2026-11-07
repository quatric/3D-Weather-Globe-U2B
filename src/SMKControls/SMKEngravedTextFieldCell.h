// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKEngravedTextFieldCell.m
#import "SMKControlsPrefix.h"


@interface SMKEngravedTextFieldCell : NSTextFieldCell
{
    NSColor *_secondaryTextColor;
}
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (id)initWithTextFieldCell:(id)aCell;
- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView;
- (void)_acceptPropertiesFromTextFieldCell:(id)aCell;
- (id)_secondaryTextColor;
- (id)secondaryTextColor;
- (void)setSecondaryTextColor:(id)aColor;
- (void)dealloc;
@end

