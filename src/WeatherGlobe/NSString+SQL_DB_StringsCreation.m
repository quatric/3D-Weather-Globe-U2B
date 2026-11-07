#import "NSString+SQL_DB_StringsCreation.h"

@implementation NSString (SQL_DB_StringsCreation)

+ (id)selectAllObjectUIDsWithGeotype:(id)aGeotype representationType:(id)aType
{
    return [self stringWithFormat:@"SELECT %@.%@ %@ FROM %@, %@ WHERE %@='%@' AND %@.%@=%@.%@ AND %@.%@='%@'",
        kGeoObjectsTableName, kColumnNameUID, kColumnNameObjectUid, kGeoObjectsTableName, kGeoDataTableName,
        kColumnNameType, aGeotype, kGeoDataTableName, kColumnNameObjectUid, kGeoObjectsTableName,
        kColumnNameUID, kGeoDataTableName, kColumnNameRepType, aType];
}

+ (id)selectBLOBUIDWithRepresentationOfType:(id)aType forObject:(id)aObject
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@='%@'",
        kColumnNameBLOBUid, kGeoDataTableName, kColumnNameRepType, aType, kColumnNameObjectUid, aObject];
}

+ (id)selectBLOBDataWithUID:(id)aUID
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@=0",
        kColumnNameBLOBData, kBLOBsTableName, kColumnNameUID, aUID, kColumnNameDEL];
}

+ (id)selectBLOBKindWithUID:(id)aUID
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@=0",
        kColumnNameKind, kBLOBsTableName, kColumnNameUID, aUID, kColumnNameDEL];
}

+ (id)selectBLOBUIDsForSampleRoutes
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@' AND %@ ISNULL",
        kColumnNameBLOBUid, kGeoDataTableName, kColumnNameRepType, kRepTypeSampleRoutes, kColumnNameDEL];
}

+ (id)selectBLOBUIDForGrid:(id)aGrid
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = '%@'",
        kColumnNameBLOBUid, kGeoDataTableName, kColumnNameRepType, aGrid];
}

+ (id)insertFilenameIntoUpdates:(id)aUpdates
{
    return [self stringWithFormat:@"INSERT INTO %@ (%@) VALUES ('%@')",
        kUpdatesTableName, kColumnNameUpdateFileName, aUpdates];
}

+ (id)selectFilenameFromUpdatesThatIsLike:(id)aLike
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ like '%@'",
        kColumnNameUpdateFileName, kUpdatesTableName, kColumnNameUpdateFileName, aLike];
}

+ (id)selectCitiesUIDsWithTimeZone:(id)aZone
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@='%@' AND %@ ISNULL",
        kColumnNameUID, kGeoObjectsTableName, kColumnNameType, kGeoTypeCity,
        kColumnNameHostTimeZone, aZone, kColumnNameDEL];
}

+ (id)selectCitiesUIDsWithCityName:(id)aName
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@='%@' AND %@ ISNULL",
        kColumnNameUID, kGeoObjectsTableName, kColumnNameType, kGeoTypeCity,
        kColumnNameName, [aName stringByEncodeAsSQLValueWOBracers], kColumnNameDEL];
}

+ (id)selectAnyCityUID
{
    return [self stringWithFormat:@"SELECT %@ FROM %@ WHERE %@='%@' AND %@ ISNULL LIMIT 1",
        kColumnNameUID, kGeoObjectsTableName, kColumnNameType, kGeoTypeCity, kColumnNameDEL];
}

+ (id)selectAllCoordinatesAndUIDs
{
    return [self stringWithFormat:@"SELECT %@, %@, %@ FROM %@ WHERE %@='%@' AND %@ NOTNULL AND %@ NOTNULL AND %@ ISNULL",
        kColumnNameLong, kColumnNameLat, kColumnNameUID, kGeoObjectsTableName, kColumnNameType,
        kGeoTypeCity, kColumnNameLat, kColumnNameLong, kColumnNameDEL];
}

