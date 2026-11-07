#import "WeatherGlobePrefix.h"


@interface CitiesListDraggAcceptButton : NSButton
{
}
- (void)concludeDragOperation:(id)aOperation;
- (BOOL)performDragOperation:(id)aOperation;
- (BOOL)prepareForDragOperation:(id)aOperation;
- (NSUInteger)draggingUpdated:(id)aUpdated;
- (NSUInteger)draggingEntered:(id)aEntered;
- (void)awakeFromNib;
@end

