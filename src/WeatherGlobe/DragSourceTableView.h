#import "WeatherGlobePrefix.h"


@interface DragSourceTableView : NSTableView
{
}
- (BOOL)writeSelectionToPasteboard:(id)aPasteboard types:(id)aTypes;
- (id)validRequestorForSendType:(id)aType returnType:(id)aType2;
- (BOOL)becomeFirstResponder;
- (void)deleteForward:(id)aForward;
- (void)keyDown:(id)aDown;
- (void)draggedImage:(id)aImage endedAt:(NSPoint)aAt operation:(NSUInteger)aOperation;
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal;
@end

@interface NSObject (CitiesDraggingCategory)
- (void)provideCityEntriesDataForType:(id)aType toPasteboard:(id)aPasteboard;
- (void)declareCitiesEntries:(id)aEntries inPasteboard:(id)aPasteboard withAdditionTypes:(id)aTypes;
@end

