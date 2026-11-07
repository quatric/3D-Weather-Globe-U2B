#import "TextFieldCell.h"

@implementation TextFieldCell

- (void)drawWithFrame:(NSRect)aFrame inView:(id)aView
{
    [aView setKeyboardFocusRingNeedsDisplayInRect:[aView bounds]];
    [super drawWithFrame:aFrame inView:aView];
}

- (void)endEditing:(id)aEditing
{
    [super endEditing:aEditing];
}

- (void)selectWithFrame:(NSRect)aFrame inView:(id)aView editor:(id)aEditor delegate:(id)aDelegate start:(NSInteger)aStart length:(NSInteger)aLength
{
    [super selectWithFrame:aFrame inView:aView editor:aEditor delegate:aDelegate start:aStart length:aLength];
    [[NSNotificationCenter defaultCenter] postNotificationName:kEditCellDidStartEditingNotification object:aView];
}

@end
