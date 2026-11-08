/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import <QuickLite/QuickLite.h>
#import "SFTestSupport.h"

// The QuickLite compatibility shim, with the same table SFThread keeps in
// Index.db, in a temporary directory.
@interface QuickLiteTests : XCTestCase {
    NSString* directory_;
    QuickLiteDatabase* db_;
}
@end

@implementation QuickLiteTests

- (void) setUp
{
    directory_ = [SFTestTemporaryDirectory() retain];
    db_ = [[QuickLiteDatabase alloc] initWithFile: [directory_ stringByAppendingPathComponent: @"Index.db"]];
    XCTAssertTrue([db_ open]);

    NSArray* columns = [NSArray arrayWithObjects:
        QLRecordUID, @"number", @"subject", @"dat", @"board", @"count", @"local", @"rate",
        @"live", @"new", @"comment", @"scroll", @"atime", nil];
    NSArray* types = [NSArray arrayWithObjects:
        QLRecordUIDDatatype, QLNumber, QLString, QLNumber, QLString, QLNumber, QLNumber, QLNumber,
        QLBoolean, QLBoolean, QLString, QLNumber, QLDateTime, nil];
    XCTAssertTrue([db_ createTable: @"threads" withColumns: columns andDatatypes: types]);
    [db_ performQuery: @"CREATE UNIQUE INDEX IF NOT EXISTS threads_index ON threads (board, dat);"];
}

- (void) tearDown
{
    [db_ close];
    [db_ release];
    [[NSFileManager defaultManager] removeItemAtPath: directory_ error: NULL];
    [directory_ release];
}

- (void) insertThread: (int) dat subject: (NSString*) subject
{
    [db_ performQuery: [NSString stringWithFormat:
        @"INSERT OR IGNORE INTO threads (dat, board, subject, count, number) VALUES (%d, '%@', '%@', %d, %d)",
        dat, @"https://test.example.invalid/test/",
        [QuickLiteDatabase prepareStringForQuery: subject], 10, 1]];
}

- (void) testInsertAndSelectByBothColumnNames
{
    [self insertThread: 1234567890 subject: @"テスト'スレ"];
    QuickLiteCursor* cursor = [db_ performQuery:
        @"SELECT * FROM threads WHERE board = 'https://test.example.invalid/test/' AND dat = 1234567890"];
    XCTAssertEqual([cursor rowCount], 1u);
    QuickLiteRow* row = [cursor rowAtIndex: 0];
    // Quotes escaped with prepareStringForQuery: come back as typed.
    XCTAssertEqualObjects([row valueForColumn: @"threads.subject"], @"テスト'スレ");
    XCTAssertEqualObjects([row valueForColumn: @"subject"], @"テスト'スレ");
    XCTAssertEqual([row intValueForColumn: @"threads.count"], 10);
}

- (void) testUniqueIndexIgnoresDuplicates
{
    [self insertThread: 1 subject: @"a"];
    [self insertThread: 1 subject: @"b"];
    QuickLiteCursor* cursor = [db_ performQuery: @"SELECT * FROM threads"];
    XCTAssertEqual([cursor rowCount], 1u);
    XCTAssertEqualObjects([[cursor rowAtIndex: 0] stringForColumn: @"threads.subject"], @"a");
}

- (void) testCursorSaveWritesBackByRowID
{
    [self insertThread: 1 subject: @"one"];
    [self insertThread: 2 subject: @"two"];

    QuickLiteCursor* cursor = [db_ performQuery: @"SELECT * FROM threads WHERE dat = 2"];
    // Values are bound, so they are stored as given (no escaping needed).
    [cursor setValue: @"tw'o" forColumn: @"threads.subject"];
    [cursor setValue: [NSNumber numberWithInt: 3] forColumn: @"threads.rate"];
    XCTAssertTrue([cursor save]);

    QuickLiteRow* two = [[db_ performQuery: @"SELECT * FROM threads WHERE dat = 2"] rowAtIndex: 0];
    XCTAssertEqualObjects([two stringForColumn: @"threads.subject"], @"tw'o");
    XCTAssertEqual([two intValueForColumn: @"threads.rate"], 3);
    QuickLiteRow* one = [[db_ performQuery: @"SELECT * FROM threads WHERE dat = 1"] rowAtIndex: 0];
    XCTAssertEqualObjects([one stringForColumn: @"threads.subject"], @"one");
}

- (void) testNestedTransactionsCommitOnce
{
    XCTAssertTrue([db_ beginTransaction]);
    XCTAssertTrue([db_ beginTransaction]);
    [self insertThread: 1 subject: @"in transaction"];
    XCTAssertTrue([db_ commitTransaction]);
    XCTAssertTrue([db_ commitTransaction]);

    // Reopen to see what reached the file.
    [db_ close];
    XCTAssertTrue([db_ open]);
    XCTAssertEqual([[db_ performQuery: @"SELECT * FROM threads"] rowCount], 1u);
}

@end
