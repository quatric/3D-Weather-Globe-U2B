#import "WeatherGlobePrefix.h"


@interface AtlasDatabase : NSObject
{
    NSRecursiveLock *_dbLocker;
    NSRecursiveLock *_searchLocker;
    SQLiteDatabase *_db;
    SQLiteStatement *_entryByUIDStatement;
    NSMutableDictionary *_geoObjects;
    NSData *_allPointsArray;
    NSData *_allPointUIDsArray;
    NSData *_entriesIndsSortedByY;
    NSArray *_allSampleRoutes;
    NSMutableDictionary *_allSampleRouteBLOBs;
    NSDictionary *_appleStoresRep;
    NSArray *_appleStores;
    NSDictionary *_appleStoreKinds;
    BoundariesContainer *_countryBorders;
    BoundariesContainer *_stateBorders;
    BoundariesContainer *_countyBorders;
    BoundariesContainer *_tzBorders;
}
+ (id)database;
- (void)setNewAppleStoresData:(id)aData;
- (id)appleStoreKinds;
- (id)appleStoresRep;
- (id)appleStores;
- (id)_appleStoresCachePath;
- (id)allCountryBordersForLOD:(NSInteger)aLOD;
- (id)allUIDsForShapeType:(NSInteger)aType;
- (id)infoWithShapeType:(NSInteger)aType underGeoPoint:(NSPoint)aPoint lod:(NSInteger)aLod;
- (id)infoWithShapeUID:(id)aUID lod:(NSInteger)aLod;
- (id)shapeUIDOfType:(NSInteger)aType underGeoPoint:(NSPoint)aPoint;
- (id)_bordersWithShapeType:(NSInteger)aType;
- (void)_rescanWasFinishedWithResult:(id)aResult;
- (void)_rescanAndApplyUpdates:(id)aUpdates;
- (void)rescanForUpdatesWithModalWindow:(id)aWindow;
- (id)dbEntryWithSystemTimeZoneCity;
- (id)dbEntryWithAddressBookCity;
- (NSPoint)geoPointForDBEntryWithUID:(id)aUID;
- (struct WeatherGlobe_anon2 *)earthVecForDBEntryWithUID:(id)aUID;
- (id)dbEntryWithUID:(id)aUID;
- (id)_createSQL_DB_EntryWithUID:(id)aUID;
- (void)rescanForUpdates;
- (id)_allUpdateFiles;
- (BOOL)_processDumpsFromFiles:(id)aFiles postNotifications:(BOOL)aNotifications;
- (void)_invalidateDBCaches;
- (int *)indicesSortedByY;
- (void)cleanupOnWindowClose;
- (void)dealloc;
- (id)init;
- (void)_initializeEntries;
- (void)_initializeSQLDatabase;
@end

@interface AtlasDatabase (NearestCitySearching)
- (id)cityNearestToGeoPoint:(NSPoint)aPoint;
@end

@interface NSDictionary (WBAtlasBoundaries)
- (NSInteger)countryRin;
- (NSRect)maxPathBounds;
- (NSRect)enclosingRect;
- (id)drawedBorderPaths;
- (id)borderPaths;
- (id)fullShapeName;
- (id)ownShapeName;
@end

