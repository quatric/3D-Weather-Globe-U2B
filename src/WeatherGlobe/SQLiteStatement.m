#import "SQLiteStatement.h"

// The result stream stores each row as its column type codes (int32 each)
// followed by the values: REAL as float32, INTEGER as int32, TEXT/BLOB as an
// int32 length plus bytes, NULL as nothing. _streamOffsets holds each row's
// offset into the stream.

static NSString *const kSQLiteDatabaseSourceFile =
    @"/Users/3dwgbuilder/Projects/3DWGBuildFolder/WBAll/WBAtlas/../Common/Sources/SQLDatabaseSupport/SQLiteDatabase.m";

typedef int (*SQLiteResultsSortCallback)(int cols, const int *typesA, const int *typesB,
                                         const void *valuesA, const void *valuesB);

static SQLiteResultsSortCallback __user_SQL_sort_cb;
static const char *__sortingStorage;
static int __numSortingCols;

static int __resultsSortCallback(const void *a, const void *b)
{
    int offA = *(const int *)a, offB = *(const int *)b;
    return __user_SQL_sort_cb(__numSortingCols,
                              (const int *)(__sortingStorage + offA),
                              (const int *)(__sortingStorage + offB),
                              __sortingStorage + offA + __numSortingCols * 4,
                              __sortingStorage + offB + __numSortingCols * 4);
}

static int __sqlResultCallback(void *context, int count, char **values, char **names)
{
    NSMutableDictionary *row = nil;
    int i;
    for (i = 0; i < count; i++) {
        if (values[i] == NULL)
            continue;
        CFStringRef value = CFStringCreateWithBytes(NULL, (const UInt8 *)values[i], strlen(values[i]),
                                                    kCFStringEncodingNonLossyASCII, false);
        CFStringRef name = names[i] ? CFStringCreateWithBytes(NULL, (const UInt8 *)names[i], strlen(names[i]),
                                                              kCFStringEncodingNonLossyASCII, false) : NULL;
        if (value != NULL) {
            if (name != NULL) {
                if (row == nil)
                    row = [NSMutableDictionary dictionary];
                [row setObject:(id)value forKey:(id)name];
            }
            CFRelease(value);
        }
        if (name != NULL)
            CFRelease(name);
    }
    if (row != nil)
        [(NSMutableArray *)context addObject:row];
    return 0;
}

static int __sqlDummyResultCallback(void *context, int count, char **values, char **names)
{
    return 0;
}

@implementation SQLiteStatement

- (void)reset
{
    if (_statement != NULL)
        sqlite3_reset(_statement);
}

- (id)processWithParameters:(id)aParameters
{
    NSInteger count, i;
    if (_bindParamsNames == nil) {
        if (_statement == NULL && ![self _compileStatement])
            return nil;
        count = sqlite3_bind_parameter_count(_statement);
        _bindParamsNames = [[NSMutableArray alloc] initWithCapacity:count];
        for (i = 0; i < count; i++) {
            const char *name = sqlite3_bind_parameter_name(_statement, (int)i + 1);
            [_bindParamsNames addObject:[NSString stringWithUTF8String:name ? name + 1 : ""]];
        }
    } else {
        count = [_bindParamsNames count];
    }
    for (i = 0; i < count; i++) {
        id name = [_bindParamsNames objectAtIndex:i];
        id value = [aParameters objectForKey:name];
        int rc;
        if (value == nil)
            [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
                file:kSQLiteDatabaseSourceFile lineNumber:0x312
                description:@"Unable to find required parameter by var_name."];
        if ([value isKindOfClass:[NSData class]]) {
            rc = sqlite3_bind_blob(_statement, (int)i + 1, [value bytes], (int)[value length], SQLITE_TRANSIENT);
        } else if ([value isKindOfClass:[NSString class]]) {
            NSData *data = [value dataUsingEncoding:NSMacOSRomanStringEncoding];
            rc = sqlite3_bind_text(_statement, (int)i + 1, [data bytes], (int)[data length], SQLITE_TRANSIENT);
        } else if ([value isKindOfClass:[NSNumber class]]) {
            rc = sqlite3_bind_int(_statement, (int)i + 1, [value intValue]);
        } else {
            continue;
        }
        if (rc != SQLITE_OK)
            [NSException raise:@"DBSQLException" format:@""];
    }
    return [self process];
}

