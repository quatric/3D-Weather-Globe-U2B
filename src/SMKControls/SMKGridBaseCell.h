// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Cells/SMKGridBaseCell.m
#import "SMKControlsPrefix.h"


@interface SMKGridBaseCell : NSActionCell
{
    NSString *_textValue;
    NSImage *_textImage;
    NSFont *_textFont;
    NSImage *_altImage;
    NSSize _contentSize;
    BOOL _isUpdateNeeded;
    BOOL _isGraphicsContentReady;
    int _dataNo;
}
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (id)copyWithZone:(NSZone *)aZone;
- (void)_initVars;
- (void)_setAltImage:(id)aImage;
- (id)_altImage;
- (NSRect)textPlacementRectForBounds:(NSRect)aBounds;
- (NSRect)graphicContentPlacementRectForBounds:(NSRect)aBounds;
- (NSSize)cachedImageSizeForBounds:(NSSize)aBounds;
- (NSSize)graphicContentSize;
- (void)setGraphicsContentReady:(BOOL)aReady;
- (void)updateContentSize;
- (void)emptyCache;
- (void)updateTitleIfNeeded;
- (void)updateContentIfNeeded;
- (void)setNeedsUpdateAsItem:(NSInteger)aItem;
- (void)setImageData:(void *)aData;
- (void)setImage:(id)aImage;
- (void *)imageData;
- (BOOL)hasGraphicComponent;
- (void)setTitle:(id)aTitle;
- (id)title;
- (void)drawCachingGraphicContentInRect:(NSRect)aRect;
- (id)cachedImageWithSize:(NSSize)aSize;
- (void)cacheGraphicContentWithSize:(NSSize)aSize;
- (void)drawGraphicContentInFrame:(NSRect)aFrame;
- (void)drawSelectionInRect:(NSRect)aRect cellFrame:(NSRect)aFrame;
- (void)drawInteriorWithFrame:(NSRect)aFrame inView:(id)aView;
- (void)drawWithFrame:(NSRect)aFrame inView:(id)aView;
- (id)_makeLoadingStatusImageWithSize:(NSSize)aSize;
- (BOOL)useImageData;
- (id)controlView;
- (void)dealloc;
- (id)init;
@end