+ (id)searchForGeoObjectWithSubstring:(id)aSubstring
{
    NSString *substring = [aSubstring stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *select = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@, %@, %@ FROM %@ ",
        kColumnNameUID, kColumnNameName, kColumnNameType, kColumnNameHostCountyUID,
        kColumnNameHostStateUID, kColumnNameHostCountryUID, kGeoObjectsTableName];
    if ([substring length] == 0)
        return [NSString stringWithFormat:@"%@ WHERE %@='%@' AND %@ ISNULL",
            select, kColumnNameType, kGeoTypeCity, kColumnNameDEL];

    NSArray *terms = [substring separatedSearchTerms];
    if ([terms count] != 0 && [[terms lastObject] length] > 2) {
        NSString *uids = [self selectUIDStatementForTerms:terms];
        return [NSString stringWithFormat:@"%@ WHERE %@ IN (%@) AND %@='%@' AND %@ ISNULL UNION %@ WHERE %@ IN (%@) AND %@='%@' AND %@ ISNULL UNION %@ WHERE %@ IN (%@) AND %@='%@' AND %@ ISNULL",
            select, kColumnNameUID, uids, kColumnNameType, kGeoTypeCity, kColumnNameDEL,
            select, kColumnNameHostStateUID, uids, kColumnNameType, kGeoTypeCity, kColumnNameDEL,
            select, kColumnNameHostCountryUID, uids, kColumnNameType, kGeoTypeCity, kColumnNameDEL];
    }

    NSString *value = [substring stringByEncodeAsSQLValueWOBracers];
    return [NSString stringWithFormat:@"%@ WHERE %@='%@' AND (%@ LIKE '%@%%' OR %@ LIKE '%%;%@%%' OR %@ IN (SELECT %@ FROM %@ WHERE %@='%@' AND (%@ LIKE '%@%%' OR %@ LIKE '%%;%@%%')) OR %@ IN (SELECT %@ FROM %@ WHERE %@='%@' AND (%@ LIKE '%@%%' OR %@ LIKE '%%;%@%%'))) AND %@ ISNULL",
        select, kColumnNameType, kGeoTypeCity, kColumnNameName, value, kColumnNameAltNames, value,
        kColumnNameHostStateUID, kColumnNameUID, kGeoObjectsTableName, kColumnNameType, kGeoTypeState,
        kColumnNameName, value, kColumnNameAltNames, value,
        kColumnNameHostCountryUID, kColumnNameUID, kGeoObjectsTableName, kColumnNameType, kGeoTypeCountry,
        kColumnNameName, value, kColumnNameAltNames, value, kColumnNameDEL];
}

+ (id)selectUIDStatementForTerms:(id)aTerms
{
    NSUInteger count = [aTerms count], i;
    NSMutableString *statement = [NSMutableString string];
    for (i = 0; i < count; i++) {
        NSString *term = [aTerms objectAtIndex:i];
        NSString *prefix = [[[NSString stringWithFormat:@"%@  ", term] substringToIndex:3] uppercaseString];
        if (i != 0)
            [statement appendString:@" INTERSECT "];
        [statement appendFormat:@"select %@ from %@ where kw_rowid in (select rowid from %@ where kw3='%@' and kw like '%@%%')",
            kColumnNameUID, kOcurencesTableName, kAllKeywordsTableName,
            [prefix stringByEncodeAsSQLValueWOBracers], [term stringByEncodeAsSQLValueWOBracers]];
    }
    return statement;
}

+ (id)autocompleteRequestForTerm:(id)aTerm
{
    if ([aTerm length] < 3)
        return nil;
    NSString *prefix = [[[aTerm substringToIndex:3] uppercaseString] stringByEncodeAsSQLValueWOBracers];
    NSString *term = [[aTerm uppercaseString] stringByEncodeAsSQLValueWOBracers];
    return [self stringWithFormat:@"SELECT %@.kw, count(%@.kw_rowid) FROM %@, %@, %@ WHERE kw3='%@' and kw like '%@%%' and kw!='%@' and %@.kw_rowid=%@.rowid and %@.uid=%@.uid and %@.%@='%@' group by %@.kw order by 2 desc, %@.kw desc limit 1",
        kAllKeywordsTableName, kOcurencesTableName, kAllKeywordsTableName, kOcurencesTableName,
        kGeoObjectsTableName, prefix, term, term, kOcurencesTableName, kAllKeywordsTableName,
        kGeoObjectsTableName, kOcurencesTableName, kGeoObjectsTableName, kColumnNameType, kGeoTypeCity,
        kAllKeywordsTableName, kAllKeywordsTableName];
}

+ (BOOL)fastLookupIsPossibleForSearchWithSubstring:(id)aSubstring
{
    NSArray *terms = [aSubstring separatedSearchTerms];
    return [terms count] != 0 && [[terms lastObject] length] > 2;
}

+ (id)selectGeoObjectWithBondUID:(id)aUID
{
    return [self stringWithFormat:@"SELECT * FROM %@ WHERE %@=:UID_VAL AND %@ ISNULL",
        kGeoObjectsTableName, kColumnNameUID, kColumnNameDEL];
}

+ (id)selectGeoObjectWithUID:(id)aUID
{
    return [self stringWithFormat:@"SELECT * FROM %@ WHERE %@='%@' AND %@ ISNULL",
        kGeoObjectsTableName, kColumnNameUID, aUID, kColumnNameDEL];
}

@end
