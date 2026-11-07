#import "CitiesListDraggAcceptButton.h"

@implementation CitiesListDraggAcceptButton

- (void)concludeDragOperation:(id)aOperation
{
    id cities = [[aOperation draggingPasteboard] propertyListForType:kCitiesListPasteboardType];
    if (cities != nil)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddCitiesNotification" object:cities userInfo:nil];
}

- (BOOL)performDragOperation:(id)aOperation
{
    return YES;
}

- (BOOL)prepareForDragOperation:(id)aOperation
{
    return YES;
}

- (NSUInteger)draggingUpdated:(id)aUpdated
{
    return NSDragOperationCopy;
}

- (NSUInteger)draggingEntered:(id)aEntered
{
    return NSDragOperationCopy;
}

- (void)awakeFromNib
{
    [self registerForDraggedTypes:[NSArray arrayWithObjects:kCitiesListPasteboardType, nil]];
}

@end
