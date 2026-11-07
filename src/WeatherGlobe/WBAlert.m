#import "WBAlert.h"

@implementation WBAlert

- (void)setDontShowAgain:(BOOL)aAgain
{
    [_dontShowButt setState:aAgain ? NSControlStateValueOn : NSControlStateValueOff];
}

- (BOOL)dontShowAgain
{
    return [_dontShowButt intValue] != 0;
}

- (NSInteger)runModal
{
    [_window makeKeyAndOrderFront:self];
    NSInteger result = [NSApp runModalForWindow:_window];
    [_window orderOut:self];
    return result;
}

- (void)buttAction:(id)aAction
{
    NSInteger tag = [aAction tag];
    if (tag == 0)
        return;
    if (tag == 4) {
        if ([_delegate respondsToSelector:@selector(wbAlertShowHelp:)])
            [_delegate wbAlertShowHelp:self];
        return;
    }
    // the default button answers 1, the cancel button 0, any other -1
    NSInteger code;
    if (tag == _defButt)
        code = 1;
    else
        code = (tag == _cancelButt) - 1;
    [NSApp stopModalWithCode:code];
}

- (NSInteger)tag
{
    return _alertTag;
}

- (void)setTag:(NSInteger)aTag
{
    _alertTag = (int)aTag;
}

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)aDelegate
{
    _delegate = aDelegate;
}

- (void)dealloc
{
    [_window release];
    [_customBgrView release];
    [super dealloc];
}

// sizes a button to its title (at least 80 wide); returns how much it grew
static int _fitButton(NSButton *aButton, NSString *aTitle, int aShift, BOOL aMove)
{
    NSRect frame = [aButton frame];
    [aButton setTitle:aTitle];
    NSSize size = [[aButton cell] cellSizeForBounds:NSMakeRect(frame.origin.x, frame.origin.y, 300, frame.size.height)];
    float width = MAX(80.0f, (float)size.width);
    int shift = (int)((float)aShift + (width - (float)(int)frame.size.width));
    if (aMove)
        frame.origin.x -= shift;
    frame.size.width = width;
    [aButton setFrame:frame];
    return shift;
}

// sizes a text field to its text; returns how much taller it got
static int _fitTextField(NSTextField *aField, NSString *aText, int aShift)
{
    NSRect frame = [aField frame];
    [aField setStringValue:aText];
    NSSize size = [[aField cell] cellSizeForBounds:NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 300)];
    int shift = (int)((float)aShift + ((float)size.height - (float)(int)frame.size.height));
    frame.origin.y -= shift;
    frame.size.height = size.height;
    [aField setFrame:frame];
    return shift;
}

static NSButton *_buttonWithIndex(WBAlert *self, NSInteger aIndex)
{
    switch (aIndex) {
    case 1: return self->_leftButt;
    case 2: return self->_midButt;
    case 3: return self->_rightButt;
    }
    return nil;
}

