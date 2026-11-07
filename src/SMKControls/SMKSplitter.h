// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKSplitter.m
#import "SMKControlsPrefix.h"


@interface SMKSplitter : NSView <NSCoding>
{
    NSImage *_splitterImage;
    BOOL _smkcIsNotOpaque;
}
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (id)_trackableEnclosingSplitView;
- (id)enclosingSplitView;
- (void)mouseDown:(id)aDown;
- (void)sizeToFit;
- (void)drawRect:(NSRect)aRect;
- (void)setOpaque:(BOOL)aOpaque;
- (BOOL)isOpaque;
- (id)_splitterImage;
- (void)setSplitterImage:(id)aImage;
- (id)splitterImage;
@end