- (id)process
{
    if (_statement == NULL && ![self _compileStatement])
        return nil;
    int cols = sqlite3_column_count(_statement);
    SQLiteResultsContainer *results = [[[SQLiteResultsContainer alloc] initWithStatement:self] autorelease];
    NSMutableData *stream = [results stream];
    NSMutableData *offsets = [results streamOffsets];
    int typesLen = cols * 4;
    int *types = [[NSMutableData dataWithLength:typesLen] mutableBytes];
    // A little slack past 0x4000 because 4-byte values are written while used < 0x3ffc.
    char *buf = [[NSMutableData dataWithLength:0x4004] mutableBytes];
    int used = 0;
    int rc, c;

    while ((rc = sqlite3_step(_statement)) == SQLITE_ROW) {
        int offset = (int)[stream length] + used;
        [offsets appendBytes:&offset length:4];
        for (c = 0; c < cols; c++)
            types[c] = sqlite3_column_type(_statement, c);
        if (used + typesLen > 0x3ffb) {
            [stream appendBytes:buf length:used];
            used = 0;
        }
        memcpy(buf + used, types, typesLen);
        used += typesLen;
        for (c = 0; c < cols; c++) {
            switch (types[c]) {
            case SQLITE_FLOAT: {
                float f = (float)sqlite3_column_double(_statement, c);
                if (used >= 0x3ffc) {
                    [stream appendBytes:buf length:used];
                    used = 0;
                }
                memcpy(buf + used, &f, 4);
                used += 4;
                break;
            }
            case SQLITE_INTEGER: {
                int n = sqlite3_column_int(_statement, c);
                if (used >= 0x3ffc) {
                    [stream appendBytes:buf length:used];
                    used = 0;
                }
                memcpy(buf + used, &n, 4);
                used += 4;
                break;
            }
            case SQLITE_TEXT:
            case SQLITE_BLOB: {
                const void *bytes = types[c] == SQLITE_TEXT
                    ? (const void *)sqlite3_column_text(_statement, c)
                    : sqlite3_column_blob(_statement, c);
                int len = sqlite3_column_bytes(_statement, c);
                if (len + used > 0x3fff) {
                    [stream appendBytes:buf length:used];
                    used = 0;
                }
                if (len < 0x3ffc) {
                    memcpy(buf + used, &len, 4);
                    memcpy(buf + used + 4, bytes, len);
                    used += 4 + len;
                } else {
                    [stream appendBytes:&len length:4];
                    [stream appendBytes:bytes length:len];
                }
                break;
            }
            }
        }
    }
    if (rc != SQLITE_DONE)
        [NSException raise:@"DBSQLException" format:@""];
    if (used != 0)
        [stream appendBytes:buf length:used];
    return results;
}

- (id)columnTypes
{
    if (_columnTypes == nil) {
        if (_statement == NULL && ![self _compileStatement])
            return nil;
        int count = sqlite3_column_count(_statement), i;
        _columnTypes = [[NSMutableArray alloc] initWithCapacity:count];
        for (i = 0; i < count; i++) {
            const char *type = sqlite3_column_decltype(_statement, i);
            [_columnTypes addObject:type ? [NSString stringWithUTF8String:type] : @"UNKNOWN"];
        }
    }
    return _columnTypes;
}

- (id)columnNames
{
    if (_columnNames == nil) {
        if (_statement == NULL && ![self _compileStatement])
            return nil;
        int count = sqlite3_column_count(_statement), i;
        _columnNames = [[NSMutableArray alloc] initWithCapacity:count];
        for (i = 0; i < count; i++)
            [_columnNames addObject:[NSString stringWithUTF8String:sqlite3_column_name(_statement, i)]];
    }
    return _columnNames;
}

- (sqlite3_stmt *)statement
{
    if (_statement == NULL && ![self _compileStatement])
        return NULL;
    return _statement;
}

- (BOOL)_compileStatement
{
    if (_statement != NULL)
        return YES;
    // The original passed the character count as the byte length; -1 reads to the terminator.
    return sqlite3_prepare(_db.database, [_request UTF8String], -1, &_statement, NULL) == SQLITE_OK;
}

- (void)dealloc
{
    if (_statement != NULL) {
        sqlite3_finalize(_statement);
        _statement = NULL;
    }
    [_request release];
    [_columnNames release];
    [_columnTypes release];
    [_bindParamsNames release];
    [super dealloc];
}

