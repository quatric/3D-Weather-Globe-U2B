#import "WeatherGlobePrefix.h"


@interface CountryHiliterTexturesStorage : NSObject
{
    NSMutableArray *_texturesArrays;
    SMK_GL_ObjectsContainer *_container;
}
+ (id)storageWithContainer:(id)aContainer;
+ (id)sharedStorage;
- (id)getTextureWithIndex:(NSUInteger)aIndex storagePart:(NSUInteger)aPart;
- (id)_createNewTexture;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
@end

