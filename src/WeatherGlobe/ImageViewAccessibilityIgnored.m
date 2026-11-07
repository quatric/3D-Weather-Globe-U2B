#import "ImageViewAccessibilityIgnored.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation ImageViewAccessibilityIgnored

- (id)accessibilityFocusedUIElement
{
    return NSAccessibilityUnignoredAncestor([self superview]);
}

- (BOOL)accessibilityIsIgnored
{
    return YES;
}

- (id)accessibilityHitTest:(NSPoint)aTest
{
    return NSAccessibilityUnignoredAncestor([self superview]);
}

- (BOOL)accessibilityIsAttributeSettable:(id)aSettable
{
    return NO;
}

- (id)accessibilityAttributeValue:(id)aValue
{
    if ([aValue isEqualToString:NSAccessibilityChildrenAttribute])
        return nil;
    if ([aValue isEqualToString:NSAccessibilityParentAttribute])
        return NSAccessibilityUnignoredAncestor([self superview]);
    return [super accessibilityAttributeValue:aValue];
}

- (id)accessibilityAttributeNames
{
    return [super accessibilityAttributeNames];
}

@end

#pragma clang diagnostic pop
