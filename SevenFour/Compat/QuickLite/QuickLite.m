/* QuickLite compatibility shim. See QuickLite.h. */

#import "QuickLite.h"
#import <sqlite3.h>

NSString* const QLRecordUID         = @"ROWID";
NSString* const QLRecordUIDDatatype = @"INTEGER PRIMARY KEY";
NSString* const QLString            = @"TEXT";
NSString* const QLNumber            = @"NUMERIC";
NSString* const QLBoolean           = @"INTEGER";
NSString* const QLDateTime          = @"REAL";

static NSString* const QLRowUIDAlias = @"__ql_rowid";

#define SQLITE_DB ((sqlite3*) db_)

static void QLBindValue(sqlite3_stmt* stmt, int index, id value)
{
    if (value == nil || value == [NSNull null]) {
        sqlite3_bind_null(stmt, index);
    } else if ([value isKindOfClass: [NSNumber class]]) {
        const char* type = [value objCType];
        if (strcmp(type, @encode(float)) == 0 || strcmp(type, @encode(double)) == 0) {
            sqlite3_bind_double(stmt, index, [value doubleValue]);
        } else {
            sqlite3_bind_int64(stmt, index, [value longLongValue]);
        }
    } else if ([value isKindOfClass: [NSDate class]]) {
        sqlite3_bind_double(stmt, index, [value timeIntervalSince1970]);
    } else if ([value isKindOfClass: [NSData class]]) {
        sqlite3_bind_blob(stmt, index, [value bytes], (int) [value length], SQLITE_TRANSIENT);
    } else {
        sqlite3_bind_text(stmt, index, [[value description] UTF8String], -1, SQLITE_TRANSIENT);
    }
}

static id QLColumnValue(sqlite3_stmt* stmt, int i)
{
    switch (sqlite3_column_type(stmt, i)) {
        case SQLITE_INTEGER:
            return [NSNumber numberWithLongLong: sqlite3_column_int64(stmt, i)];
        case SQLITE_FLOAT:
            return [NSNumber numberWithDouble: sqlite3_column_double(stmt, i)];
        case SQLITE_TEXT: {
            const unsigned char* text = sqlite3_column_text(stmt, i);
            NSString* s = [NSString stringWithUTF8String: (const char*) text];
            return s ? s : @"";
        }
        case SQLITE_BLOB:
            return [NSData dataWithBytes: sqlite3_column_blob(stmt, i)
                                  length: sqlite3_column_bytes(stmt, i)];
        default:
            return [NSNull null];
    }
}

@implementation QuickLiteDatabase

+ (NSString*) prepareStringForQuery: (NSString*) string
{
    if (! string) {
        return @"";
    }
    return [string stringByReplacingOccurrencesOfString: @"'" withString: @"''"];
}

- (id) initWithFile: (NSString*) path
{
    self = [super init];
    if (self) {
        path_ = [path copy];
    }
    return self;
}

- (void) dealloc
{
    [self close];
    [path_ release];
    [super dealloc];
}

- (BOOL) open: (BOOL) useCache
{
    return [self open];
}

- (BOOL) open
{
    if (db_) {
        return YES;
    }
    sqlite3* db = NULL;
    int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2([path_ fileSystemRepresentation], &db, flags, NULL) != SQLITE_OK) {
        NSLog(@"QuickLiteDatabase: cannot open %@: %s", path_, db ? sqlite3_errmsg(db) : "unknown error");
        if (db) {
            sqlite3_close(db);
        }
        return NO;
    }
    db_ = db;
    return YES;
}

- (void) close
{
    if (db_) {
        sqlite3_close(SQLITE_DB);
        db_ = NULL;
    }
}

- (sqlite3_stmt*) prepare: (NSString*) sql logErrors: (BOOL) logErrors
{
    sqlite3_stmt* stmt = NULL;
    if (sqlite3_prepare_v2(SQLITE_DB, [sql UTF8String], -1, &stmt, NULL) != SQLITE_OK) {
        if (logErrors) {
            NSLog(@"QuickLiteDatabase: %s (query: %@)", sqlite3_errmsg(SQLITE_DB), sql);
        }
        return NULL;
    }
    return stmt;
}

