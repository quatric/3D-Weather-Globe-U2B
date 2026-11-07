#import "WeatherGlobePrefix.h"


@interface CitiesListController : NSObject <CitiesDraggingHelperProtocol>
{
    DragSourceTableView *_citiesTableView;
    NSTextField *_filterTextField;
    NSString *_previousFilterTextFieldContent;
    id _delegate;
    NSArray *_draggedEntries;
    NSMutableArray *_sortedCityEntries;
    int _sortingMode;
    BOOL _nibWasLoaded;
    BOOL _showsAllEntries;
    NSString *_searchString;
    SQLiteResultsContainer *_searchResults;
    SQLiteResultsContainer *_allResults;
    NSMutableArray *_searchedEntries;
    NSTimer *_defferedResearchTimer;
    BOOL _isResearch;
    BOOL _isSearching;
}
- (void)tableViewSelectionDidChange:(id)aChange;
- (void)searchFieldAction:(id)aAction;
- (void)controlTextDidChange:(id)aChange;
- (void)_renewSearchResults;
- (void)_applyFilterTextUndo:(id)aUndo;
- (void)setDraggedEntries:(id)aEntries;
- (id)draggedEntries;
- (void)pasteboard:(id)aPasteboard provideDataForType:(id)aType;
- (void)tableView:(id)aView didClickTableColumn:(id)aColumn;
- (BOOL)tableView:(id)aView writeRows:(id)aRows toPasteboard:(id)aPasteboard;
- (id)tableView:(id)aView objectValueForTableColumn:(id)aColumn row:(NSInteger)aRow;
- (NSInteger)numberOfRowsInTableView:(id)aView;
- (void)setDelegate:(id)aDelegate;
- (id)delegate;
- (void)_markColumnAction:(id)aAction;
- (id)selectedItemsWithLimit:(NSInteger)aLimit createIfNeeded:(BOOL)aNeeded;
- (BOOL)singleItemIsSelected;
- (id)selectedItem;
- (void)setSearchTerm:(id)aTerm andRefreshResults:(BOOL)aResults;
- (NSInteger)_selectedRow;
- (void)reloadTableData;
- (id)citiesTableView;
- (void)loadNibIfNeeded;
- (void)dealloc;
- (void)awakeFromNib;
- (id)nibName;
- (id)searchedEntryAtIndex:(NSInteger)aIndex createIfNeeded:(BOOL)aNeeded;
- (id)currentSearchResults;
- (void)invalCurrentEntries;
@end

