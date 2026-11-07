#import "WSSubscriptionController.h"

static WSSubscriptionController *_sWSSubscriptionController = nil;

static BOOL _isValidEmail(NSString *aEmail)
{
    if (![aEmail canBeConvertedToEncoding:NSASCIIStringEncoding])
        return NO;
    NSRange at = [aEmail rangeOfString:@"@"];
    if (at.location == 0 || at.length != 1)
        return NO;
    NSRange lastAt = [aEmail rangeOfString:@"@" options:NSBackwardsSearch];
    if (lastAt.location != at.location || lastAt.location == [aEmail length] - 1)
        return NO;
    NSString *local = [aEmail substringToIndex:lastAt.location];
    NSString *domain = [aEmail substringFromIndex:lastAt.location + 1];
    NSMutableCharacterSet *localSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [localSet addCharactersInString:@"!#$%'*+-./=?^_`~&"];
    NSMutableCharacterSet *domainSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [domainSet addCharactersInString:@".-"];
    if (local == nil || domain == nil)
        return NO;
    if ([local rangeOfCharacterFromSet:[localSet invertedSet]].location != NSNotFound)
        return NO;
    if ([domain rangeOfCharacterFromSet:[domainSet invertedSet]].location != NSNotFound)
        return NO;
    if ([domain hasSuffix:@"."] || [domain hasPrefix:@"."])
        return NO;
    if ([domain rangeOfString:@".."].location != NSNotFound)
        return NO;
    return [domain rangeOfString:@"."].location != NSNotFound;
}

static void _setFieldFromInfo(NSTextField *aField, NSDictionary *aInfo, NSString *aKey)
{
    id value = [aInfo objectForKey:aKey];
    if (value != nil)
        [aField setObjectValue:value];
    else if ([[aField stringValue] length] != 0)
        [aField setObjectValue:@""];
}

@implementation WSSubscriptionController

+ (id)registrationInfo
{
    return [[self _sharedController] _registrationInfo];
}

+ (BOOL)runModal
{
    return [[self _sharedController] _runModal];
}

+ (id)_sharedController
{
    if (_sWSSubscriptionController == nil)
        _sWSSubscriptionController = [WSSubscriptionController new];
    return _sWSSubscriptionController;
}

- (void)incompleteRequiredInformationSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
    [aEnd orderOut:self];
    if (aCode == 1) {
        [self _releaseSheet];
        id field = (id)aInfo;
        if (field != nil && [field isKindOfClass:[NSResponder class]])
            [_window makeFirstResponder:field];
    }
}

- (void)incompleteEmailSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
    [aEnd orderOut:self];
    if (aCode == 1)
        [self _releaseSheet];
}

- (void)privacyStatementSheetDidEnd:(id)aEnd returnCode:(NSInteger)aCode contextInfo:(void *)aInfo
{
    [aEnd orderOut:self];
    if (aCode == 1) {
        _sheet = nil;
        _sheetDidEndSelector = NULL;
    }
}

- (void)showHelp:(id)aHelp
{
    AHGotoPage(CFSTR("3D Weather Globe Help"), CFSTR("topics/weather.html"), NULL);
}

- (void)privacyStatementWindowOK:(id)aOK
{
    [NSApp endSheet:_sheet returnCode:1];
}

- (void)privacyStatement:(id)aStatement
{
    _sheet = _privacyStatementWindow;
    _sheetDidEndSelector = @selector(privacyStatementSheetDidEnd:returnCode:contextInfo:);
    [NSApp beginSheet:_privacyStatementWindow modalForWindow:_window modalDelegate:self didEndSelector:_sheetDidEndSelector contextInfo:NULL];
}

- (void)doNotSubscribe:(id)aSubscribe
{
    [NSApp stopModalWithCode:0];
}

- (void)subscribeNow:(id)aNow
{
    NSString *email = [_emailField stringValue];
    id missing = [_countryPopUp indexOfSelectedItem] == 0 ? _countryPopUp : nil;
    if ([email length] == 0)
        missing = _emailField;
    if ([[_lastNameField stringValue] length] == 0)
        missing = _lastNameField;
    if ([[_firstNameField stringValue] length] == 0)
        missing = _firstNameField;
    NSBundle *bundle = [NSBundle mainBundle];
    if (missing == nil) {
        if (_isValidEmail(email)) {
            [self _collectUserInformation];
            [NSApp stopModalWithCode:1];
            return;
        }
        _sheet = NSGetAlertPanel([bundle localizedStringForKey:@"Email address not complete" value:@"" table:nil],
                                 @"%@",
                                 [bundle localizedStringForKey:@"OK" value:@"" table:nil], nil, nil,
                                 [bundle localizedStringForKey:@"Email address not complete..." value:@"" table:nil]);
        [_sheet setExcludedFromWindowsMenu:YES];
        _sheetDidEndSelector = @selector(incompleteEmailSheetDidEnd:returnCode:contextInfo:);
    } else {
        _sheet = NSGetAlertPanel([bundle localizedStringForKey:@"Required information incomplete" value:@"" table:nil],
                                 @"%@",
                                 [bundle localizedStringForKey:@"OK" value:@"" table:nil], nil, nil,
                                 [bundle localizedStringForKey:@"Required information incomplete..." value:@"" table:nil]);
        [_sheet setExcludedFromWindowsMenu:YES];
        _sheetDidEndSelector = @selector(incompleteRequiredInformationSheetDidEnd:returnCode:contextInfo:);
    }
    [NSApp beginSheet:_sheet modalForWindow:_window modalDelegate:self didEndSelector:_sheetDidEndSelector contextInfo:missing];
}

