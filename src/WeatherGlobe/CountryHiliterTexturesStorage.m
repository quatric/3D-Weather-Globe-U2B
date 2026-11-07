#import "CountryHiliterTexturesStorage.h"

// The one pool of 256x256 RGBA textures the country hiliters draw into, kept
// in separate arrays ("parts") so each hiliter reuses its own textures.

static CountryHiliterTexturesStorage *_sharedStorage = nil;

@implementation CountryHiliterTexturesStorage

+ (id)storageWithContainer:(id)aContainer
{
    return [[[self alloc] initWithContainer:aContainer] autorelease];
}

+ (id)sharedStorage
{
    NSAssert(_sharedStorage != nil, @"CountryHiliterTexturesStorage instance was not created!");
    return _sharedStorage;
}

// a part or texture one past the end is created on demand
- (id)getTextureWithIndex:(NSUInteger)aIndex storagePart:(NSUInteger)aPart
{
    NSUInteger partsCount = [_texturesArrays count];
    NSAssert(aPart <= partsCount, @"Wrong storage part in CountryHiliterTexturesStorage !");
    NSMutableArray *textures;
    if (aPart == partsCount) {
        textures = [NSMutableArray arrayWithCapacity:16];
        [_texturesArrays addObject:textures];
    } else {
        textures = [_texturesArrays objectAtIndex:aPart];
    }
    NSUInteger count = [textures count];
    NSAssert(aIndex <= count, @"Wrong texture index in CountryHiliterTexturesStorage !");
    if (aIndex != count)
        return [textures objectAtIndex:aIndex];
    SMK_GL_2DTexture *texture = [self _createNewTexture];
    [textures addObject:texture];
    return texture;
}

- (id)_createNewTexture
{
    SMK_GL_2DTexture *texture = [[[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:1 width:256 height:256 dataFormat:GL_RGBA8] autorelease];
    [texture setWrapS:GL_CLAMP_TO_EDGE T:GL_CLAMP_TO_EDGE];
    return texture;
}

- (void)dealloc
{
    _sharedStorage = nil;
    [_texturesArrays release];
    [super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
    NSAssert(_sharedStorage == nil, @"It is incorrect to create more than one instance of CountryHiliterTexturesStorage!");
    self = [super init];
    if (self != nil) {
        _container = aContainer;
        _texturesArrays = [[NSMutableArray alloc] initWithCapacity:4];
        _sharedStorage = self;
    }
    return self;
}

@end
