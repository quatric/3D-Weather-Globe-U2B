#import "DrawerController.h"

// days in each month, indexed from 1
static const int _daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

static int _daysInMonthOfYear(NSInteger aMonth, NSInteger aYear)
{
    if (aMonth == 2 && (aYear & 3) == 0)
        return 29;
    if (aMonth < 1 || aMonth > 12)
        return 0;
    return _daysInMonth[aMonth];
}

@implementation DrawerController

- (void)setNeedsChangeParentWindowFrame:(BOOL)aFrame
{
    _needChangeFrame = aFrame;
}

- (void)forceRestoreParentWindowFrame
{
    if (_restoreFrame)
        [[_drawer parentWindow] setFrame:_prevFrame display:YES];
}

- (void)windowDidMove:(id)aMove
{
    if ([_drawer state] == NSDrawerOpenState)
        _restoreFrame = NO;
}

- (void)windowDidResize:(id)aResize
{
    if ([_drawer state] == NSDrawerOpenState)
        _restoreFrame = NO;
}

- (void)drawerDidClose:(id)aClose
{
    if (_needChangeFrame && _restoreFrame) {
        [[_drawer parentWindow] setFrame:_prevFrame display:YES];
        _restoreFrame = NO;
    }
    _needChangeFrame = YES;
}

- (void)drawerDidOpen:(id)aOpen
{
    NSWindow *window = [_drawer parentWindow];
    NSRect frame = [window frame];
    NSRect visible = [[NSScreen mainScreen] visibleFrame];
    NSSize drawerSize = [_drawer contentSize];
    if (_needChangeFrame) {
        // move the window left so the drawer fits on the screen
        float right = frame.origin.x + frame.size.width + drawerSize.width + 10.0f;
        float screenRight = visible.origin.x + visible.size.width;
        if (screenRight < right) {
            _prevFrame = frame;
            float x = frame.origin.x - (right - screenRight);
            float width = frame.size.width;
            if (x < visible.origin.x) {
                width = frame.size.width - (visible.origin.x - x);
                float excess = width - [window minSize].width;
                x = visible.origin.x;
                if (excess < 0.0f) {
                    width -= excess;
                    x = visible.origin.x + excess;
                }
            }
            [window setFrame:NSMakeRect(x, frame.origin.y, width, frame.size.height) display:YES];
            _restoreFrame = YES;
        }
    }
    [self selectInitialResponder];
    _needChangeFrame = YES;
}

- (void)selectInitialResponder
{
    NSWindow *window = [_drawer parentWindow];
    [window makeFirstResponder:_contentView];
    [window selectNextKeyView:nil];
}

- (BOOL)drawerIsOpenState
{
    return [_drawer state] == NSDrawerOpeningState || [_drawer state] == NSDrawerOpenState;
}

- (void)mainViewControllerClassWasChangedTo:(Class)aTo
{
    [_globeTransparency setEnabled:[aTo isSubclassOfClass:[SphereMapController class]]];
}

- (void)toggleOptions
{
    if ([self drawerIsOpenState])
        [self hideOptions];
    else
        [self showOptions];
}

- (void)hideOptions
{
    [_drawer close];
}

- (void)showOptions
{
    [_drawer openOnEdge:NSMaxXEdge];
}

