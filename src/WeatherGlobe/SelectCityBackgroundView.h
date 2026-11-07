#import "WeatherGlobePrefix.h"
#import "CitiesListController.h"


@interface SelectCityBackgroundView : NSView
{
    NSImage *_image;
}
- (void)drawRect:(NSRect)aRect;
- (void)setImage:(id)aImage;
@end

@interface SelectCityWindow : NSWindow
{
}
- (BOOL)canBecomeKeyWindow;
- (id)initWithContentRect:(NSRect)aRect styleMask:(NSUInteger)aMask backing:(NSInteger)aBacking defer:(BOOL)aDefer;
@end

@interface SelectCityDialogController : CitiesListController
{
    NSWindow *_window;
    SelectCityBackgroundView *_backgroundView;
    int _dialogMode;
    id _modalDelegate;
}
+ (void)beginSheetModalForWindow:(id)aWindow modalDelegate:(id)aDelegate;
+ (void)runModalDialog;
+ (id)_homeCity;
+ (id)_sharedController;
- (void)selectAction:(id)aAction;
- (void)sheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo;
- (void)_beginSheetWithDefaultCity:(id)aCity modalForWindow:(id)aWindow modalDelegate:(id)aDelegate;
- (void)_runModalDialogWithDefaultCity:(id)aCity;
- (void)_prepareWindowForCity:(id)aCity;
- (void)_doubleClickAction:(id)aAction;
- (id)nibName;
- (void)dealloc;
- (void)awakeFromNib;
@end

