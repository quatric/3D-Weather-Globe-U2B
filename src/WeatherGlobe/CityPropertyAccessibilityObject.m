#import "CityPropertyAccessibilityObject.h"

@implementation CityPropertyAccessibilityObject

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityRoleAttribute])
        return NSAccessibilityUnknownRole;
    if ([aValue isEqualToString:NSAccessibilityParentAttribute])
        return _parentView;
    if ([aValue isEqualToString:NSAccessibilityTitleAttribute] || [aValue isEqualToString:NSAccessibilityHelpAttribute])
        return _description;
    if ([aValue isEqualToString:NSAccessibilityPositionAttribute]) {
        NSPoint point = [_parentView convertPoint:_frameRect.origin toView:nil];
        return [NSValue valueWithPoint:[[_parentView window] convertPointToScreen:point]];
    }
    if ([aValue isEqualToString:NSAccessibilitySizeAttribute])
        return [NSValue valueWithSize:_frameRect.size];
    return nil;
}

- (id)accessibilityAttributeNames
{
    return [NSArray arrayWithObjects:NSAccessibilityRoleAttribute, NSAccessibilityHelpAttribute, NSAccessibilityTitleAttribute, NSAccessibilityPositionAttribute, NSAccessibilitySizeAttribute, NSAccessibilityParentAttribute, nil];
}

- (void)dealloc
{
    [_description release];
    [super dealloc];
}

- (id)initWithParentView:(id)aView frameRect:(NSRect)aRect description:(id)aDescription
{
    self = [super init];
    if (self != nil) {
        _frameRect = aRect;
        _parentView = aView;
        _description = [aDescription retain];
    }
    return self;
}

@end

@implementation CityPropertyGenericView

+ (id)optionsMenuItems
{
    NSArray *descriptors = [self _menuItemsDescriptors];
    NSInteger count = [descriptors count];
    NSMutableArray *items = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        NSDictionary *descriptor = [descriptors objectAtIndex:i];
        NSString *title = [descriptor objectForKey:@"TITLE"];
        NSMenu *submenu = [descriptor objectForKey:@"SUBMENU"];
        SEL action = NSSelectorFromString([descriptor objectForKey:@"SELECTOR"]);
        NSInteger tag = [[descriptor objectForKey:@"TAG"] intValue];
        NSMenuItem *item;
        if ([title isEqual:@"-"]) {
            item = [NSMenuItem separatorItem];
        } else {
            item = [[NSMenuItem new] autorelease];
            [item setTitle:title];
            [item setTarget:self];
            [item setTag:tag];
            [item setAction:action];
            if (submenu != nil)
                [item setSubmenu:submenu];
        }
        [items addObject:item];
    }
    return items;
}

+ (id)_menuItemsDescriptors
{
    return nil;
}

+ (void)_clocksMeasureWereChanged:(id)aChanged
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AdjustTimeFormatNotification" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NeedReconstructNotification" object:nil];
}

+ (void)initialize
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_clocksMeasureWereChanged:) name:kClockFormatWasChanged object:nil];
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    if ([aSettable isEqualToString:NSAccessibilityChildrenAttribute] || [aSettable isEqualToString:NSAccessibilityRoleAttribute])
        return NO;
    return [super accessibilityIsAttributeSettable:aSettable];
}

- (BOOL)accessibilityIsIgnored
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityChildrenAttribute])
        return [self accessibilityObjects];
    if ([aValue isEqualToString:NSAccessibilityRoleAttribute])
        return NSAccessibilityGroupRole;
    return [super accessibilityAttributeValue:aValue];
}

- (id)accessibilityAttributeNames
{
    return [[super accessibilityAttributeNames] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:NSAccessibilityChildrenAttribute, nil]];
}

- (id)accessibilityObjects
{
    return nil;
}

- (BOOL)enabled
{
    return NO;
}

- (NSSize)sizeForBestFit
{
    return NSMakeSize(1, 1);
}

- (void)dealloc
{
    [_entry release];
    [super dealloc];
}

- (id)initWithCityEntry:(id)aEntry
{
    self = [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    if (self != nil)
        _entry = [aEntry retain];
    return self;
}

@end
