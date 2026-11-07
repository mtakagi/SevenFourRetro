/*
 * QuickLite compatibility shim.
 *
 * SevenFour originally linked against QuickLite.framework (an Objective-C
 * SQLite wrapper) which is not available for modern macOS. This header
 * re-implements the subset of the QuickLite API used by SevenFour directly
 * on top of the system libsqlite3.
 *
 * Column values are accessible both by bare name ("subject") and by
 * "table.column" ("threads.subject"), like QuickLite.
 */

#import <Foundation/Foundation.h>

extern NSString* const QLRecordUID;
extern NSString* const QLRecordUIDDatatype;
extern NSString* const QLString;
extern NSString* const QLNumber;
extern NSString* const QLBoolean;
extern NSString* const QLDateTime;

@class QuickLiteCursor;
@class QuickLiteRow;

@interface QuickLiteDatabase : NSObject
{
    NSString* path_;
    void* db_;              /* sqlite3* */
    int transactionDepth_;
}

+ (NSString*) prepareStringForQuery: (NSString*) string;

- (id) initWithFile: (NSString*) path;
- (BOOL) open: (BOOL) useCache;
- (BOOL) open;
- (void) close;

- (QuickLiteCursor*) performQuery: (NSString*) query;

- (BOOL) createTable: (NSString*) table
         withColumns: (NSArray*) columns
        andDatatypes: (NSArray*) datatypes;

- (BOOL) beginTransaction;
- (BOOL) commitTransaction;

/* Private: used by QuickLiteCursor */
- (BOOL) executeUpdate: (NSString*) sql arguments: (NSArray*) arguments;
@end

@interface QuickLiteCursor : NSObject
{
    QuickLiteDatabase* database_;
    NSMutableArray* rows_;
}

- (id) initWithDatabase: (QuickLiteDatabase*) database rows: (NSArray*) rows;

- (unsigned) rowCount;
- (QuickLiteRow*) rowAtIndex: (unsigned) index;

/* Sets the column on every row of the cursor. Call -save to write back. */
- (void) setValue: (id) value forColumn: (NSString*) column;
- (BOOL) save;
@end

@interface QuickLiteRow : NSObject
{
    NSMutableDictionary* values_;
    NSMutableDictionary* changes_;   /* "table.column" -> value */
    long long rowUID_;
    BOOL hasRowUID_;
}

- (id) initWithValues: (NSDictionary*) values rowUID: (long long) uid hasRowUID: (BOOL) hasUID;

- (id) valueForColumn: (NSString*) column;
- (NSString*) stringForColumn: (NSString*) column;
- (int) intValueForColumn: (NSString*) column;
- (BOOL) boolValueForColumn: (NSString*) column;

/* Private: used by QuickLiteCursor */
- (void) setValue: (id) value forColumn: (NSString*) column;
- (NSDictionary*) changes;
- (void) clearChanges;
- (long long) rowUID;
- (BOOL) hasRowUID;
@end
