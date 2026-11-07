#import "CIPaletteView.h"

static NSPoint __mouseLocation;

@implementation CIPaletteView

- (void)concludeDragOperation:(id)aOperation
{
    NSPasteboard *pasteboard = [aOperation draggingPasteboard];
    if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:kCitiesListPasteboardType]] != nil) {
        id cities = [pasteboard propertyListForType:kCitiesListPasteboardType];
        if (cities != nil)
            [[NSNotificationCenter defaultCenter] postNotificationName:@"AddCitiesNotification" object:cities userInfo:nil];
    }
}

- (BOOL)performDragOperation:(id)aOperation
{
    return YES;
}

- (BOOL)prepareForDragOperation:(id)aOperation
{
    if ([[aOperation draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:@"CityInfoPboardType"]] != nil)
        [[aOperation draggingSource] showDraggedImageIfCan];
    return YES;
}

- (void)draggingExited:(id)aExited
{
    NSEvent *event = [NSApp currentEvent];
    if ([event type] == NSEventTypeKeyDown && [[event charactersIgnoringModifiers] characterAtIndex:0] != 0) {
        if ([[aExited draggingSource] respondsToSelector:@selector(abortDragging)])
            [[aExited draggingSource] abortDragging];
        return;
    }
    if ([[aExited draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kCitiesListPasteboardType]] == nil)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DraggingExitedNotification" object:[[aExited draggingSource] owner] userInfo:nil];
}

- (NSUInteger)draggingUpdated:(id)aUpdated
{
    if ([[aUpdated draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kCitiesListPasteboardType]] != nil)
        return NSDragOperationCopy;
    NSPoint location = [aUpdated draggingLocation];
    if (NSEqualPoints(location, __mouseLocation))
        return NSDragOperationEvery;
    __mouseLocation = location;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DraggingUpdatedNotification" object:aUpdated userInfo:nil];
    return NSDragOperationEvery;
}

- (NSUInteger)draggingEntered:(id)aEntered
{
    if ([[aEntered draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:kCitiesListPasteboardType]] != nil)
        return NSDragOperationCopy;
    __mouseLocation = [aEntered draggingLocation];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DraggingEnteredNotification" object:aEntered userInfo:nil];
    return NSDragOperationEvery;
}

- (void)moveUp:(id)aUp
{
    if (aUp == self)
        [_controller moveUp:aUp];
}

- (void)moveRight:(id)aRight
{
    if (aRight == self)
        [_controller moveRight:aRight];
}

- (void)moveLeft:(id)aLeft
{
    if (aLeft == self)
        [_controller moveLeft:aLeft];
}

- (void)moveDown:(id)aDown
{
    if (aDown == self)
        [_controller moveDown:aDown];
}

- (void)deleteForward:(id)aForward
{
    if (aForward == self)
        [_controller deleteForward:aForward];
}

- (void)keyDown:(id)aDown
{
    NSString *characters = [aDown charactersIgnoringModifiers];
    SEL op = NULL;
    if ([characters length] == 1) {
        switch ([characters characterAtIndex:0]) {
        case NSDeleteFunctionKey:     op = @selector(deleteForward:); break;
        case NSUpArrowFunctionKey:    op = @selector(moveUp:); break;
        case NSDownArrowFunctionKey:  op = @selector(moveDown:); break;
        case NSLeftArrowFunctionKey:  op = @selector(moveLeft:); break;
        case NSRightArrowFunctionKey: op = @selector(moveRight:); break;
        }
    }
    if (op != NULL)
        [self performSelector:op withObject:self];
    else
        [super keyDown:aDown];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)isFlipped
{
    return YES;
}

- (id)initWithController:(id)aController
{
    self = [self initWithFrame:NSMakeRect(0, 0, 1, 1)];
    if (self != nil)
        _controller = aController;
    return self;
}

- (id)initWithFrame:(NSRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self != nil)
        [self registerForDraggedTypes:[NSArray arrayWithObjects:@"CityInfoPboardType", kCitiesListPasteboardType, nil]];
    return self;
}

@end