- (id)initWithDB:(id)aDB request:(id)aRequest
{
    self = [super init];
    if (self != nil) {
        _request = [aRequest retain];
        _db = aDB;
    }
    return self;
}

@end

@implementation SQLiteResultsContainer

- (void)sortWithCallback:(void *)aCallback
{
    __user_SQL_sort_cb = (SQLiteResultsSortCallback)aCallback;
    __sortingStorage = [_stream bytes];
    __numSortingCols = _cols_count;
    qsort([_streamOffsets mutableBytes], [self count], 4, __resultsSortCallback);
    __user_SQL_sort_cb = NULL;
    __sortingStorage = NULL;
    __numSortingCols = 0;
}

- (BOOL)loadValues:(void **)aValues format:(int *)aFormat count:(NSInteger)aCount atIndex:(NSUInteger)aIndex
{
    int offset = ((const int *)[_streamOffsets bytes])[aIndex];
    const char *row = (const char *)[_stream bytes] + offset;
    const int *types = (const int *)row;
    const char *p = row + _cols_count * 4;
    int col, n = 0;
    float scanned = 0;

    for (col = 0; col < _cols_count && n < aCount; col++) {
        int type = types[col];
        if (type == SQLITE_FLOAT) {
            float f;
            memcpy(&f, p, 4);
            if (aFormat[n] == 1)
                *(int *)aValues[n] = (int)f;
            else if (aFormat[n] == 2)
                *(float *)aValues[n] = f;
            else
                goto wrongFormat;
            p += 4;
            n++;
        } else if (type == SQLITE_INTEGER) {
            int i;
            memcpy(&i, p, 4);
            if (aFormat[n] == 1)
                *(int *)aValues[n] = i;
            else if (aFormat[n] == 2)
                *(float *)aValues[n] = (float)i;
            else
                goto wrongFormat;
            p += 4;
            n++;
        } else if (type == SQLITE_TEXT || type == SQLITE_BLOB) {
            int len;
            memcpy(&len, p, 4);
            p += 4;
            int format = aFormat[n];
            if (format == 1 || format == 2) {
                char text[20];
                int copy = len < 20 ? len : 19;
                memcpy(text, p, copy);
                text[copy] = '\0';
                sscanf(text, "%f", &scanned);
            }
            if (format == 1)
                *(int *)aValues[n] = (int)scanned;
            else if (format == 2)
                *(float *)aValues[n] = scanned;
            else if (format == 3 || format == 4)
                memcpy(aValues[n], p, len);
            else
                goto wrongFormat;
            n++;
            p += len;
        }
    }
    return YES;

wrongFormat:
    NSLog(@"Wrong format catched.");
    return NO;
}

- (id)objectAtIndex:(NSUInteger)aIndex
{
    int offset = ((const int *)[_streamOffsets bytes])[aIndex];
    const char *row = (const char *)[_stream bytes] + offset;
    const int *types = (const int *)row;
    const char *p = row + _cols_count * 4;
    id objects[100], keys[100];
    int col, n = 0;

    for (col = 0; col < _cols_count; col++) {
        int len;
        switch (types[col]) {
        case SQLITE_FLOAT: {
            float f;
            memcpy(&f, p, 4);
            keys[n] = _colNamesFLAT[col];
            objects[n++] = [NSNumber numberWithFloat:f];
            p += 4;
            break;
        }
        case SQLITE_INTEGER: {
            int i;
            memcpy(&i, p, 4);
            keys[n] = _colNamesFLAT[col];
            objects[n++] = [NSNumber numberWithInt:i];
            p += 4;
            break;
        }
        case SQLITE_TEXT:
            memcpy(&len, p, 4);
            keys[n] = _colNamesFLAT[col];
            objects[n++] = [[[NSString alloc] initWithBytes:p + 4 length:len
                                                   encoding:NSMacOSRomanStringEncoding] autorelease];
            p += 4 + len;
            break;
        case SQLITE_BLOB:
            memcpy(&len, p, 4);
            keys[n] = _colNamesFLAT[col];
            objects[n++] = [NSData dataWithBytes:p + 4 length:len];
            p += 4 + len;
            break;
        }
    }
    return [NSDictionary dictionaryWithObjects:objects forKeys:keys count:n];
}

- (NSUInteger)count
{
    return [_streamOffsets length] / 4;
}

- (id)columnTypes
{
    return _columnTypes;
}