- (id)_registrationInfo
{
    return _regInfoIsValid ? _regInfo : nil;
}

- (BOOL)_runModal
{
    [self _loadNibIfNeeded];
    [NSApp activateIgnoringOtherApps:YES];
    [_window center];
    _regInfoIsValid = [NSApp runModalForWindow:_window] == 1;
    [_window orderOut:self];
    return _regInfoIsValid;
}

- (void)dealloc
{
    if (_sheet != nil && _sheet != _privacyStatementWindow)
        NSReleaseAlertPanel(_sheet);
    [_privacyStatementWindow release];
    [_window release];
    [_regInfo release];
    [super dealloc];
}

- (void)awakeFromNib
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Countries" ofType:@"plist"];
    if (path != nil) {
        NSDictionary *plist = [[[NSDictionary alloc] initWithContentsOfFile:path] autorelease];
        id countries = [plist objectForKey:@"Countries"];
        if (countries != nil && [countries isKindOfClass:[NSArray class]]) {
            NSString *first = [[_countryPopUp itemTitleAtIndex:0] retain];
            [_countryPopUp removeAllItems];
            [_countryPopUp addItemWithTitle:first];
            [_countryPopUp addItemsWithTitles:countries];
            [_countryPopUp addItemWithTitle:@"Other"];
            [first release];
        }
    }
    [_firstNameField setFormatter:[WSSubsribtionTextFormatter formatterWithMaxLength:250]];
    [_lastNameField setFormatter:[WSSubsribtionTextFormatter formatterWithMaxLength:250]];
    _regInfo = [[self _addressBookInfo] retain];
    [self _setUserInformation];
    [_window setExcludedFromWindowsMenu:YES];
}

- (void)_loadNibIfNeeded
{
    if (_window == nil)
        [NSBundle loadNibNamed:@"subscribe" owner:self];
}

- (void)_releaseSheet
{
    if (_sheet != nil)
        NSReleaseAlertPanel(_sheet);
    _sheet = nil;
    _sheetDidEndSelector = NULL;
}

- (void)_setUserInformation
{
    if (_regInfo == nil)
        return;
    _setFieldFromInfo(_firstNameField, _regInfo, kWSRFirstNameKey);
    _setFieldFromInfo(_lastNameField, _regInfo, kWSRLastNameKey);
    _setFieldFromInfo(_emailField, _regInfo, kWSREmailKey);
    id country = [_regInfo objectForKey:kWSRCountryKey];
    if ([country isKindOfClass:[NSString class]]) {
        [_countryPopUp selectItemWithTitle:[country capitalizedString]];
        if ([_countryPopUp indexOfSelectedItem] >= 0)
            return;
    } else if ([_countryPopUp selectedItem] == nil) {
        return;
    }
    [_countryPopUp selectItemAtIndex:0];
}

- (void)_collectUserInformation
{
    if (_regInfo == nil)
        _regInfo = [NSMutableDictionary new];
    [_regInfo setObject:[_firstNameField stringValue] forKey:kWSRFirstNameKey];
    [_regInfo setObject:[_lastNameField stringValue] forKey:kWSRLastNameKey];
    [_regInfo setObject:[_emailField stringValue] forKey:kWSREmailKey];
    if ([_countryPopUp indexOfSelectedItem] > 0)
        [_regInfo setObject:[[_countryPopUp selectedItem] title] forKey:kWSRCountryKey];
}

- (id)_addressBookInfo
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    ABPerson *me = [[ABAddressBook sharedAddressBook] me];
    id value = [me valueForProperty:kABFirstNameProperty];
    if (value != nil)
        [info setObject:value forKey:kWSRFirstNameKey];
    value = [me valueForProperty:kABLastNameProperty];
    if (value != nil)
        [info setObject:value forKey:kWSRLastNameKey];
    ABMultiValue *emails = [me valueForProperty:kABEmailProperty];
    value = [emails valueAtIndex:[emails indexForIdentifier:[emails primaryIdentifier]]];
    if (value != nil)
        [info setObject:value forKey:kWSREmailKey];
    ABMultiValue *addresses = [me valueForProperty:kABAddressProperty];
    value = [[addresses valueAtIndex:[addresses indexForIdentifier:[addresses primaryIdentifier]]] objectForKey:kABAddressCountryKey];
    if (value != nil)
        [info setObject:value forKey:kWSRCountryKey];
    return info;
}

@end

@implementation WSSubsribtionTextFormatter

+ (id)formatterWithMaxLength:(NSUInteger)aLength
{
    return [[[self alloc] initWithMaxLength:aLength] autorelease];
}

- (BOOL)isPartialStringValid:(id)aValid newEditingString:(id *)aString errorDescription:(id *)aDescription
{
    BOOL valid = [super isPartialStringValid:aValid newEditingString:aString errorDescription:aDescription];
    _lastLength = (unsigned int)[aValid length];
    if (valid && _lastLength > _maxLength) {
        if (aDescription != NULL)
            *aDescription = @"string is too long";
        if (_lastLength - _maxLength < 2) {
            *aString = nil;
        } else {
            *aString = [aValid substringWithRange:NSMakeRange(0, _maxLength)];
            NSBeep();
        }
        valid = NO;
    }
    return valid;
}

- (BOOL)getObjectValue:(id *)aValue forString:(id)aString errorDescription:(id *)aDescription
{
    *aValue = aString;
    return YES;
}

- (id)stringForObjectValue:(id)aValue
{
    return [aValue isKindOfClass:[NSString class]] ? aValue : nil;
}

- (id)initWithMaxLength:(NSUInteger)aLength
{
    self = [self init];
    _maxLength = (unsigned int)aLength;
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
        _maxLength = 1;
    return self;
}

@end
