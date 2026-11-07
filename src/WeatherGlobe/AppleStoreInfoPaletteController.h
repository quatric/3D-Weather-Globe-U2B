#import "WeatherGlobePrefix.h"


@interface AppleStoreInfoPaletteController : NSObject
{
    NSView *_contentView;
    NSTextField *_appleStore;
    NSTextField *_title;
    NSTextField *_additionalInfo;
    LinkButton *_urlLink;
    AppleStoreInfoPalette *_palette;
    NSSize _minPalleteSize;
}
+ (void)hideAppleStoresInfo;
+ (void)showAppleStoresInfo:(id)aInfo;
+ (id)_sharedInstanceAtIndex:(NSInteger)aIndex;
+ (NSInteger)_sharedInstancesCount;
- (id)palette;
- (void)_hideAppleStoreInfo;
- (void)_showAppleStoreInfo:(id)aInfo center:(BOOL)aCenter previousFrame:(NSRect)aFrame;
- (void)_setValues:(id)aValues;
- (void)_adjustPalleteSizeToContentData;
- (void)_loadNibIfNeeded;
- (void)dealloc;
- (void)awakeFromNib;
@end

