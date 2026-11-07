// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/SMKGridControl.m
#import "SMKControlsPrefix.h"


@class SMKGridControl;

// the grid control's data source
@interface NSObject (SMKGridControlDataSource)
- (NSInteger)numberOfItemsInGridControl:(SMKGridControl *)aControl;
- (id)gridControl:(SMKGridControl *)aControl titleForItemAt:(NSInteger)aIndex;
- (id)gridControl:(SMKGridControl *)aControl imageDataForItemAt:(NSInteger)aIndex;
- (id)gridControl:(SMKGridControl *)aControl imageForItemAt:(NSInteger)aIndex;
- (BOOL)areTitlesCanBePreloadedInGridControl:(SMKGridControl *)aControl;
- (id)pasteboardTypesForGridControl:(SMKGridControl *)aControl;
- (id)directPasteboardTypesForGridControl:(SMKGridControl *)aControl;
- (void)gridControl:(SMKGridControl *)aControl pasteboard:(id)aPasteboard provideDataForType:(id)aType;
@end

@interface SMKGridControl : NSSplitView
{
    int _mode;
    NSSize _thumbnailSize;
    NSSize _thumbnailCellSize;
    BOOL _isThreadedPreloadingEnabled;
    id dataSource;
    NSScrollView *_scrollView;
    SMKGridMatrix *_gridMatrix;
    SMKGridTableView *_tableView;
    SMKGridDrawView *_drawView;
    NSString *_placeholderString;
    NSString *_stringForEmptyTitle;
    BOOL _isDragEnabled;
}
- (void)notifyOfAppendedItems;
- (void)reloadData;
- (void)_reloadDataFrom:(NSUInteger)aFrom to:(NSUInteger)aTo;
- (void)setDataSource:(id)aSource;
- (id)dataSource;
- (id)titleForItemAt:(NSInteger)aAt;
- (void *)imageDataForItemAt:(NSInteger)aAt;
- (id)imageForItemAt:(NSInteger)aAt;
- (void)onMouseDown:(id)aDown;
- (void)setTarget:(id)aTarget;
- (void)setDoubleAction:(SEL)aAction;
- (void)setAction:(SEL)aAction;
- (void)setSelectedItem:(id)aItem byExtendingSelection:(BOOL)aSelection;
- (id)selectedItems;
- (id)selectedItem;
- (void)selectItemAtIndex:(NSUInteger)aIndex byExtendingSelection:(BOOL)aSelection;
- (NSUInteger)selectedItemIndex;
- (NSUInteger)count;
- (void)setTableViewAutofitTextDuringLiveResize:(BOOL)aResize;
- (void)setThreadedPreloadingEnabled:(BOOL)aEnabled;
- (BOOL)isThreadedPreloadingEnabled;
- (BOOL)isTitlePreloadingEnabled;
- (void)setCellControlSize:(NSInteger)aSize;
- (void)setScrollerControlSize:(NSInteger)aSize;
- (NSInteger)scrollerControlSize;
- (void)setSelectionStyle:(NSInteger)aStyle;
- (NSInteger)selectionStyle;
- (void)setAllowsMultipleSelection:(BOOL)aSelection;
- (BOOL)allowsMultipleSelection;
- (void)setThumbnailCachingEnabled:(BOOL)aEnabled;
- (BOOL)isThumbnailCachingEnabled;
- (void)setMaxTitleHeight:(CGFloat)aHeight;
- (void)setThumbnailSize:(NSSize)aSize;
- (void)setThumbnailSize:(NSSize)aSize andIntercellSpacing:(NSSize)aSpacing;
- (void)_updateSelection;
- (void)viewDidEndLiveResize;
- (void)viewWillStartLiveResize;
- (void)tableViewSelectionDidChange:(id)aChange;
- (void)setDragEnabled:(BOOL)aEnabled;
- (BOOL)isDragEnabled;
- (void)pasteboard:(id)aPasteboard provideDataForType:(id)aType;
- (void)dragImage:(id)aImage imageOrigin:(NSPoint)aOrigin source:(id)aSource event:(id)aEvent;
- (void)writeSelectionToPasteboard:(id)aPasteboard withImage:(id)aImage;
- (id)imageForMultipleDraggedItemsForImage:(id)aImage;
- (void)setStringForEmptyTitle:(id)aTitle;
- (id)stringForEmptyTitle;
- (void)drawPlaceholderStringInRect:(NSRect)aRect;
- (void)setPlaceholderString:(id)aString;
- (id)placeholderString;
- (NSInteger)mode;
- (void)setMode:(NSInteger)aMode;
- (id)tableView;
- (id)gridMatrix;
- (id)scrollView;
- (void)makeFirstResponder;
- (BOOL)acceptsFirstMouse:(id)aMouse;
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (void)dealloc;
- (void)awakeFromNib;
- (id)initWithFrame:(NSRect)aFrame;
@end