- (void)controlsAction:(id)aAction
{
    NSInteger tag = [aAction tag];
    _ignoreDefaultsChangings = YES;
    switch (tag) {
    case 300:
        [Preferences setAutomoveSpeedSliderValue:[aAction floatValue]];
        break;
    case 301:
        [Preferences setCloudsAnimationSliderValue:[aAction floatValue]];
        break;
    case 400:
        if ([aAction intValue])
            [self _enableCustomTime];
        else
            [self _disableCustomTime];
        break;
    case 401:
        [_timeController setNormalizedDayTime:[aAction floatValue]];
        break;
    case 402:
        if (_currentField == _yearField || _currentField == _dayField) {
            // as strings: current AppKit groups digits for numbers ("2,026")
            [_currentField setStringValue:[NSString stringWithFormat:@"%d", [aAction intValue]]];
        } else if (_currentField == _monthField) {
            NSCalendarDate *month = [NSCalendarDate dateWithYear:2000 month:[aAction intValue] day:4 hour:0 minute:0 second:1 timeZone:nil];
            [_monthField setStringValue:[month descriptionWithCalendarFormat:@"%b"]];
        }
        [_timeController setDayMonthYearFromDate:[self _dateFromFields]];
        break;
    case 500:
        [Preferences setMarkersScale:[aAction floatValue]];
        break;
    case 700:
        [Preferences useMetricSystem:[aAction intValue] != 0];
        break;
    case 800:
        [_mainWndController setShowApples:[aAction intValue] != 0];
        break;
    case 900:
        [Preferences setShowLocationNamesEnabled:[aAction intValue] != 0];
        break;
    case 1000:
        [Preferences setGlobeTransparencyLevel:[aAction floatValue]];
        break;
    }
    _ignoreDefaultsChangings = NO;
}

- (void)controlTextDidEndEditing:(id)aEditing
{
    [_timeController setDayMonthYearFromDate:[self _dateFromFields]];
    [_dateStepper setEnabled:NO];
    _currentField = nil;
}

- (void)_textFieldDidStartEditing:(id)aEditing
{
    _currentField = [aEditing object];
    [_dateStepper setEnabled:YES];
    NSCalendarDate *date = [self _dateFromFields];
    int value;
    if (_currentField == _yearField) {
        [_dateStepper setMinValue:1900.0];
        [_dateStepper setMaxValue:2100.0];
        value = _prevYear = (int)[date yearOfCommonEra];
    } else if (_currentField == _monthField) {
        [_dateStepper setMinValue:1.0];
        [_dateStepper setMaxValue:12.0];
        value = _prevMonth = (int)[date monthOfYear];
    } else if (_currentField == _dayField) {
        double days = _daysInMonthOfYear([date monthOfYear], [date yearOfCommonEra]);
        [_dateStepper setMinValue:1.0];
        [_dateStepper setMaxValue:days];
        value = _prevDay = (int)[date dayOfMonth];
    } else {
        return;
    }
    [_dateStepper setIntValue:value];
}

- (id)_dateFromFields
{
    NSInteger year = [_yearField intValue];
    if ((NSUInteger)(year - 1900) > 200)
        year = _prevYear;
    NSString *monthName = [_monthField stringValue];
    NSCalendarDate *monthDate = [NSCalendarDate dateWithString:monthName calendarFormat:@"%B"];
    if (monthDate == nil)
        monthDate = [NSCalendarDate dateWithString:monthName calendarFormat:@"%b"];
    NSInteger month = monthDate != nil ? [monthDate monthOfYear] : _prevMonth;
    int days = _daysInMonthOfYear(month, year);
    NSInteger day = [_dayField intValue];
    if (day < 1 || day > days)
        day = _prevDay;
    return [NSCalendarDate dateWithYear:year month:month day:day hour:0 minute:0 second:1 timeZone:nil];
}

- (void)_disableCustomTime
{
    [_customTime setEnabled:NO];
    [_dayField setEnabled:NO];
    [_monthField setEnabled:NO];
    [_yearField setEnabled:NO];
    [_dateStepper setEnabled:NO];
    [_timeController setUseCustomTime:NO];
}

- (void)_enableCustomTime
{
    [_customTime setEnabled:YES];
    [_dayField setEnabled:YES];
    [_monthField setEnabled:YES];
    [_yearField setEnabled:YES];
    [_timeController setUseCustomTime:YES];
}

- (void)_worldTimeWasChanged:(id)aChanged
{
    [self _setupCustomTimeControls];
}

- (void)_defaultsWereChanged:(id)aChanged
{
    [self _setupControls];
}

- (void)_clocksMeasureWereChanged:(id)aChanged
{
    [self _setupCustomTimeControls];
}

