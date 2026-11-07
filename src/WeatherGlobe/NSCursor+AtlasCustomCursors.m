#import "NSCursor+AtlasCustomCursors.h"

static NSCursor *__loadCursor(NSString *aImageName, CGFloat aHotSpotX, CGFloat aHotSpotY)
{
    NSImage *image = [NSImage imageNamed:aImageName];
    if (image == nil)
        return nil;
    return [[[NSCursor alloc] initWithImage:image hotSpot:NSMakePoint(aHotSpotX, aHotSpotY)] autorelease];
}

@implementation NSCursor (AtlasCustomCursors)

+ (id)appleStoreCursor
{
    return __loadCursor(@"appleStore_big", 13.0, 4.0);
}

+ (id)pushPinCursor
{
    return __loadCursor(@"pushpin_big", 3.0, 15.0);
}

+ (id)zoomOutCursor
{
    return __loadCursor(@"zoomout_big", 9.0, 6.0);
}

+ (id)zoomInCursor
{
    return __loadCursor(@"zoomin_big", 9.0, 6.0);
}

+ (id)handCloseCursor
{
    return __loadCursor(@"handclose_big", 13.0, 4.0);
}

+ (id)handOpenCursor
{
    return __loadCursor(@"handopen_big", 13.0, 4.0);
}

@end