- (id)columnNames
{
    return _columnNames;
}

- (id)streamOffsets
{
    if (_streamOffsets == nil)
        _streamOffsets = [NSMutableData new];
    return _streamOffsets;
}

- (id)stream
{
    if (_stream == nil)
        _stream = [NSMutableData new];
    return _stream;
}

- (void)dealloc
{
    if (_colNamesFLAT != NULL)
        free(_colNamesFLAT);
    [_columnNames release];
    [_columnTypes release];
    [_stream release];
    [_streamOffsets release];
    [super dealloc];
}

- (id)initWithStatement:(id)aStatement
{
    self = [super init];
    if (self != nil) {
        int i;
        _statement = aStatement;
        _columnNames = [[aStatement columnNames] retain];
        _columnTypes = [[_statement columnTypes] retain];
        _cols_count = (int)[_columnNames count];
        _colNamesFLAT = malloc(sizeof(NSString *) * (_cols_count ? _cols_count : 1));
        for (i = 0; i < _cols_count; i++)
            _colNamesFLAT[i] = [_columnNames objectAtIndex:i];
        if (_cols_count > 99)
            [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
                file:kSQLiteDatabaseSourceFile lineNumber:399
                description:@"Unsupported columns count (too many)"];
    }
    return self;
}

@end

@implementation SQLiteDatabase

- (id)lastErrorString
{
    if (sqlite3_errcode(_database) == SQLITE_OK)
        return nil;
    return [NSString stringWithUTF8String:sqlite3_errmsg(_database)];
}

- (id)processRequest:(id)aRequest
{
    char *error = NULL;
    NSMutableArray *rows = [NSMutableArray array];
    if (sqlite3_exec(_database, [aRequest UTF8String], __sqlResultCallback, rows, &error) != SQLITE_OK) {
        NSString *message = [NSString stringWithUTF8String:error ? error : ""];
        sqlite3_free(error);
        [NSException raise:@"SQLRequestExecuteException" format:@"%@", message];
    }
    return rows;
}

- (void)setShowTemporaryTables:(BOOL)aTables
{
    if (_showTemporaryTables != aTables) {
        _showTemporaryTables = aTables;
        [self invalidateTables];
    }
}

- (void)invalidateTables
{
    [_tables release];
    _tables = nil;
}

- (id)tableWithName:(id)aName
{
    NSArray *tables = [self tables];
    NSUInteger count = [tables count], i;
    NSString *name = [aName lowercaseString];
    for (i = 0; i < count; i++) {
        if ([[[[tables objectAtIndex:i] tableName] lowercaseString] isEqualToString:name])
            return [tables objectAtIndex:i];
    }
    return nil;
}

- (id)tables
{
    if (_tables == nil) {
        NSArray *rows = [self processRequest:@"SELECT name FROM sqlite_master WHERE type IN ('table','view')"];
        NSUInteger count = [rows count], i;
        _tables = [[NSMutableArray alloc] initWithCapacity:count];
        for (i = 0; i < count; i++)
            [_tables addObject:[SQLiteTable tableWithDB:self
                                                   name:[[[rows objectAtIndex:i] allValues] objectAtIndex:0]
                                                 isTemp:NO]];
        if (_showTemporaryTables) {
            rows = [self processRequest:@"SELECT name FROM sqlite_temp_master WHERE type IN ('table','view')"];
            count = [rows count];
            for (i = 0; i < count; i++)
                [_tables addObject:[SQLiteTable tableWithDB:self
                                                       name:[[[rows objectAtIndex:i] allValues] objectAtIndex:0]
                                                     isTemp:YES]];
        }
    }
    return _tables;
}

- (id)databasePath
{
    return _databasePath;
}

- (sqlite3 *)database
{
    return _database;
}

- (void)dealloc
{
    [self _closeDatabase];
    [super dealloc];
}

- (id)initWithDatabasePath:(id)aPath
{
    self = [super init];
    if (self != nil) {
        @try {
            [self _openDatabase:aPath];
        } @catch (NSException *exception) {
            [self release];
            self = nil;
        }
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        if (sqlite3_open(NULL, &_database) != SQLITE_OK)
            [NSException raise:@"DBOpenException" format:@""];
    }
    return self;
}

- (void)_openDatabase:(id)aDatabase
{
    [self _closeDatabase];
    if (sqlite3_open([aDatabase fileSystemRepresentation], &_database) != SQLITE_OK)
        [NSException raise:@"DBOpenException" format:@""];
    _databasePath = [aDatabase copy];
}

