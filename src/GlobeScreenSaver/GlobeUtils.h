#import "GlobeScreenSaverPrefix.h"


@interface GlobeUtils : NSObject
{
    BOOL _lightDirIsValid;
    SMK_GL_Vec3 _lightDirection;
    BOOL _moonDirIsValid;
    SMK_GL_Vec3 _moonDirection;
    NSTimer *_autoUpdateTimer;
}
- (void)_worldTimeWasChanged:(id)aChanged;
- (SMK_GL_Vec3)moonDirection;
- (SMK_GL_Vec3)lightDirection;
- (CGFloat)moonPhase;
- (CGFloat)normalizedYearPhase;
- (CGFloat)yearPhase;
- (CGFloat)GMTDayPhase;
- (CGFloat)localDayPhase;
- (void)_calculateMoonDirection;
- (void)_calculateLightDirection;
- (void)dealloc;
- (id)init;
@end

