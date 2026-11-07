#import "GlobeScreenSaverPrefix.h"


@interface GlobeScreenSaverView : ScreenSaverView
{
    NSDictionary *_configDictionary;
    GlobeConfigureSheetController *_configureSheetController;
    GlobeGLView *_glView;
    NSSize _newSize;
    float _textureLoadingDone;
}
- (id)configDictionary;
- (id)configureSheet;
- (BOOL)hasConfigureSheet;
- (void)animateOneFrame;
- (void)drawRect:(NSRect)aRect;
- (void)stopAnimation;
- (void)startAnimation;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame isPreview:(BOOL)aPreview;
@end

@interface GlobeScreenSaverView (Private)
- (void)_fillBackGround;
@end

