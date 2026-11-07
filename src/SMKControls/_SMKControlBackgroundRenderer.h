// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/Utility/_SMKControlBackgroundRenderer.m
#import "SMKControlsPrefix.h"


@interface _SMKControlBackgroundRenderer : NSObject <SMKControlBackgroundRenderer, NSObject>
{
    float _leftCapWidth;
    float _rightCapWidth;
    float _segmentHeight;
    BOOL _sizesValid;
    NSImage * _images[20];
    unsigned int _imageInitAttempts;
}
+ (void)controlTintDidChange:(id)aChange;
+ (NSInteger)currentControlTint;
+ (NSInteger)_getCurrentControlTint;
+ (id)newBackgroundRendererForControlSize:(NSInteger)aSize;
- (void)drawBackgroundImageForObject:(id)aObject bounds:(NSRect)aBounds style:(NSUInteger)aStyle;
- (struct _SMKInset)contentInsetForObject:(id)aObject;
- (struct _SMKInset)defaultContentInset;
- (CGFloat)segmentHeightForObject:(id)aObject;
- (void)_drawFill:(NSUInteger)aFill client:(id)aClient withBounds:(NSRect)aBounds;
- (void)_drawRightCap:(NSUInteger)aCap client:(id)aClient withBounds:(NSRect *)aBounds;
- (void)_drawLeftCap:(NSUInteger)aCap client:(id)aClient withBounds:(NSRect *)aBounds;
- (CGFloat)rightCapWidthForObject:(id)aObject;
- (CGFloat)leftCapWidthForObject:(id)aObject;
- (void)_initSizes;
- (id)_imageForTag:(NSInteger)aTag;
- (id)loadImageForTag:(NSInteger)aTag;
- (void)dealloc;
@end