- (id)initWithTitle:(id)aTitle body:(id)aBody rightButt:(id)aButt middleButt:(id)aButt2 leftButt:(id)aButt3 checkboxTitle:(id)aTitle2 hasHelpButt:(BOOL)aButt4 defButtIndex:(NSInteger)aIndex cancelButtIndex:(NSInteger)aIndex2 hasCustomBgr:(BOOL)aBgr withNibName:(id)aName alertCaption:(id)aCaption
{
    self = [super init];
    if (self == nil)
        return nil;
    _defButt = (int)aIndex;
    _cancelButt = (int)aIndex2;
    [NSBundle loadNibNamed:aName != nil ? aName : @"WBAlert" owner:self];

    // missing titles are filled from the left
    NSString *rightTitle = aButt, *middleTitle = aButt2, *leftTitle = aButt3;
    if (rightTitle == nil) {
        rightTitle = leftTitle;
        if (middleTitle != nil) {
            rightTitle = middleTitle;
            middleTitle = leftTitle;
        }
        leftTitle = nil;
    } else if (middleTitle == nil) {
        middleTitle = leftTitle;
        leftTitle = nil;
    }

    NSRect contentFrame = [[_window contentView] frame];
    NSSize contentSize = contentFrame.size;
    int grow = 0;
    if (rightTitle != nil)
        grow = _fitButton(_leftButt, rightTitle, 0, YES);
    if (middleTitle == nil) {
        [_midButt removeFromSuperview];
        _midButt = nil;
    } else {
        grow = _fitButton(_midButt, middleTitle, grow, YES);
    }
    if (leftTitle == nil) {
        [_rightButt removeFromSuperview];
        _rightButt = nil;
    } else {
        grow = _fitButton(_rightButt, leftTitle, grow, NO);
    }
    if (!aButt4) {
        [_helpButt removeFromSuperview];
        _helpButt = nil;
    }
    if (grow > 0) {
        contentSize.width = (float)grow + contentFrame.size.width;
        [_window setContentSize:NSMakeSize(contentSize.width, contentFrame.size.height)];
    }

    int titleGrow = _fitTextField(_title, aTitle, 0);
    grow = _fitTextField(_body, aBody, titleGrow);
    if (aTitle2 == nil) {
        grow = (int)((float)grow - [_dontShowButt frame].size.height);
        [_dontShowButt removeFromSuperview];
        _dontShowButt = nil;
    } else {
        [_dontShowButt setTitle:aTitle2];
    }
    if (grow > 0) {
        contentSize.height = (float)grow + contentFrame.size.height;
        [_window setContentSize:contentSize];
    }
    if (aCaption != nil)
        [_window setTitle:aCaption];
    if (aIndex > 0)
        [_buttonWithIndex(self, aIndex) setKeyEquivalent:@"\r"];
    if (aIndex2 > 0 && aIndex != aIndex2)
        [_buttonWithIndex(self, aIndex2) setKeyEquivalent:@"\e"];
    [_window setContentSize:contentSize];
    [_window center];

    if (aBgr) {
        // move the contents into a borderless window drawn by the custom background view
        NSRect frame = [[_window contentView] frame];
        NSArray *subviews = [NSArray arrayWithArray:[[_window contentView] subviews]];
        [_window release];
        frame.size.width += 14.0;
        _window = [[WBAlertWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        [_window setMovableByWindowBackground:YES];
        [_window setOpaque:NO];
        [_window setAlphaValue:0.999f];
        [_window setBackgroundColor:[NSColor clearColor]];
        [_window setHasShadow:YES];
        [_window center];
        NSInteger count = [subviews count];
        NSRect newContent = [[_window contentView] frame];
        [_customBgrView setFrame:NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, newContent.size.width, newContent.size.height)];
        [[_window contentView] addSubview:_customBgrView];
        for (NSInteger i = 0; i < count; i++) {
            NSView *view = [subviews objectAtIndex:i];
            NSPoint origin = [view frame].origin;
            if (![view isKindOfClass:[NSImageView class]])
                origin.x += 10.0;
            [view setFrameOrigin:origin];
            [_customBgrView addSubview:view];
        }
    }
    return self;
}

- (id)initWithTitle:(id)aTitle body:(id)aBody rightButt:(id)aButt middleButt:(id)aButt2 leftButt:(id)aButt3 checkboxTitle:(id)aTitle2 hasHelpButt:(BOOL)aButt4 defButtIndex:(NSInteger)aIndex cancelButtIndex:(NSInteger)aIndex2 hasCustomBgr:(BOOL)aBgr
{
    return [self initWithTitle:aTitle body:aBody rightButt:aButt middleButt:aButt2 leftButt:aButt3 checkboxTitle:aTitle2 hasHelpButt:aButt4 defButtIndex:aIndex cancelButtIndex:aIndex2 hasCustomBgr:aBgr withNibName:nil alertCaption:nil];
}

@end

@implementation WBAlertClearView

- (void)drawRect:(NSRect)aRect
{
    [[NSColor whiteColor] set];
    NSRectFill(aRect);
}

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

@end

@implementation WBAlertImageView

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

@end

@implementation WBAlertWindow

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

@end
