#import "CompanyLinkButton.h"

// value of an Info.plist key, localized one first
static id _infoValue(NSBundle *aBundle, NSString *aKey)
{
    id value = [[aBundle localizedInfoDictionary] objectForKey:aKey];
    if (value == nil)
        value = [[aBundle infoDictionary] objectForKey:aKey];
    return value;
}

static NSMutableDictionary *_newLinkAttributes(NSColor *aColor)
{
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:aColor, NSForegroundColorAttributeName, nil];
    [attributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
    return attributes;
}

@implementation LinkButton

- (void)setAlternateTitle:(id)aTitle
{
    [super setAlternateTitle:aTitle];
    NSMutableAttributedString *title = [[[NSMutableAttributedString alloc] initWithAttributedString:[self attributedAlternateTitle]] autorelease];
    [title addAttributes:_altTitleAttr range:NSMakeRange(0, [title length])];
    [self setAttributedAlternateTitle:title];
}

- (void)setTitle:(id)aTitle
{
    [super setTitle:aTitle];
    NSMutableAttributedString *title = [[[NSMutableAttributedString alloc] initWithAttributedString:[self attributedTitle]] autorelease];
    [title addAttributes:_titleAttr range:NSMakeRange(0, [title length])];
    [self setAttributedTitle:title];
}

- (void)setAlternateColor:(id)aColor
{
    [_altTitleAttr setObject:aColor forKey:NSForegroundColorAttributeName];
    [self setAlternateTitle:[self alternateTitle]];
}

- (void)setColor:(id)aColor
{
    [_titleAttr setObject:aColor forKey:NSForegroundColorAttributeName];
    [self setTitle:[self title]];
}

- (id)getURL
{
    return _url;
}

- (void)setURL:(id)aURL
{
    [aURL retain];
    [_url release];
    _url = aURL;
}

- (BOOL)sendAction:(SEL)aAction to:(id)aTo
{
    if (aAction == NULL && _url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:_url];
        return YES;
    }
    return [super sendAction:aAction to:aTo];
}

- (void)resetCursorRects
{
    _cursorRect = [[self cell] drawingRectForBounds:[self bounds]];
    [self addCursorRect:_cursorRect cursor:_pointingHandCursor];
}

- (void)dealloc
{
    [_pointingHandCursor release];
    [_url release];
    [_titleAttr release];
    [_altTitleAttr release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self _preInit];
}

- (id)init
{
    self = [super init];
    if (self != nil)
        [self _preInit];
    return self;
}

- (void)_preInit
{
    if (_titleAttr == nil)
        _titleAttr = _newLinkAttributes([NSColor blueColor]);
    if (_altTitleAttr == nil)
        _altTitleAttr = _newLinkAttributes([NSColor redColor]);
    if (_pointingHandCursor == nil) {
        if (NSAppKitVersionNumber < 682.0)
            _pointingHandCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"hand"] hotSpot:NSMakePoint(6.0, 0.0)];
        else
            _pointingHandCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"hand_big"] hotSpot:NSMakePoint(10.0, 0.0)];
    }
    [self setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [self title]]]];
    [self setTitle:[self title]];
    [self setAlternateTitle:[self alternateTitle]];
}

@end

@implementation CompanyLinkButton

- (void)setBundleValue
{
    if (_link == nil)
        return;
    [self setTitle:_link];
    [self setAlternateTitle:_link];
    [self setURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", _link]]];
}

- (void)dealloc
{
    [_link release];
    [super dealloc];
}

- (void)_preInit
{
    [super _preInit];
    if (_link == nil) {
        _link = [[[NSBundle mainBundle] companyLink] retain];
        if (_link == nil)
            _link = [[self title] retain];
    }
    [self setBundleValue];
}

@end

@implementation VersionTextField

- (void)setBundleValue
{
    if (_version != nil)
        [self setStringValue:_version];
}

// clicking switches between the version and the build number
- (void)mouseDown:(id)aDown
{
    [self setStringValue:[[self stringValue] isEqualToString:_version] ? _build : _version];
}

- (void)dealloc
{
    [_version release];
    [_build release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self _preInit];
}

- (id)init
{
    self = [super init];
    if (self != nil)
        [self _preInit];
    return self;
}

- (void)_preInit
{
    [self setEditable:NO];
    if (_version == nil) {
        _version = [[[NSBundle mainBundle] versionString] retain];
        if (_version == nil)
            _version = [[self stringValue] retain];
    }
    if (_build == nil) {
        _build = [[[NSBundle mainBundle] buildString] retain];
        if (_build == nil)
            _build = [[self stringValue] retain];
    }
    [self setBundleValue];
}

@end

@implementation CopyrightTextField

- (void)setBundleValue
{
    if (_copyright != nil)
        [self setStringValue:_copyright];
}

- (void)awakeFromNib
{
    [self _preInit];
}

- (id)init
{
    self = [super init];
    if (self != nil)
        [self _preInit];
    return self;
}

- (void)_preInit
{
    if (_copyright == nil) {
        _copyright = [[[NSBundle mainBundle] copyrightString] retain];
        if (_copyright == nil)
            _copyright = [[self stringValue] retain];
    }
    [self setBundleValue];
}

- (void)dealloc
{
    [_copyright release];
    [super dealloc];
}

@end

@implementation AppNameTextField

- (void)setBundleValue
{
    if (_appName != nil)
        [self setStringValue:_appName];
}

- (void)dealloc
{
    [_appName release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [self _preInit];
}

- (id)init
{
    self = [super init];
    if (self != nil)
        [self _preInit];
    return self;
}

- (void)_preInit
{
    if (_appName == nil) {
        _appName = [[[NSBundle mainBundle] bundleName] retain];
        if (_appName == nil)
            _appName = [[self stringValue] retain];
    }
    [self setBundleValue];
}

@end

@implementation NSBundle (BundleInfoStrings)

- (id)companyLink
{
    return _infoValue(self, @"CompanyLink");
}

- (id)copyrightString
{
    return _infoValue(self, @"NSHumanReadableCopyright");
}

- (id)buildString
{
    id build = _infoValue(self, @"CFBundleVersion");
    if (build == nil)
        return nil;
    return [NSString stringWithFormat:@"%@ %@", [[NSBundle mainBundle] localizedStringForKey:@"Build" value:@"" table:nil], build];
}

- (id)versionString
{
    id version = _infoValue(self, @"CFBundleShortVersionString");
    if (version == nil)
        return nil;
    return [NSString stringWithFormat:@"%@ %@", [[NSBundle mainBundle] localizedStringForKey:@"Version" value:@"" table:nil], version];
}

- (id)bundleName
{
    id name = _infoValue(self, @"CFBundleDisplayName");
    if (name == nil)
        name = _infoValue(self, @"CFBundleName");
    return name;
}

@end
