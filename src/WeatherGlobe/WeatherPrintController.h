#import "WeatherGlobePrefix.h"


@interface WeatherPrintController : NSObject
{
    NSMutableArray *_cityEntries;
    NSView *_currentView;
    BOOL _nibWasLoaded;
    NSView *_pageView;
    NSView *_containerView;
    NSImageView *_titleImage;
    NSTextField *_copyrightField;
    WeatherPrintingData *_data;
    NSSize _defaultTitleImageSize;
    float _defaultCopyrightFontSize;
}
+ (void)printCities:(id)aCities;
- (void)doPrint:(id)aPrint;
- (void)preparePage:(NSInteger)aPage;
- (NSInteger)pageCount;
- (id)printJobTitle;
- (void)setCities:(id)aCities;
- (void)_adjustTextFields;
- (CGFloat)_additionalScale;
- (NSSize)_pageSize;
- (void)_loadNibIfNeeded;
- (void)dealloc;
- (id)initWithCities:(id)aCities;
- (void)awakeFromNib;
@end