- (void)_closeDatabase
{
    [_databasePath release];
    [_tables release];
    _databasePath = nil;
    _tables = nil;
    if (_database != NULL) {
        sqlite3_close(_database);
        _database = NULL;
    }
}

@end

@implementation SQLiteTable

+ (id)tableWithDB:(id)aDB name:(id)aName isTemp:(BOOL)aTemp
{
    return [[[self alloc] initWithDB:aDB name:aName isTemp:aTemp] autorelease];
}

- (BOOL)isTemp
{
    return _isTemp;
}

- (id)columnTypes
{
    return _columnTypes;
}

- (id)columnNames
{
    return _columnNames;
}

- (id)creationRequest
{
    return _creationRequest;
}

- (char *)c_tableName
{
    return _UTF8TableName;
}

- (id)tableName
{
    return _name;
}

- (void)dealloc
{
    [_creationRequest release];
    [_name release];
    [_columnNames release];
    [_columnTypes release];
    [super dealloc];
}

- (id)initWithDB:(id)aDB name:(id)aName isTemp:(BOOL)aTemp
{
    self = [super init];
    if (self != nil) {
        _isTemp = aTemp;
        _db = aDB;
        _name = [aName retain];
        _UTF8TableName = (char *)[_name UTF8String];
        NSString *format = aTemp
            ? @"SELECT sql FROM sqlite_temp_master WHERE type IN ('table','view') AND tbl_name=\"%@\""
            : @"SELECT sql FROM sqlite_master WHERE type IN ('table','view') AND tbl_name=\"%@\"";
        NSArray *rows = [_db processRequest:[NSString stringWithFormat:format, _name]];
        _creationRequest = [[[[rows objectAtIndex:0] allValues] objectAtIndex:0] retain];
        SQLiteStatement *statement = [[SQLiteStatement alloc] initWithDB:_db
            request:[NSString stringWithFormat:@"SELECT * FROM %@", _name]];
        _columnNames = [[statement columnNames] retain];
        _columnTypes = [[statement columnTypes] retain];
        [statement release];
    }
    return self;
}

@end

@implementation NSArray (SQLEncode)

- (id)stringAsSQLValuesList
{
    return [[self arrayByEncodingAllAsSQLValues] componentsJoinedByString:@", "];
}

- (id)arrayByEncodingAllAsSQLValues
{
    NSUInteger count = [self count], i;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++) {
        id object = [self objectAtIndex:i];
        id encoded = [object respondsToSelector:@selector(stringByEncodeAsSQLValue)]
            ? [object stringByEncodeAsSQLValue] : nil;
        if (encoded != nil)
            [result addObject:encoded];
        else
            NSLog(@"Cannot encode object of class %@", NSStringFromClass([object class]));
    }
    return result;
}

@end

@implementation NSData (SQLEncode)

- (id)stringByEncodeAsSQLValue
{
    static const char remap[] = "0123456789ABCDEF";
    NSUInteger length = [self length], i;
    const unsigned char *bytes = [self bytes];
    NSMutableData *data = [[NSMutableData alloc] initWithLength:length * 2 + 3];
    char *out = [data mutableBytes];
    out[0] = 'X';
    out[1] = '\'';
    out[length * 2 + 2] = '\'';
    for (i = 0; i < length; i++) {
        out[2 + i * 2] = remap[bytes[i] >> 4];
        out[3 + i * 2] = remap[bytes[i] & 0xf];
    }
    NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    [data release];
    return result;
}

@end

@implementation NSNumber (SQLEncode)

- (id)stringByEncodeAsSQLValue
{
    return [self stringValue];
}

@end

@implementation NSString (SQLSearching)

- (id)separatedSearchTerms
{
    static NSMutableCharacterSet *charsSet;
    static NSCharacterSet *separatorsSet;
    if (separatorsSet == nil) {
        charsSet = [[NSCharacterSet decimalDigitCharacterSet] mutableCopy];
        [charsSet formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
        [charsSet formUnionWithCharacterSet:[NSCharacterSet letterCharacterSet]];
        [charsSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"'"]];
        separatorsSet = [[charsSet invertedSet] retain];
    }
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSMutableArray *terms = [NSMutableArray array];
    NSString *term;
    [scanner scanUpToCharactersFromSet:charsSet intoString:NULL];
    while ([scanner scanUpToCharactersFromSet:separatorsSet intoString:&term]) {
        [terms addObject:[term uppercaseString]];
        [scanner scanUpToCharactersFromSet:charsSet intoString:NULL];
    }
    return terms;
}

