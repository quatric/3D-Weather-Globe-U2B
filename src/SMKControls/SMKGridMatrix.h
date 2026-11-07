// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridMatrix.m
#import "SMKControlsPrefix.h"


@interface SMKGridMatrix : NSMatrix
{
    float _cellTitleAdditionalHeight;
    NSSize _cellContentSize;
    unsigned int _extraCellCount;
    BOOL _useDefaultResize;
    id _owningGridControl;
    float _maxTitleHeight;
    int _controlSize;
    int _selectionStyle;
    BOOL _isUpdaterRunning;
    BOOL _isUpdaterThreadActive;
    BOOL _isThreadedCellUpdatingStopped;
    NSMutableArray *_updateCellsArray;
    NSConditionLock *_updateCellsLock;
    NSLock *_stopUpdatingCellsLock;
    struct __CFRunLoop *updaterRunLoop;
    struct __CFRunLoopSource *updaterUpdateSource;
    BOOL _isPredictiveUpdaterRunning;
    NSRunLoop *_predictiveUpdatingLoop;
    BOOL _isDrawingPermitted;
    BOOL _isThumbnailCachingEnabled;
}
- (void)startThreadedCellUpdating;
- (void)stopThreadedCellUpdating;
- (void)_updateGraphicContentInCells;
- (void)_updatingThread:(id)aThread;
- (void)_initCellUpdater;
- (void)enableThreadUpdater:(BOOL)aUpdater;
- (BOOL)tableView:(id)aView writeRows:(id)aRows toPasteboard:(id)aPasteboard;
- (id)tableView:(id)aView objectValueForTableColumn:(id)aColumn row:(NSInteger)aRow;
- (NSInteger)numberOfRowsInTableView:(id)aView;
- (BOOL)sendAction:(SEL)aAction to:(id)aTo;
- (void)setSelectionStyle:(NSInteger)aStyle;
- (NSInteger)selectionStyle;
- (void)setAllowsMultipleSelection:(BOOL)aSelection;
- (BOOL)allowsMultipleSelection;
- (void)setIntercellSpacing:(NSSize)aSpacing;
- (void)setDefaultResize:(BOOL)aResize;
- (NSUInteger)fittingNumberOfColumns;
- (void)fitByWidth;
- (void)setColumnCount:(NSUInteger)aCount;
- (NSSize)_calcCellSize;
- (void)setMaxTitleHeight:(CGFloat)aHeight;
- (CGFloat)maxTitleHeight;
- (void)setCellContentSize:(NSSize)aSize;
- (NSSize)cellContentSize;
- (void)setCellTitleAdditionalHeight:(CGFloat)aHeight;
- (CGFloat)cellTitleAdditionalHeight;
- (id)imageFrameColor;
- (id)textFrameColor;
- (id)textFont;
- (void)setControlSize:(NSInteger)aSize;
- (NSInteger)controlSize;
- (void)setCellSize:(NSSize)aSize;
- (void)setCount:(NSUInteger)aCount;
- (NSUInteger)count;
- (void)_setNeedsDisplay;
- (void)setNeedsUpdateCell:(id)aCell;
- (void)_setNeedsDrawAndMakeReadyCell:(id)aCell;
- (void)_setNeedsDrawCell:(id)aCell;
- (void)_setNeedsDrawCells:(id)aCells;
- (void)drawRect:(NSRect)aRect;
- (BOOL)isDrawingPermitted;
- (BOOL)isTitlePreloading;
- (BOOL)isThreadedCellUpdatingEnabled;
- (void)setThumbnailCachingEnabled:(BOOL)aEnabled;
- (BOOL)isThumbnailCachingEnabled;
- (BOOL)isCacheAllowed;
- (void)setOwningGridControl:(id)aControl;
- (id)owningGridControl;
- (void)mouseDragged:(id)aDragged;
- (void)mouseDown:(id)aDown;
- (void)selectAll:(id)aAll;
- (void)resizeWithOldSuperviewSize:(NSSize)aSize;
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)aLocal;
- (void)onWindowBecomeResignKey:(id)aKey;
- (void)viewDidMoveToWindow;
- (BOOL)becomeFirstResponder;
- (BOOL)needsPanelToBecomeKey;
- (BOOL)acceptsFirstResponder;
- (void)encodeWithCoder:(id)aCoder;
- (id)initWithCoder:(id)aCoder;
- (void)dealloc;
- (id)initWithFrame:(NSRect)aFrame;
- (void)_initVars;
@end

