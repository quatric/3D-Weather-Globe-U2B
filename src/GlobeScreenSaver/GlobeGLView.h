#import "GlobeScreenSaverPrefix.h"


@interface GlobeGLView : SMK_GL_View
{
}
- (void)createSMKGLContextForNSOpenGLContext:(id)aContext;
- (BOOL)isDoubleBuffered;
- (void)prepareToAnimateNextFrameForFPS:(CGFloat)aFPS;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame isPreview:(BOOL)aPreview;
@end