- (QuickLiteCursor*) performQuery: (NSString*) query
{
    if (! db_ && ! [self open]) {
        return nil;
    }

    NSString* trimmed = [query stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    sqlite3_stmt* stmt = NULL;

    /* For single table SELECTs, also fetch ROWID so that the cursor can be saved. */
    if ([trimmed length] > 7 &&
        [[trimmed substringToIndex: 7] caseInsensitiveCompare: @"SELECT "] == NSOrderedSame) {
        NSString* withUID = [NSString stringWithFormat: @"SELECT ROWID AS %@, %@",
                             QLRowUIDAlias, [trimmed substringFromIndex: 7]];
        stmt = [self prepare: withUID logErrors: NO];
    }
    if (! stmt) {
        stmt = [self prepare: trimmed logErrors: YES];
    }
    if (! stmt) {
        return nil;
    }

    NSMutableArray* rows = [NSMutableArray array];
    int columns = sqlite3_column_count(stmt);
    int rc;

    while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
        NSMutableDictionary* values = [NSMutableDictionary dictionaryWithCapacity: columns * 2];
        long long uid = 0;
        BOOL hasUID = NO;
        int i;

        for (i = 0; i < columns; i++) {
            NSString* name = [NSString stringWithUTF8String: sqlite3_column_name(stmt, i)];
            id value = QLColumnValue(stmt, i);

            if ([name isEqualToString: QLRowUIDAlias]) {
                uid = sqlite3_column_int64(stmt, i);
                hasUID = YES;
                continue;
            }

            [values setObject: value forKey: name];
            const char* table = sqlite3_column_table_name(stmt, i);
            const char* origin = sqlite3_column_origin_name(stmt, i);
            if (table && origin) {
                [values setObject: value
                           forKey: [NSString stringWithFormat: @"%s.%s", table, origin]];
            }
        }

        QuickLiteRow* row = [[QuickLiteRow alloc] initWithValues: values rowUID: uid hasRowUID: hasUID];
        [rows addObject: row];
        [row release];
    }

    if (rc != SQLITE_DONE) {
        NSLog(@"QuickLiteDatabase: %s (query: %@)", sqlite3_errmsg(SQLITE_DB), query);
    }
    sqlite3_finalize(stmt);

    return [[[QuickLiteCursor alloc] initWithDatabase: self rows: rows] autorelease];
}

- (BOOL) executeUpdate: (NSString*) sql arguments: (NSArray*) arguments
{
    if (! db_ && ! [self open]) {
        return NO;
    }
    sqlite3_stmt* stmt = [self prepare: sql logErrors: YES];
    if (! stmt) {
        return NO;
    }
    int i;
    for (i = 0; i < (int) [arguments count]; i++) {
        QLBindValue(stmt, i + 1, [arguments objectAtIndex: i]);
    }
    int rc = sqlite3_step(stmt);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        NSLog(@"QuickLiteDatabase: %s (query: %@)", sqlite3_errmsg(SQLITE_DB), sql);
    }
    sqlite3_finalize(stmt);
    return rc == SQLITE_DONE || rc == SQLITE_ROW;
}

- (BOOL) createTable: (NSString*) table
         withColumns: (NSArray*) columns
        andDatatypes: (NSArray*) datatypes
{
    NSMutableArray* defs = [NSMutableArray array];
    NSUInteger i;
    for (i = 0; i < [columns count] && i < [datatypes count]; i++) {
        NSString* column = [columns objectAtIndex: i];
        if ([column isEqualToString: QLRecordUID]) {
            continue;   /* SQLite provides ROWID implicitly */
        }
        [defs addObject: [NSString stringWithFormat: @"\"%@\" %@", column, [datatypes objectAtIndex: i]]];
    }
    NSString* sql = [NSString stringWithFormat: @"CREATE TABLE IF NOT EXISTS \"%@\" (%@)",
                     table, [defs componentsJoinedByString: @", "]];
    return [self executeUpdate: sql arguments: nil];
}

- (BOOL) beginTransaction
{
    if (transactionDepth_++ > 0) {
        return YES;
    }
    return [self executeUpdate: @"BEGIN TRANSACTION" arguments: nil];
}

- (BOOL) commitTransaction
{
    if (transactionDepth_ <= 0) {
        transactionDepth_ = 0;
        return NO;
    }
    if (--transactionDepth_ > 0) {
        return YES;
    }
    return [self executeUpdate: @"COMMIT TRANSACTION" arguments: nil];
}

@end

@implementation QuickLiteCursor

- (id) initWithDatabase: (QuickLiteDatabase*) database rows: (NSArray*) rows
{
    self = [super init];
    if (self) {
        database_ = [database retain];
        rows_ = [rows mutableCopy];
    }
    return self;
}

