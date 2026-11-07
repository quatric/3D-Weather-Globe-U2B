#import "WeatherGlobePrefix.h"


@interface CityPropertyAccessibilityObject : NSObject
{
    NSRect _frameRect;
    NSView *_parentView;
    NSString *_description;
}
- (BOOL)accessibilityIsIgnored;
- (BOOL)accessibilityIsAttributeSettable:(id)aSettable;
- (id)accessibilityAttributeValue:(id)aValue;
- (id)accessibilityAttributeNames;
- (void)dealloc;
- (id)initWithParentView:(id)aView frameRect:(NSRect)aRect description:(id)aDescription;
@end

@interface CityPropertyGenericView : NSView
{
    YACityEntry *_entry;
}
+ (id)optionsMenuItems;
+ (id)_menuItemsDescriptors;
+ (void)_clocksMeasureWereChanged:(id)aChanged;
+ (void)initialize;
- (BOOL)accessibilityIsAttributeSettable:(id)aSettable;
- (BOOL)accessibilityIsIgnored;
- (id)accessibilityAttributeValue:(id)aValue;
- (id)accessibilityAttributeNames;
- (id)accessibilityObjects;
- (BOOL)enabled;
- (NSSize)sizeForBestFit;
- (void)dealloc;
- (id)initWithCityEntry:(id)aEntry;
@end

