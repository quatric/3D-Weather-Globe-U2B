// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Control.m
#import "SMKGLPrefix.h"


@interface SMK_GL_Control : NSObject
{
    SMK_GL_2DTexture *_normalTexture;
    SMK_GL_2DTexture *_overTexture;
    NSString *_title;
    SMK_GL_Font *_font;
    BOOL _keepProportions;
    NSRect _rect;
    int _currentState;
    BOOL _trackable;
    id _target;
    SEL _selector;
    int _tag;
}
- (void)drawInContext:(id)aContext;
- (NSRect)rect;
- (void)setRect:(NSRect)aRect;
- (void)setKeepProportions:(BOOL)aProportions;
- (void)setTitle:(id)aTitle;
- (id)title;
- (void)setFont:(id)aFont;
- (id)font;
- (void)performAction;
- (void)setTag:(NSInteger)aTag;
- (NSInteger)tag;
- (void)setTarget:(id)aTarget selector:(SEL)aSelector;
- (void)setTrackable:(BOOL)aTrackable;
- (void)setState:(NSInteger)aState;
- (NSInteger)state;
- (BOOL)hitByPoint:(NSPoint)aPoint;
- (NSRect)frame;
- (void)dealloc;
- (id)initWithNormalTexture:(id)aTexture mouseOverTexture:(id)aTexture2 rect:(NSRect)aRect;
@end