- (void)_setupControls
{
    if (_ignoreDefaultsChangings)
        return;
    [_spinSpeed setFloatValue:[Preferences automoveSpeedSliderValue]];
    [_markerSize setFloatValue:[Preferences markersScale]];
    [_cloudsAnimSpeed setFloatValue:[Preferences cloudsAnimationSliderValue]];
    [_globeTransparency setFloatValue:[Preferences globeTransparencyLevel]];
    [_locationNames setIntValue:[Preferences showLocationNamesEnabled]];
    [_appleStoresCheckBox setIntValue:[_mainWndController showsApples]];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_contentView release];
    [_drawer release];
    [_timeController release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [_cloudsAnimSpeed setMinValue:kMinCloudsAnimationSliderValue];
    [_cloudsAnimSpeed setMaxValue:kMaxCloudsAnimationSliderValue];
    _needChangeFrame = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_clocksMeasureWereChanged:) name:kClockFormatWasChanged object:nil];
    [center addObserver:self selector:@selector(_defaultsWereChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:[_drawer parentWindow]];
    [center addObserver:self selector:@selector(windowDidMove:) name:NSWindowDidMoveNotification object:[_drawer parentWindow]];
    [_drawer setDelegate:(id)self];
    [center addObserver:self selector:@selector(_worldTimeWasChanged:) name:kWorldTimeWasChanged object:nil];
    [center addObserver:self selector:@selector(_textFieldDidStartEditing:) name:kEditCellDidStartEditingNotification object:nil];
    [self _setupCellForField:_dayField];
    [self _setupCellForField:_monthField];
    [self _setupCellForField:_yearField];
    _timeController = [[[AtlasController atlasController] timeController] retain];
    [self _setupCustomTimeControls];
    _fitClippedLabels(_contentView != nil ? _contentView : [_drawer contentView]);
}

- (void)_setupCellForField:(id)aField
{
    NSTextFieldCell *old = [aField cell];
    TextFieldCell *cell = [[[TextFieldCell alloc] init] autorelease];
    [cell setType:[old type]];
    [cell setFont:[old font]];
    [cell setFormatter:[old formatter]];
    [cell setEnabled:[old isEnabled]];
    [cell setContinuous:[old isContinuous]];
    [cell setEditable:[old isEditable]];
    [cell setSelectable:[old isSelectable]];
    [cell setBordered:[old isBordered]];
    [cell setBezeled:[old isBezeled]];
    [cell setScrollable:[old isScrollable]];
    [cell setHighlighted:[old isHighlighted]];
    [cell setAlignment:[old alignment]];
    [cell setWraps:[old wraps]];
    [cell setTarget:[old target]];
    [cell setAction:[old action]];
    [cell setTag:[old tag]];
    [cell setFocusRingType:[old focusRingType]];
    [cell setShowsFirstResponder:[old showsFirstResponder]];
    [aField setCell:cell];
}

- (void)_setupCustomTimeControls
{
    NSCalendarDate *date = [_timeController currentDate];
    if (date == nil)
        return;
    NSInteger seconds = [date secondOfMinute] + [date hourOfDay] * 3600 + [date minuteOfHour] * 60;
    [_customTime setFloatValue:(float)seconds / 86400.0f];
    NSString *format = [Preferences uses24HourClock] ? @"%H:%M:%S" : @"%I:%M:%S %p";
    [_timeField setStringValue:[date descriptionWithCalendarFormat:format]];
    [_dayField setStringValue:[NSString stringWithFormat:@"%d", (int)[date dayOfMonth]]];
    [_monthField setStringValue:[date descriptionWithCalendarFormat:@"%b"]];
    [_yearField setStringValue:[NSString stringWithFormat:@"%d", (int)[date yearOfCommonEra]]];
    BOOL custom = [_timeController usesCustomTime];
    [_useCustomTime setIntValue:custom];
    [_customTime setEnabled:custom];
    [_dayField setEnabled:custom];
    [_monthField setEnabled:custom];
    [_yearField setEnabled:custom];
}

@end