@end

@implementation NSString (SQLEncode)

- (id)stringByEncodeAsSQLValueWOBracers
{
    return [self _stringByEncodeAsSQLValueWithBracers:NO];
}

- (id)stringByEncodeAsSQLValue
{
    return [self _stringByEncodeAsSQLValueWithBracers:YES];
}

- (id)_stringByEncodeAsSQLValueWithBracers:(BOOL)aBracers
{
    NSString *string = self;
    if ([self rangeOfString:@"'"].location != NSNotFound) {
        NSMutableString *escaped = [NSMutableString stringWithString:self];
        [escaped replaceOccurrencesOfString:@"'" withString:@"''" options:0
                                      range:NSMakeRange(0, [escaped length])];
        string = escaped;
    }
    return aBracers ? [NSString stringWithFormat:@"'%@'", string] : string;
}

@end

@implementation SQLiteDatabase (SQLMacroOperations)

- (BOOL)processRequestsFromFile:(id)aFile ignoringErrors:(BOOL)aErrors
{
    NSData *data = [NSData dataWithContentsOfFile:aFile options:NSDataReadingMappedIfSafe error:NULL];
    if (data == nil)
        return NO;
    return [self processRequestsWithData:data ignoringErrors:aErrors];
}

- (BOOL)processRequestsFromFile:(id)aFile
{
    return [self processRequestsFromFile:aFile ignoringErrors:NO];
}

- (BOOL)processRequestsWithData:(id)aData ignoringErrors:(BOOL)aErrors
{
    NSInteger style = [aData lineBreakStyle];
    if (style == -1)
        return NO;
    const char *p = [aData bytes];
    const char *end = p + [aData length];
    NSMutableData *lineData = [NSMutableData data];
    NSUInteger capacity = 0;
    char *line = NULL;
    char *error = NULL;

    while (p < end) {
        const char *q = p, *next = end;
        // Find the end of this line; the original dropped the final character
        // of a last line with no line break, which this does not.
        for (; q < end; q++) {
            if (style == 0 && *q == '\r' && q + 1 < end && q[1] == '\n') {
                next = q + 2;
                break;
            }
            if ((style == 1 && *q == '\n') || (style == 2 && *q == '\r')) {
                next = q + 1;
                break;
            }
        }
        NSUInteger length = q - p;
        if (capacity <= length) {
            capacity = length + 10;
            [lineData setLength:capacity];
            line = [lineData mutableBytes];
        }
        memcpy(line, p, length);
        line[length] = '\0';
        if (sqlite3_exec(_database, line, __sqlDummyResultCallback, NULL, &error) != SQLITE_OK && !aErrors) {
            sqlite3_free(error);
            return NO;
        }
        sqlite3_free(error);
        error = NULL;
        p = next;
    }
    return YES;
}

- (BOOL)processRequestsWithData:(id)aData
{
    return [self processRequestsWithData:aData ignoringErrors:NO];
}

- (BOOL)processRequestsInArray:(id)aArray
{
    NSUInteger count = [aArray count], i;
    @try {
        for (i = 0; i < count; i++)
            [self processRequest:[aArray objectAtIndex:i]];
    } @catch (NSException *exception) {
        return NO;
    }
    return YES;
}

@end

@implementation NSData (SQLMacroOperations)

- (NSInteger)lineBreakStyle
{
    NSInteger length = [self length];
    NSInteger limit = length <= 100000 ? length - 1 : 99999;
    const char *bytes = [self bytes];
    int cr = 0, lf = 0, crlf = 0;
    NSInteger i;
    for (i = 0; i < limit; i++) {
        if (bytes[i] == '\r') {
            if (bytes[i + 1] == '\n') {
                crlf++;
                i++;
            } else {
                cr++;
            }
        } else if (bytes[i] == '\n') {
            lf++;
        }
    }
    if (cr == 0) {
        if (lf == 0) {
            if (crlf != 0)
                return 0;
        } else if (crlf == 0) {
            return 1;
        }
    } else if (lf == 0 && crlf == 0) {
        return 2;
    }
    return -1;
}

@end
