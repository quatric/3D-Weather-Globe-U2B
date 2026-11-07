#import "WeatherGlobePrefix.h"


@interface CalcListView : NSView
{
    NSTextField *_locField;
    NSTextField *_distField;
    NSTextFieldCell *_textCell;
    NSArray *_entries;
    float _scaleCoef;
    float _aspect;
    NSSize _space;
    NSRect _layoutRect;
    float _columnWidth[2];
    int _curIndex;
    NSMutableArray *_captions;
    NSMutableData *_cellFrames;
    NSMutableData *_pageStarts;
}
- (void)drawRect:(NSRect)aRect;
- (void)preparePage:(NSInteger)aPage;
- (NSInteger)pageCount;
- (NSInteger)_layoutPages;
- (void)_prepareCaptions;
- (void)_precalcLayout;
- (id)textCell;
- (id)totalFont;
- (id)textFont;
- (void)dealloc;
- (void)setScaleCoef:(CGFloat)aCoef;
- (void)setEntries:(id)aEntries;
- (BOOL)isOpaque;
- (BOOL)isFlipped;
- (id)initWithFrame:(NSRect)aFrame;
@end

