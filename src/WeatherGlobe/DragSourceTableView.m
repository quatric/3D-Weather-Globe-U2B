#import "DragSourceTableView.h"

static NSArray *__selectedRowNumbers(NSTableView *aTable)
{
    NSIndexSet *rows = [aTable selectedRowIndexes];
    NSMutableArray *numbers = [NSMutableArray arrayWithCapacity:[rows count]];
    NSUInteger row;
    for (row = [rows firstIndex]; row != NSNotFound; row = [rows indexGreaterThanIndex:row])
        [numbers addObject:[NSNumber numberWithInt:(int)row]];
    return numbers;
}

@implementation DragSourceTableView

- (BOOL)writeSelectionToPasteboard:(id)aPasteboard types:(id)aTypes
{
    [aPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [aPasteboard setString:[[[self dataSource] selectedItem] ownName] forType:NSStringPboardType];
    return YES;
}

// Offers the Services menu the selected city's name when exactly one row is selected.
- (id)validRequestorForSendType:(id)aType returnType:(id)aType2
{
    if ([aType isEqual:NSStringPboardType] && aType2 == nil
        && [[self dataSource] isKindOfClass:[CitiesListController class]] && [self numberOfSelectedRows] == 1)
        return self;
    return [super validRequestorForSendType:aType returnType:aType2];
}

- (BOOL)becomeFirstResponder
{
    BOOL became = [super becomeFirstResponder];
    if (became)
        [[NSNotificationCenter defaultCenter] postNotification:
            [NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification object:self]];
    return became;
}

- (void)deleteForward:(id)aForward
{
    id dataSource = [self dataSource];
    if ([dataSource respondsToSelector:@selector(tableView:requestedToDeleteRows:)])
        [dataSource performSelector:@selector(tableView:requestedToDeleteRows:) withObject:self
                         withObject:__selectedRowNumbers(self)];
}

- (void)keyDown:(id)aDown
{
    NSString *characters = [aDown charactersIgnoringModifiers];
    id dataSource = [self dataSource];
    unichar character = [characters length] == 1 ? [characters characterAtIndex:0] : 0;
    unsigned short keyCode = [aDown keyCode];

    if (character == 0x7f || character == NSDeleteFunctionKey)
        [self deleteForward:nil];
    else if ([characters isEqualToString:@" "] && [dataSource respondsToSelector:@selector(tableView:requestedToMarkRows:)])
        [dataSource performSelector:@selector(tableView:requestedToMarkRows:) withObject:self
                         withObject:__selectedRowNumbers(self)];
    else if ((keyCode == 0x24 || keyCode == 0x4c) && [dataSource respondsToSelector:@selector(tableView:requestedToEditRows:)])
        [dataSource performSelector:@selector(tableView:requestedToEditRows:) withObject:self
                         withObject:__selectedRowNumbers(self)];
    else if (character == NSHomeFunctionKey)
        [self scrollRowToVisible:0];
    else if (character == NSEndFunctionKey)
        [self scrollRowToVisible:[self numberOfRows] - 1];
    else
        [super keyDown:aDown];
}

- (void)draggedImage:(id)aImage endedAt:(NSPoint)aAt operation:(NSUInteger)aOperation
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kCitiesListDraggingEndedNotification object:self];
}

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal
{
    return NSDragOperationCopy;
}

@end

@implementation NSObject (CitiesDraggingCategory)

- (void)provideCityEntriesDataForType:(id)aType toPasteboard:(id)aPasteboard
{
    if (![self conformsToProtocol:@protocol(CitiesDraggingHelperProtocol)])
        return;
    NSArray *entries = [(id)self draggedEntries];
    NSUInteger count = [entries count], i;
    if ([aType isEqual:kCitiesListPasteboardType]) {
        NSMutableArray *list = [NSMutableArray array];
        for (i = 0; i < count; i++)
            [list addObject:[[entries objectAtIndex:i] entryDictionary]];
        [aPasteboard setPropertyList:list forType:kCitiesListPasteboardType];
    } else if ([aType isEqual:NSStringPboardType]) {
        NSMutableString *names = nil;
        for (i = 0; i < count; i++) {
            NSString *caption = [[entries objectAtIndex:i] shortCaption];
            if (names == nil) {
                names = [NSMutableString stringWithString:caption];
            } else {
                [names appendString:@"\n"];
                [names appendString:caption];
            }
        }
        [aPasteboard setString:names forType:NSStringPboardType];
    }
}

- (void)declareCitiesEntries:(id)aEntries inPasteboard:(id)aPasteboard withAdditionTypes:(id)aTypes
{
    [aPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    [aPasteboard addTypes:aTypes owner:self];
    if ([self conformsToProtocol:@protocol(CitiesDraggingHelperProtocol)])
        [(id)self setDraggedEntries:aEntries];
}

@end
