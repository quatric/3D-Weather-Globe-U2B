#import "WeatherGlobePrefix.h"


@interface LayoutView : NSBox
{
    NSMutableDictionary *_subviewsDict;
    NSMutableDictionary *_initFramesDict;
    NSSize _initSize;
    int _dWidth;
    NSWindow *_wnd;
}
- (void)dealloc;
- (void)awakeFromNib;
- (void)frameDidChange:(id)aChange;
- (void)_rightFill;
- (void)_leftFill;
- (void)_xCenterPosition;
- (void)_xRightProportional:(NSInteger)aProportional;
- (void)_xLeftProportional:(NSInteger)aProportional;
- (void)_initSubviews;
- (void)_sortArraysForTag:(NSInteger)aTag;
@end

