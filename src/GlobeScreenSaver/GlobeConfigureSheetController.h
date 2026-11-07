#import "GlobeScreenSaverPrefix.h"


@interface GlobeConfigureSheetController : NSWindowController
{
    NSButtonCell *_viewFromSatelite;
    NSButtonCell *_viewOnGlobe;
    NSMatrix *_pointOfViewMatrix;
    NSMatrix *_globeSpinDirMatrix;
    NSSlider *_zoom;
    NSButtonCell *_showDayNight;
    NSButtonCell *_showStars;
    NSButtonCell *_showMoon;
    NSButtonCell *_showSun;
    NSButtonCell *_showClouds;
    NSSlider *_spinningSpeed;
}
- (void)_pointOfViewChanged:(id)aChanged;
- (void)onDone:(id)aDone;
- (void)onCancel:(id)aCancel;
- (void)_postEndConfigSheetNotification;
- (void)dealloc;
- (void)windowDidLoad;
- (id)init;
@end

@interface GlobeConfigureSheetController (Private)
- (BOOL)_synchronize;
- (void)_updateDefaultsFromUI;
- (void)_updateUIFromeDefaults;
- (void)_refreshControlsEnabledState;
@end

