#import "WeatherGlobePrefix.h"


@interface SQLiteStatement : NSObject
{
    sqlite3_stmt *_statement;
    NSString *_request;
    SQLiteDatabase *_db;
    NSMutableArray *_columnNames;
    NSMutableArray *_columnTypes;
    NSMutableArray *_bindParamsNames;
}
- (void)reset;
- (id)processWithParameters:(id)aParameters;
- (id)process;
- (id)columnTypes;
- (id)columnNames;
- (sqlite3_stmt *)statement;
- (BOOL)_compileStatement;
- (void)dealloc;
- (id)initWithDB:(id)aDB request:(id)aRequest;
@end

@interface SQLiteResultsContainer : NSObject
{
    SQLiteStatement *_statement;
    NSArray *_columnNames;
    NSArray *_columnTypes;
    NSString **_colNamesFLAT;
    NSMutableData *_stream;
    NSMutableData *_streamOffsets;
    int _cols_count;
}
- (void)sortWithCallback:(void *)aCallback;
- (BOOL)loadValues:(void **)aValues format:(int *)aFormat count:(NSInteger)aCount atIndex:(NSUInteger)aIndex;
- (id)objectAtIndex:(NSUInteger)aIndex;
- (NSUInteger)count;
- (id)columnTypes;
- (id)columnNames;
- (id)streamOffsets;
- (id)stream;
- (void)dealloc;
- (id)initWithStatement:(id)aStatement;
@end

@interface SQLiteDatabase : NSObject
{
    sqlite3 *_database;
    NSString *_databasePath;
    NSMutableArray *_tables;
    BOOL _showTemporaryTables;
}
- (id)lastErrorString;
- (id)processRequest:(id)aRequest;
- (void)setShowTemporaryTables:(BOOL)aTables;
- (void)invalidateTables;
- (id)tableWithName:(id)aName;
- (id)tables;
- (id)databasePath;
- (sqlite3 *)database;
- (void)dealloc;
- (id)initWithDatabasePath:(id)aPath;
- (id)init;
- (void)_openDatabase:(id)aDatabase;
- (void)_closeDatabase;
@end

@interface SQLiteTable : NSObject
{
    SQLiteDatabase *_db;
    NSString *_name;
    NSString *_creationRequest;
    char *_UTF8TableName;
    NSArray *_columnNames;
    NSArray *_columnTypes;
    BOOL _isTemp;
}
+ (id)tableWithDB:(id)aDB name:(id)aName isTemp:(BOOL)aTemp;
- (BOOL)isTemp;
- (id)columnTypes;
- (id)columnNames;
- (id)creationRequest;
- (char *)c_tableName;
- (id)tableName;
- (void)dealloc;
- (id)initWithDB:(id)aDB name:(id)aName isTemp:(BOOL)aTemp;
@end

@interface NSArray (SQLEncode)
- (id)stringAsSQLValuesList;
- (id)arrayByEncodingAllAsSQLValues;
@end

@interface NSData (SQLEncode)
- (id)stringByEncodeAsSQLValue;
@end

@interface NSNumber (SQLEncode)
- (id)stringByEncodeAsSQLValue;
@end

@interface NSString (SQLSearching)
- (id)separatedSearchTerms;
@end

@interface NSString (SQLEncode)
- (id)stringByEncodeAsSQLValueWOBracers;
- (id)stringByEncodeAsSQLValue;
- (id)_stringByEncodeAsSQLValueWithBracers:(BOOL)aBracers;
@end

@interface SQLiteDatabase (SQLMacroOperations)
- (BOOL)processRequestsFromFile:(id)aFile ignoringErrors:(BOOL)aErrors;
- (BOOL)processRequestsFromFile:(id)aFile;
- (BOOL)processRequestsWithData:(id)aData ignoringErrors:(BOOL)aErrors;
- (BOOL)processRequestsWithData:(id)aData;
- (BOOL)processRequestsInArray:(id)aArray;
@end

@interface NSData (SQLMacroOperations)
- (NSInteger)lineBreakStyle;
@end

