#import "WeatherGlobePrefix.h"


@interface DrawerController : NSObject
{
    NSDrawer *_drawer;
    NSView *_contentView;
    MainWindowController *_mainWndController;
    BOOL _ignoreDefaultsChangings;
    NSSlider *_globeTransparency;
    NSSlider *_spinSpeed;
    NSSlider *_cloudsAnimSpeed;
    NSButton *_useCustomTime;
    NSStepper *_dateStepper;
    NSSlider *_customTime;
    NSTextField *_timeField;
    NSTextField *_dayField;
    NSTextField *_monthField;
    NSTextField *_yearField;
    id _currentField;
    NSSlider *_markerSize;
    NSButton *_appleStoresCheckBox;
    NSRect _prevFrame;
    BOOL _restoreFrame;
    BOOL _needChangeFrame;
    TimeController *_timeController;
    int _prevMonth;
    int _prevDay;
    int _prevYear;
    NSButton *_locationNames;
}
- (void)setNeedsChangeParentWindowFrame:(BOOL)aFrame;
- (void)forceRestoreParentWindowFrame;
- (void)windowDidMove:(id)aMove;
- (void)windowDidResize:(id)aResize;
- (void)drawerDidClose:(id)aClose;
- (void)drawerDidOpen:(id)aOpen;
- (void)selectInitialResponder;
- (BOOL)drawerIsOpenState;
- (void)mainViewControllerClassWasChangedTo:(Class)aTo;
- (void)toggleOptions;
- (void)hideOptions;
- (void)showOptions;
- (void)controlsAction:(id)aAction;
- (void)controlTextDidEndEditing:(id)aEditing;
- (void)_textFieldDidStartEditing:(id)aEditing;
- (id)_dateFromFields;
- (void)_disableCustomTime;
- (void)_enableCustomTime;
- (void)_worldTimeWasChanged:(id)aChanged;
- (void)_defaultsWereChanged:(id)aChanged;
- (void)_clocksMeasureWereChanged:(id)aChanged;
- (void)_setupControls;
- (void)dealloc;
- (void)awakeFromNib;
- (void)_setupCellForField:(id)aField;
- (void)_setupCustomTimeControls;
@end

