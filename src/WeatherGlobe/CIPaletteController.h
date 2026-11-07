#import "WeatherGlobePrefix.h"


@interface CIPaletteController : NSObject
{
    CIPaletteWindow *_citiesPalette;
    CIPaletteView *_citiesPaletteView;
    CIPaletteTitleView *_citiesPaletteTitleView;
    CICitiesListController *_citiesListController;
    NSSize _minContentSize;
    NSSize _contentSize;
    NSSize _maxCityViewSize;
    NSTimer *_timeTick;
    BOOL _needReloadCitiesList;
    NSRect _titleViewComponentRect;
    NSMutableArray *_cityInfoControllers;
    NSMutableArray *_citiesIndexes;
    NSImage *_verticalSeparatorImage;
    NSMutableArray *_separatorViews;
    NSMenu *_paletteMenu;
    CityInfoController *_draggedCityInfo;
    BOOL _mouseOutside;
}
- (void)runPageLayout:(id)aLayout;
- (void)doPrint:(id)aPrint;
- (void)dealloc;
- (void)awakeFromNib;
- (id)init;
- (BOOL)markerColumnAction:(id)aAction forCity:(id)aCity;
- (BOOL)cityIsMarked:(id)aMarked;
- (BOOL)dragIsSupportedForController:(id)aController;
- (void)menuDidClose:(id)aClose;
- (void)windowDidBecomeKey:(id)aKey;
- (void)windowDidResignKey:(id)aKey;
- (void)windowDidResize:(id)aResize;
- (BOOL)windowShouldClose:(id)aClose;
- (void)moveUp:(id)aUp;
- (void)moveRight:(id)aRight;
- (void)moveLeft:(id)aLeft;
- (void)moveDown:(id)aDown;
- (void)deleteForward:(id)aForward;
- (void)removeAllCities;
- (void)manualUpdate;
- (BOOL)paletteIsVisible;
- (void)togglePalette;
- (void)hidePalette;
- (void)showPalette;
- (void)_transparencyLevelWasChanged:(id)aChanged;
- (void)_acceptDraggingRemoveCity:(id)aCity;
- (void)_acceptDraggingExited:(id)aExited;
- (void)_acceptDraggingUpdated:(id)aUpdated;
- (void)_acceptDraggingEntered:(id)aEntered;
- (void)_acceptAddCities:(id)aCities;
- (void)_acceptResetCities:(id)aCities;
- (void)_acceptNeedReconstruct:(id)aReconstruct;
- (void)_timeTick:(id)aTick;
- (void)_acceptMenuAction:(id)aAction;
- (void)_acceptVerticalAction:(id)aAction;
- (void)_acceptCloseAction:(id)aAction;
- (void)_createMenu;
- (void)_addSelfMenu;
- (void)_createSelfMenu;
- (id)_menuItemWithTitle:(id)aTitle selector:(SEL)aSelector tag:(NSInteger)aTag targer:(id)aTarger;
- (id)_fontSizeMenuItem;
- (id)_newFontSizeMenuItemWithTitle:(id)aTitle tag:(NSInteger)aTag;
- (void)_paletteActionsMenu:(id)aMenu;
- (void)_fontSizeMenu:(id)aMenu;
- (void)showCityDetails:(id)aDetails;
- (BOOL)validateMenuItem:(id)aItem;
- (void)_createTitleView;
- (id)_titleViewComponents;
- (id)_buttonImageWithName:(id)aName;
- (id)_buttonWithTitle:(id)aTitle action:(SEL)aAction image:(id)aImage tag:(NSInteger)aTag enabled:(BOOL)aEnabled sendActionOn:(NSInteger)aOn;
- (void)_setCitiesFromPreferences;
- (void)_addDefaultCityIfNeeded;
- (void)_addCityInfo:(id)aInfo;
- (void)_changeVerticalState;
- (BOOL)_refreshMaxSizeWithNeedReconstruct:(BOOL)aReconstruct;
- (void)_reconstructPalette;
- (void)_resizePalette;
- (void)_adjustPalettePosition;
- (id)_screen;
- (void)_constrainKeyViewsChain;
- (void)_cacheNextImageIfNeeded;
- (void)_loadNibIfNeeded;
@end

@interface NSMenu (Extensions)
- (void)addItems:(id)aItems;
- (id)recursiveFindItemWithTag:(NSInteger)aTag;
@end

