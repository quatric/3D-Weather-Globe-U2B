#import "AboutController.h"

@implementation AboutController

- (void)showPanel
{
    if (_panel == nil && ![NSBundle loadNibNamed:@"About" owner:self])
        return;
    [_tabView selectFirstTabViewItem:self];
    [_panel center];
    [_panel makeKeyAndOrderFront:self];
}

- (void)awakeFromNib
{
    id textView = [_creditsView documentView];
    if ([textView respondsToSelector:@selector(setLinkTextAttributes:)]
        && [textView respondsToSelector:@selector(linkTextAttributes)]) {
        NSMutableDictionary *attributes = [[textView linkTextAttributes] mutableCopy];
        NSCursor *cursor = [[[NSCursor alloc] initWithImage:[NSImage imageNamed:@"hand_big"]
                                                    hotSpot:NSMakePoint(6.0, 0.0)] autorelease];
        [attributes setObject:cursor forKey:NSCursorAttributeName];
        [textView setLinkTextAttributes:attributes];
        [attributes release];
    }
}

@end
