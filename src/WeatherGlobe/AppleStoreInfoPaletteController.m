#import "AppleStoreInfoPaletteController.h"

static NSMutableArray *_sAppleStoreInfoPaletteControllers;

@implementation AppleStoreInfoPaletteController

+ (void)hideAppleStoresInfo
{
    NSInteger count = [[self class] _sharedInstancesCount], i;
    for (i = 0; i < count; i++)
        [[[self class] _sharedInstanceAtIndex:i] _hideAppleStoreInfo];
}

// Stacks one palette per store downwards from the first, centered one, then
// moves the whole stack up if it ran off the bottom of the screen.
+ (void)showAppleStoresInfo:(id)aInfo
{
    NSInteger count = [aInfo count], i;
    NSRect visible = [[NSScreen mainScreen] visibleFrame];
    NSRect previous = NSZeroRect;
    CGFloat shift = 0.0;
    for (i = 0; i < count; i++) {
        AppleStoreInfoPaletteController *controller = [[self class] _sharedInstanceAtIndex:i];
        [controller _showAppleStoreInfo:[aInfo objectAtIndex:i] center:i == 0 previousFrame:previous];
        previous = [[controller palette] frame];
        if (NSMinY(previous) < NSMinY(visible))
            shift = NSMinY(visible) - NSMinY(previous);
    }
    if (shift > 0.0) {
        for (i = 0; i < count; i++) {
            NSWindow *palette = [[[self class] _sharedInstanceAtIndex:i] palette];
            NSRect frame = [palette frame];
            [palette setFrameOrigin:NSMakePoint(NSMinX(frame), NSMinY(frame) + shift)];
        }
    }
    NSInteger instances = [[self class] _sharedInstancesCount];
    for (i = count; i < instances; i++)
        [[[self class] _sharedInstanceAtIndex:i] _hideAppleStoreInfo];
}

+ (id)_sharedInstanceAtIndex:(NSInteger)aIndex
{
    if (_sAppleStoreInfoPaletteControllers == nil)
        _sAppleStoreInfoPaletteControllers = [[NSMutableArray alloc] initWithCapacity:8];
    if ((NSUInteger)aIndex < [_sAppleStoreInfoPaletteControllers count])
        return [_sAppleStoreInfoPaletteControllers objectAtIndex:aIndex];
    if ((NSUInteger)aIndex != [_sAppleStoreInfoPaletteControllers count])
        return nil;
    AppleStoreInfoPaletteController *controller = [[[AppleStoreInfoPaletteController alloc] init] autorelease];
    [_sAppleStoreInfoPaletteControllers addObject:controller];
    return controller;
}

+ (NSInteger)_sharedInstancesCount
{
    return [_sAppleStoreInfoPaletteControllers count];
}

- (id)palette
{
    return _palette;
}

- (void)_hideAppleStoreInfo
{
    [_palette performClose:self];
}

- (void)_showAppleStoreInfo:(id)aInfo center:(BOOL)aCenter previousFrame:(NSRect)aFrame
{
    [self _loadNibIfNeeded];
    [self _setValues:aInfo];
    if (aCenter) {
        if (![_palette isVisible])
            [_palette center];
    } else {
        NSRect frame = [_palette frame];
        [_palette setFrame:NSMakeRect(NSMinX(aFrame), NSMinY(aFrame) - NSHeight(frame) - 5.0, NSWidth(frame), NSHeight(frame))
                   display:YES];
    }
    [_palette makeKeyAndOrderFront:self];
}

- (void)_setValues:(id)aValues
{
    NSString *title = @"";
    NSString *name = [aValues alternativeName];
    if (name != nil) {
        NSMutableString *trimmed = [NSMutableString stringWithString:name];
        [trimmed replaceOccurrencesOfString:@"Apple Store " withString:@"" options:NSAnchoredSearch
                                      range:NSMakeRange(0, [trimmed length])];
        title = trimmed;
    }
    [_title setStringValue:title];

    NSString *info = @"";
    if ([aValues additionalInfo] != nil && [[aValues additionalInfo] length] != 0)
        info = [NSString stringWithFormat:@"\n\n%@", [aValues additionalInfo]];
    NSString *address = @"";
    if ([aValues isKindOfClass:[AppleStoreEntry class]] && [aValues address] != nil)
        address = [aValues address];
    [_additionalInfo setStringValue:[NSString stringWithFormat:@"%@%@", address, info]];

    NSString *url = [aValues url];
    [_urlLink setURL:[NSURL URLWithString:url ? url : @"http://"]];
    NSString *paletteTitle = [aValues infoPaletteTitle];
    [_appleStore setStringValue:paletteTitle ? paletteTitle : @"Apple Store"];
    [self _adjustPalleteSizeToContentData];
}

// Grows the palette by however much the text outgrew its fields, keeping its top edge in place.
- (void)_adjustPalleteSizeToContentData
{
    NSRect titleFrame = [_title frame];
    NSRect infoFrame = [_additionalInfo frame];
    NSSize titleSize = [[_title cell] cellSize];
    NSSize infoSize = [[_additionalInfo cell] cellSize];
    NSRect frame = [_palette frame];
    CGFloat width = (MAX(titleSize.width, infoSize.width) - MAX(NSWidth(titleFrame), NSWidth(infoFrame))) + NSWidth(frame);
    CGFloat height = (infoSize.height - NSHeight(infoFrame)) + NSHeight(frame);
    width = MAX(_minPalleteSize.width, width);
    height = MAX(_minPalleteSize.height, height);
    [_palette setFrame:NSMakeRect(NSMinX(frame), NSHeight(frame) + NSMinY(frame) - height, width, height) display:YES];
}

- (void)_loadNibIfNeeded
{
    if (_contentView == nil)
        [NSBundle loadNibNamed:@"AppleStoreInfoPalette" owner:self];
}

- (void)dealloc
{
    [_palette release];
    [super dealloc];
}

- (void)awakeFromNib
{
    _palette = [AppleStoreInfoPalette new];
    NSRect frame = [_contentView frame];
    _minPalleteSize = frame.size;
    [_palette setContentSize:frame.size];
    [_palette setContentView:_contentView];
    [_urlLink setColor:[NSColor colorWithCalibratedRed:1.0 green:0.68 blue:0.0 alpha:1.0]];
    [_urlLink setAlternateColor:[NSColor blueColor]];
}

@end
