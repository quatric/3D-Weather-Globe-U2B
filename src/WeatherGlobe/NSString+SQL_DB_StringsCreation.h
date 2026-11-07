#import "WeatherGlobePrefix.h"


@interface NSString (SQL_DB_StringsCreation)
+ (id)selectAllObjectUIDsWithGeotype:(id)aGeotype representationType:(id)aType;
+ (id)selectBLOBUIDWithRepresentationOfType:(id)aType forObject:(id)aObject;
+ (id)selectBLOBDataWithUID:(id)aUID;
+ (id)selectBLOBKindWithUID:(id)aUID;
+ (id)selectBLOBUIDsForSampleRoutes;
+ (id)selectBLOBUIDForGrid:(id)aGrid;
+ (id)insertFilenameIntoUpdates:(id)aUpdates;
+ (id)selectFilenameFromUpdatesThatIsLike:(id)aLike;
+ (id)selectCitiesUIDsWithTimeZone:(id)aZone;
+ (id)selectCitiesUIDsWithCityName:(id)aName;
+ (id)selectAnyCityUID;
+ (id)selectAllCoordinatesAndUIDs;
+ (id)searchForGeoObjectWithSubstring:(id)aSubstring;
+ (id)selectUIDStatementForTerms:(id)aTerms;
+ (id)autocompleteRequestForTerm:(id)aTerm;
+ (BOOL)fastLookupIsPossibleForSearchWithSubstring:(id)aSubstring;
+ (id)selectGeoObjectWithBondUID:(id)aUID;
+ (id)selectGeoObjectWithUID:(id)aUID;
@end

