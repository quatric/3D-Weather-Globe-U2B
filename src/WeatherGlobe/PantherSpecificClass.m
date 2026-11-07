#import "PantherSpecificClass.h"

static BOOL __needLoad = YES;
static SInt32 __currentVersion;
static Class __principalClass;

@implementation PantherSpecificClass

+ (Class)principalClass
{
    if (__needLoad) {
        __needLoad = NO;
        if (__currentVersion >= kPantherVersion) {
            NSString *path = [[NSBundle mainBundle] pathForResource:@"PantherSpecific" ofType:@"bundle"];
            __principalClass = [[NSBundle bundleWithPath:path] principalClass];
        }
    }
    return __principalClass;
}

+ (NSInteger)currentOSVersion
{
    return __currentVersion;
}

+ (void)initialize
{
    Gestalt(gestaltSystemVersion, &__currentVersion);
}

@end
