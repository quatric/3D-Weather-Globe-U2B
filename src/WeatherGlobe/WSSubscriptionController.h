#import "WeatherGlobePrefix.h"


@interface WSSubscriptionController : NSObject
{
    NSWindow *_window;
    NSWindow *_privacyStatementWindow;
    NSTextField *_firstNameField;
    NSTextField *_lastNameField;
    NSTextField *_emailField;
    NSPopUpButton *_countryPopUp;
    NSMutableDictionary *_regInfo;
    BOOL _regInfoIsValid;
    NSWindow *_sheet;
    SEL _sheetDidEndSelector;
}
+ (id)registrationInfo;
+ (BOOL)runModal;
+ (id)_sharedController;
- (void)incompleteRequiredInformationSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo;
- (void)incompleteEmailSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo;
- (void)privacyStatementSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo;
- (void)showHelp:(id)aHelp;
- (void)privacyStatementWindowOK:(id)aOK;
- (void)privacyStatement:(id)aStatement;
- (void)doNotSubscribe:(id)aSubscribe;
- (void)subscribeNow:(id)aNow;
- (id)_registrationInfo;
- (BOOL)_runModal;
- (void)dealloc;
- (void)awakeFromNib;
- (void)_loadNibIfNeeded;
- (void)_releaseSheet;
- (void)_setUserInformation;
- (void)_collectUserInformation;
- (id)_addressBookInfo;
@end

@interface WSSubsribtionTextFormatter : NSFormatter
{
    unsigned int _lastLength;
    unsigned int _maxLength;
}
+ (id)formatterWithMaxLength:(NSUInteger)aLength;
- (BOOL)isPartialStringValid:(id)aValid newEditingString:(id *)aString errorDescription:(id *)aDescription;
- (BOOL)getObjectValue:(id *)aValue forString:(id)aString errorDescription:(id *)aDescription;
- (id)stringForObjectValue:(id)aValue;
- (id)initWithMaxLength:(NSUInteger)aLength;
- (id)init;
@end

