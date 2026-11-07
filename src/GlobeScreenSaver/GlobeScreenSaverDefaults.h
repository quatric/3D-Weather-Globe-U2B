#import "GlobeScreenSaverPrefix.h"


@interface GlobeScreenSaverDefaults : NSObject
{
}
+ (id)configDictionary;
+ (void)setZoom:(CGFloat)aZoom;
+ (CGFloat)zoom;
+ (void)setSpinningSpeed:(CGFloat)aSpeed;
+ (CGFloat)spinningSpeed;
+ (void)setCloudsEnabled:(BOOL)aEnabled;
+ (BOOL)cloudsEnabled;
+ (void)setMoonEnabled:(BOOL)aEnabled;
+ (BOOL)moonEnabled;
+ (void)setSunEnabled:(BOOL)aEnabled;
+ (BOOL)sunEnabled;
+ (void)setDayNightEnabled:(BOOL)aEnabled;
+ (BOOL)dayNightEnabled;
+ (void)setStarsEnabled:(BOOL)aEnabled;
+ (BOOL)starsEnabled;
+ (void)setSpinDirectionMode:(NSInteger)aMode;
+ (NSInteger)spinDirectionMode;
+ (NSInteger)globeSpinningDirection;
+ (void)setPointOfViewMode:(NSInteger)aMode;
+ (NSInteger)pointOfViewMode;
+ (id)standardSaverDefaults;
@end

@interface NSDictionary (ConfigDictionary)
- (CGFloat)animationFPS;
@end

