#import "WeatherGlobePrefix.h"


@interface AppleStoreEditController : NSWindowController
{
    NSFormCell *_name;
    NSFormCell *_longitude;
    NSFormCell *_latitude;
    NSFormCell *_url;
    NSFormCell *_cityName;
    NSFormCell *_infoPaletteTitle;
    NSTextView *_address;
    NSTextView *_additionalInfo;
    NSColorWell *_markerColor;
    NSPopUpButton *_markerSize;
    NSTextField *_markerString;
    NSButton *_previousButton;
    NSButton *_nextButton;
    MainWindowController *_mainController;
    AppleStoreEntry *_entry;
}
+ (BOOL)isAppleStoreEditPanelVisible;
+ (void)hideAppleStoreEditPanel;
+ (void)showAppleStoreEditPanelWithEntry:(id)aEntry mainController:(id)aController;
- (void)deleteButtonAction:(id)aAction;
- (void)newButtonAction:(id)aAction;
- (void)nexButtonAction:(id)aAction;
- (void)previousButtonAction:(id)aAction;
- (void)replaceEntryWithAppleStoreIfNeeded;
@end

@interface AppleStoreEditController (WindowDelegate)
- (BOOL)windowShouldClose:(id)aClose;
@end

@interface AppleStoreEditController (Private)
- (BOOL)saveValues;
- (void)showPanel;
@end