- (void) dealloc
{
    [database_ release];
    [rows_ release];
    [super dealloc];
}

- (unsigned) rowCount
{
    return (unsigned) [rows_ count];
}

- (QuickLiteRow*) rowAtIndex: (unsigned) index
{
    if (index >= [rows_ count]) {
        return nil;
    }
    return [rows_ objectAtIndex: index];
}

- (void) setValue: (id) value forColumn: (NSString*) column
{
    for (QuickLiteRow* row in rows_) {
        [row setValue: value forColumn: column];
    }
}

- (BOOL) save
{
    BOOL ok = YES;
    for (QuickLiteRow* row in rows_) {
        NSDictionary* changes = [row changes];
        if ([changes count] == 0) {
            continue;
        }
        if (! [row hasRowUID]) {
            NSLog(@"QuickLiteCursor: cannot save a row without ROWID");
            ok = NO;
            continue;
        }

        /* Group changed columns by table */
        NSMutableDictionary* byTable = [NSMutableDictionary dictionary];
        for (NSString* key in changes) {
            NSRange dot = [key rangeOfString: @"." options: NSBackwardsSearch];
            if (dot.location == NSNotFound) {
                NSLog(@"QuickLiteCursor: column %@ must be qualified as table.column", key);
                ok = NO;
                continue;
            }
            NSString* table = [key substringToIndex: dot.location];
            NSString* column = [key substringFromIndex: NSMaxRange(dot)];
            NSMutableDictionary* cols = [byTable objectForKey: table];
            if (! cols) {
                cols = [NSMutableDictionary dictionary];
                [byTable setObject: cols forKey: table];
            }
            [cols setObject: [changes objectForKey: key] forKey: column];
        }

        for (NSString* table in byTable) {
            NSDictionary* cols = [byTable objectForKey: table];
            NSMutableArray* sets = [NSMutableArray array];
            NSMutableArray* args = [NSMutableArray array];
            for (NSString* column in cols) {
                [sets addObject: [NSString stringWithFormat: @"\"%@\" = ?", column]];
                [args addObject: [cols objectForKey: column]];
            }
            [args addObject: [NSNumber numberWithLongLong: [row rowUID]]];
            NSString* sql = [NSString stringWithFormat: @"UPDATE \"%@\" SET %@ WHERE ROWID = ?",
                             table, [sets componentsJoinedByString: @", "]];
            ok = [database_ executeUpdate: sql arguments: args] && ok;
        }
        [row clearChanges];
    }
    return ok;
}

@end

@implementation QuickLiteRow

- (id) initWithValues: (NSDictionary*) values rowUID: (long long) uid hasRowUID: (BOOL) hasUID
{
    self = [super init];
    if (self) {
        values_ = [values mutableCopy];
        changes_ = [[NSMutableDictionary alloc] init];
        rowUID_ = uid;
        hasRowUID_ = hasUID;
    }
    return self;
}

- (void) dealloc
{
    [values_ release];
    [changes_ release];
    [super dealloc];
}

- (id) valueForColumn: (NSString*) column
{
    id value = [values_ objectForKey: column];
    if (! value) {
        NSRange dot = [column rangeOfString: @"." options: NSBackwardsSearch];
        if (dot.location != NSNotFound) {
            value = [values_ objectForKey: [column substringFromIndex: NSMaxRange(dot)]];
        }
    }
    return value ? value : [NSNull null];
}

- (NSString*) stringForColumn: (NSString*) column
{
    id value = [self valueForColumn: column];
    if (value == [NSNull null]) {
        return nil;
    }
    return [value isKindOfClass: [NSString class]] ? value : [value description];
}

- (int) intValueForColumn: (NSString*) column
{
    id value = [self valueForColumn: column];
    return value == [NSNull null] ? 0 : [value intValue];
}

- (BOOL) boolValueForColumn: (NSString*) column
{
    return [self intValueForColumn: column] != 0;
}

- (void) setValue: (id) value forColumn: (NSString*) column
{
    id v = value ? value : [NSNull null];
    [values_ setObject: v forKey: column];
    [changes_ setObject: v forKey: column];
}

- (NSDictionary*) changes
{
    return changes_;
}

- (void) clearChanges
{
    [changes_ removeAllObjects];
}

- (long long) rowUID
{
    return rowUID_;
}

- (BOOL) hasRowUID
{
    return hasRowUID_;
}

@end
