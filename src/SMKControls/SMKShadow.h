// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKShadow.m
#import "SMKControlsPrefix.h"


@interface SMKShadow : NSObject
{
    unsigned int _shadowFlags;
    NSSize _shadowOffset;
    float _shadowBlurRadius;
    float _reservedFloat[3];
    void *_reserved;
}
- (void)setShadowColor:(id)aColor;
- (id)shadowColor;
- (void)set;
- (void)setShadowBlurRadius:(CGFloat)aRadius;
- (CGFloat)shadowBlurRadius;
- (void)setShadowOffset:(NSSize)aOffset;
- (NSSize)shadowOffset;
- (void)dealloc;
- (id)init;
@end

