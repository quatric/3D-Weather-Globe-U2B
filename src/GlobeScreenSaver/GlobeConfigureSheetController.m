#import "GlobeConfigureSheetController.h"

// The Options sheet. It edits GlobeScreenSaverDefaults directly; Cancel
// reloads the controls from the defaults.
@implementation GlobeConfigureSheetController

/* i386 ivar offsets: _viewFromSatelite=0x28, _viewOnGlobe=0x2c, _pointOfViewMatrix=0x30, _globeSpinDirMatrix=0x34, _zoom=0x38, _showDayNight=0x3c, _showStars=0x40, _showMoon=0x44, _showSun=0x48, _showClouds=0x4c, _spinningSpeed=0x50 */

- (void)_pointOfViewChanged:(id)aChanged
{
	[self _refreshControlsEnabledState];
}

// The 2011 saver ended the sheet with -[NSApp endSheet:]. Current hosts
// (System Settings, legacyScreenSaver) present it with the window sheet API,
// so it's ended on its sheet parent when it has one.
static void _endSheet(NSWindow *aSheet)
{
	NSWindow *parent = [aSheet sheetParent];
	if (parent != nil) {
		[parent endSheet:aSheet];
	} else {
		[NSApp endSheet:aSheet];
	}
}

- (void)onDone:(id)aDone
{
	_endSheet([self window]);
	[self _updateDefaultsFromUI];
	[self _postEndConfigSheetNotification];
}

- (void)onCancel:(id)aCancel
{
	_endSheet([self window]);
	[self _updateUIFromeDefaults];
	[self _postEndConfigSheetNotification];
}

- (void)_postEndConfigSheetNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kEndConfigSheetNotification object:self];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)windowDidLoad
{
	[_spinningSpeed setMinValue:(double)0.01f];
	[_spinningSpeed setMaxValue:(double)0.4f];
	[self _updateUIFromeDefaults];
}

- (id)init
{
	return [super initWithWindowNibName:@"ConfigureSheet"];
}

@end

@implementation GlobeConfigureSheetController (Private)

- (BOOL)_synchronize
{
	BOOL done = [[GlobeScreenSaverDefaults standardSaverDefaults] synchronize];
	if (done) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kUserDefaultsDidChangeNotification object:nil];
	}
	return done;
}

- (void)_updateDefaultsFromUI
{
	[GlobeScreenSaverDefaults setPointOfViewMode:[_pointOfViewMatrix selectedRow]];
	[GlobeScreenSaverDefaults setSpinDirectionMode:[_globeSpinDirMatrix selectedRow]];
	[GlobeScreenSaverDefaults setZoom:[_zoom floatValue]];
	[GlobeScreenSaverDefaults setStarsEnabled:[_showStars state] == NSControlStateValueOn];
	[GlobeScreenSaverDefaults setDayNightEnabled:[_showDayNight state] == NSControlStateValueOn];
	[GlobeScreenSaverDefaults setSunEnabled:[_showSun state] == NSControlStateValueOn];
	[GlobeScreenSaverDefaults setCloudsEnabled:[_showClouds state] == NSControlStateValueOn];
	[GlobeScreenSaverDefaults setMoonEnabled:[_showMoon state] == NSControlStateValueOn];
	[GlobeScreenSaverDefaults setSpinningSpeed:[_spinningSpeed floatValue]];
	[self _synchronize];
}

- (void)_updateUIFromeDefaults
{
	[_zoom setFloatValue:(float)[GlobeScreenSaverDefaults zoom]];
	[_pointOfViewMatrix selectCellAtRow:[GlobeScreenSaverDefaults pointOfViewMode] column:0];
	[_globeSpinDirMatrix selectCellAtRow:[GlobeScreenSaverDefaults spinDirectionMode] column:0];
	[_showStars setState:[GlobeScreenSaverDefaults starsEnabled]];
	[_showDayNight setState:[GlobeScreenSaverDefaults dayNightEnabled]];
	[_showSun setState:[GlobeScreenSaverDefaults sunEnabled]];
	[_showClouds setState:[GlobeScreenSaverDefaults cloudsEnabled]];
	[_showMoon setState:[GlobeScreenSaverDefaults moonEnabled]];
	[_spinningSpeed setFloatValue:(float)[GlobeScreenSaverDefaults spinningSpeed]];
	[self _refreshControlsEnabledState];
}

// zoom and spin direction only apply to the whole-globe view (row 1)
- (void)_refreshControlsEnabledState
{
	BOOL globe = (char)[_pointOfViewMatrix selectedRow] != 0;
	[_zoom setEnabled:globe];
	[_globeSpinDirMatrix setEnabled:globe];
}

@end
