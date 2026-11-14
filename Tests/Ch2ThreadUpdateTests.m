/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Thread.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

// Plays the part of SFThread: keeps the DAT cache in a temporary directory.
@interface SFTestThreadCache : NSObject {
    NSString* path_;
}
- (id)initWithPath:(NSString*)path;
@end

@implementation SFTestThreadCache
- (id)initWithPath:(NSString*)path
{
    self = [super init];
    path_ = [path copy];
    return self;
}
- (void)dealloc
{
    [path_ release];
    [super dealloc];
}
// Like SFThread, returns a retained object; Ch2Thread releases it.
- (NSData*)threadLoadCache:(Ch2Thread*)t
{
    return [[NSData alloc] initWithContentsOfFile:path_];
}
- (void)thread:(Ch2Thread*)t writeCache:(NSData*)data
{
    [data writeToFile:path_ atomically:YES];
}
- (NSDate*)threadCacheModificationDate:(Ch2Thread*)t
{
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:path_ error:NULL]
        objectForKey:NSFileModificationDate];
}
@end


typedef enum {
    SFTestDatNormal,              // the DAT, 206 with the rest for a Range
    SFTestDatRangeNotSatisfiable, // 416
    SFTestDatIgnoresRange,        // 200 with the whole DAT even for a Range
    SFTestDatConnectionLost,      // 206 that closes before Content-Length bytes
    SFTestDatCutMidLine,          // 206 whose last line has no newline
    SFTestDatServerError,         // 500 with an HTML page
    SFTestDatSlow,                // like SFTestDatNormal, after 1 second
    SFTestDatWrongRange,          // 206 whose Content-Range doesn't continue the cache
    SFTestDatNoContentRange,      // 206 without a Content-Range
} SFTestDatMode;

@interface Ch2ThreadUpdateTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSString* directory_;
    NSData* dat_;
    NSData* append_;
    int mode_; // how the server answers; see SFTestDatMode
}
@end

@implementation Ch2ThreadUpdateTests

- (void)setUp
{
    directory_ = [SFTestTemporaryDirectory() retain];
    dat_ = [SFTestFixtureShiftJIS(@"thread.dat") retain];
    append_ = [SFTestFixtureShiftJIS(@"thread-append.dat") retain];
    mode_ = 0;

    server_ = [[SFTestHTTPServer alloc] initWithHandler:^SFTestHTTPResponse*(SFTestHTTPRequest* request) {
        if (![[request path] isEqualToString:@"/test/dat/1234567890.dat"]) {
            return nil;
        }
        NSMutableData* all = [NSMutableData dataWithData:dat_];
        [all appendData:append_];
        NSString* range = [request header:@"Range"];
        NSUInteger from = [range hasPrefix:@"bytes="]
            ? (NSUInteger)[[range substringFromIndex:6] integerValue]
            : NSNotFound;
        NSData* rest = (from != NSNotFound)
            ? [all subdataWithRange:NSMakeRange(from, [all length] - from)]
            : nil;
        NSDictionary* contentRange = (from != NSNotFound)
            ? [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"bytes %lu-%lu/%lu",
                                                     (unsigned long) from, (unsigned long) [all length] - 1, (unsigned long) [all length]]
                                          forKey:@"Content-Range"]
            : nil;

        switch (mode_) {
        case SFTestDatRangeNotSatisfiable:
            return [SFTestHTTPResponse responseWithStatus:416 headers:nil body:[NSData data]];
        case SFTestDatIgnoresRange:
            return [SFTestHTTPResponse responseWithStatus:200 headers:nil body:all];
        case SFTestDatConnectionLost: {
            // A valid 206 (it continues the cache) that closes halfway.
            NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:contentRange];
            [headers setObject:[NSString stringWithFormat:@"%lu", (unsigned long) [rest length]]
                        forKey:@"Content-Length"];
            return [SFTestHTTPResponse responseWithStatus:206
                                                  headers:headers
                                                     body:[rest subdataWithRange:NSMakeRange(0, [rest length] / 2)]];
        }
        case SFTestDatCutMidLine: {
            // The first new line whole, then the start of the second.
            NSUInteger cut = [append_ length] - 10;
            return [SFTestHTTPResponse responseWithStatus:206
                                                  headers:contentRange
                                                     body:[rest subdataWithRange:NSMakeRange(0, cut)]];
        }
        case SFTestDatServerError:
            return [SFTestHTTPResponse responseWithStatus:500
                                                  headers:nil
                                                     body:SFTestShiftJIS(@"<html><body>エラー<>です<>本当に<>\n</body></html>\n")];
        case SFTestDatWrongRange:
            return [SFTestHTTPResponse responseWithStatus:206
                                                  headers:[NSDictionary dictionaryWithObject:@"bytes 0-99/200"
                                                                                      forKey:@"Content-Range"]
                                                     body:rest];
        case SFTestDatNoContentRange:
            return [SFTestHTTPResponse responseWithStatus:206 headers:nil body:rest];
        case SFTestDatSlow:
            [NSThread sleepForTimeInterval:1.0];
            break;
        default:
            break;
        }
        if (rest) {
            return [SFTestHTTPResponse responseWithStatus:206 headers:contentRange body:rest];
        }
        return [SFTestHTTPResponse responseWithStatus:200 headers:nil body:dat_];
    }];
    XCTAssertTrue([server_ start]);
}

- (void)tearDown
{
    [server_ stop];
    [server_ release];
    [[NSFileManager defaultManager] removeItemAtPath:directory_ error:NULL];
    [directory_ release];
    [dat_ release];
    [append_ release];
}

- (Ch2Thread*)threadWithCache:(SFTestThreadCache*)cache
{
    NSURL* board = [NSURL URLWithString:@"test/" relativeToURL:[server_ baseURL]];
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber:1234567890 board:[board absoluteURL]] autorelease];
    [thread setUserAgent:@"Monazilla/1.00 (SevenFourTests)"];
    [thread setDelegate:cache];
    return thread;
}

// Runs -update and waits until it finishes or fails. Returns the name of
// the notification that ended it, or nil when none came.
- (NSString*)updateAndWait:(Ch2Thread*)thread
{
    __block NSString* ended = nil;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    void (^record)(NSNotification*) = ^(NSNotification* n) {
        XCTAssertTrue([NSThread isMainThread]);
        ended = [n name];
    };
    id a = [center addObserverForName:Ch2ThreadDidFinishUpdatingNotification
                               object:thread
                                queue:nil
                           usingBlock:record];
    id b = [center addObserverForName:Ch2ThreadConnectionDidFailNotification
                               object:thread
                                queue:nil
                           usingBlock:record];
    [thread update];
    // The download runs in the background.
    XCTAssertNil(ended);
    XCTAssertTrue([thread isUpdating]);
    SFTestWaitFor(10, ^BOOL {
        return ended != nil;
    });
    [center removeObserver:a];
    [center removeObserver:b];
    return ended;
}

- (BOOL)update:(Ch2Thread*)thread
{
    return [self updateAndWait:thread] != nil;
}

- (NSString*)cachePath
{
    return [directory_ stringByAppendingPathComponent:@"1234567890.dat"];
}

// A thread whose cache holds the first 4 messages.
- (Ch2Thread*)threadWithCachedDat
{
    [dat_ writeToFile:[self cachePath] atomically:YES];
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath:[self cachePath]] autorelease];
    return [self threadWithCache:cache];
}

- (NSData*)wholeDat
{
    NSMutableData* all = [NSMutableData dataWithData:dat_];
    [all appendData:append_];
    return all;
}

- (void)testDatURLKeepsThePort
{
    NSURL* url = [Ch2Thread URLOfDatWithBoard:[NSURL URLWithString:@"http://127.0.0.1:8765/test"]
                                       number:42];
    XCTAssertEqualObjects([url absoluteString], @"http://127.0.0.1:8765/test/dat/42.dat");

    url = [Ch2Thread URLOfDatWithBoard:[NSURL URLWithString:@"https://egg.5ch.io/software"] number:42];
    XCTAssertEqualObjects([url absoluteString], @"https://egg.5ch.io/software/dat/42.dat");

    url = [Ch2Thread URLOfHTMLWithBoard:[NSURL URLWithString:@"http://127.0.0.1:8765/test/"] number:42];
    XCTAssertEqualObjects([url absoluteString], @"http://127.0.0.1:8765/test/read.cgi/test/42/");
    url = [Ch2Thread URLOfHTMLWithBoard:[NSURL URLWithString:@"https://egg.5ch.io/software"] number:42];
    XCTAssertEqualObjects([url absoluteString], @"https://egg.5ch.io/test/read.cgi/software/42/");
}

- (void)assertBoardOf:(NSString*)url is:(NSString*)board number:(int)number
{
    int n = -1;
    NSURL* result = [Ch2Thread boardOfThreadURL:[NSURL URLWithString:url] number:&n];
    XCTAssertEqualObjects([result absoluteString], board, @"%@", url);
    if (board) {
        XCTAssertEqual(n, number, @"%@", url);
    }
}

- (void)testBoardOfThreadURLKeepsThePort
{
    // read.cgi, with and without a range, and dat.
    [self assertBoardOf:@"http://127.0.0.1:8765/test/read.cgi/test/1234567890/"
                     is:@"http://127.0.0.1:8765/test"
                 number:1234567890];
    [self assertBoardOf:@"http://127.0.0.1:8765/test/read.cgi/test/1234567890/l50"
                     is:@"http://127.0.0.1:8765/test"
                 number:1234567890];
    [self assertBoardOf:@"http://127.0.0.1:8765/test/dat/1234567890.dat"
                     is:@"http://127.0.0.1:8765/test"
                 number:1234567890];
    // Without a port, as on the real boards.
    [self assertBoardOf:@"https://egg.5ch.io/test/read.cgi/software/1234567890/"
                     is:@"https://egg.5ch.io/software"
                 number:1234567890];
    [self assertBoardOf:@"https://egg.5ch.io/software/dat/1234567890.dat"
                     is:@"https://egg.5ch.io/software"
                 number:1234567890];
    // Anything but explicit http becomes https (an internal URL included).
    [self assertBoardOf:@"sevenfour://127.0.0.1:8765/test/read.cgi/test/1234567890/"
                     is:@"https://127.0.0.1:8765/test"
                 number:1234567890];
}

- (void)testBoardOfThreadURLRejectsOtherURLs
{
    [self assertBoardOf:@"https://egg.5ch.io/software/" is:nil number:0];
    [self assertBoardOf:@"https://egg.5ch.io/software/subject.txt" is:nil number:0];
    [self assertBoardOf:@"https://egg.5ch.io/software/dat/notes.txt" is:nil number:0];
    [self assertBoardOf:@"https://egg.5ch.io/test/read.cgi/software/" is:nil number:0];
    [self assertBoardOf:@"https://egg.5ch.io/test/read.cgi/software/abc/" is:nil number:0];
}

- (void)testBoardOfThreadURLFindsTheSameDat
{
    // The thread list makes threads from the board URL; a thread URL must
    // lead to the same DAT, or a second thread is made with the wrong URL.
    NSURL* listBoard = [NSURL URLWithString:@"http://127.0.0.1:8765/test/"];
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber:1234567890 board:listBoard] autorelease];
    int number = 0;
    NSURL* board = [Ch2Thread boardOfThreadURL:[thread URLOfHTML] number:&number];
    XCTAssertEqualObjects([Ch2Thread URLOfDatWithBoard:board number:number], [thread URLOfDat]);
}

- (void)testIfModifiedSinceIsTheCacheDateInRFC1123
{
    Ch2Thread* thread = [self threadWithCachedDat];
    // 2026-11-08 00:00:00 GMT
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:1794096000];
    [[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObject:date forKey:NSFileModificationDate]
                                     ofItemAtPath:[self cachePath]
                                            error:NULL];
    XCTAssertTrue([self update:thread]);
    XCTAssertEqualObjects([[[server_ requests] lastObject] header:@"If-Modified-Since"],
        @"Sun, 08 Nov 2026 00:00:00 GMT");
}

- (void)testFetchesNewThreadAndWritesCache
{
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath:
            [directory_ stringByAppendingPathComponent:@"1234567890.dat"]] autorelease];
    Ch2Thread* thread = [self threadWithCache:cache];

    XCTAssertTrue([self update:thread]);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([thread subject], @"テストスレ");
    XCTAssertEqualObjects([[thread messageAtIndex:3] objectForKey:@"no"], [NSNumber numberWithInt:4]);
    XCTAssertFalse([thread isUpdating]);

    NSData* written = [NSData dataWithContentsOfFile:[directory_ stringByAppendingPathComponent:@"1234567890.dat"]];
    XCTAssertEqualObjects(written, dat_);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request header:@"User-Agent"], @"Monazilla/1.00 (SevenFourTests)");
    XCTAssertNil([request header:@"Range"]);
}

- (void)testFetchesOnlyTheDifference
{
    NSString* path = [directory_ stringByAppendingPathComponent:@"1234567890.dat"];
    [dat_ writeToFile:path atomically:YES];
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath:path] autorelease];
    Ch2Thread* thread = [self threadWithCache:cache];

    XCTAssertTrue([self update:thread]);
    XCTAssertEqual([thread count], 6);
    XCTAssertEqual([thread newCount], 2);
    XCTAssertEqualObjects([[thread messageAtIndex:4] objectForKey:@"body"], @" 5 つめ（差分） ");

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request header:@"Range"],
        ([NSString stringWithFormat:@"bytes=%lu-", (unsigned long) [dat_ length]]));

    // The cache now holds the whole DAT, once.
    NSMutableData* expected = [NSMutableData dataWithData:dat_];
    [expected appendData:append_];
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], expected);
}

- (void)testRangeNotSatisfiableKeepsTheCache
{
    NSString* path = [directory_ stringByAppendingPathComponent:@"1234567890.dat"];
    [dat_ writeToFile:path atomically:YES];
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath:path] autorelease];
    Ch2Thread* thread = [self threadWithCache:cache];

    mode_ = SFTestDatRangeNotSatisfiable;
    XCTAssertTrue([self update:thread]);
    XCTAssertEqual([thread count], 4);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:path], dat_);
}

- (void)testFailedFetchAllowsTheNextUpdate
{
    // Nothing listens on port 9 of the loopback interface.
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber:1234567890
                                                     board:[NSURL URLWithString:@"http://127.0.0.1:9/test/"]] autorelease];
    XCTAssertTrue([self update:thread]);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqual([thread count], 0);
}

- (void)testWholeDatForARangeReplacesTheCache
{
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatIgnoresRange;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);

    // Not 4 + 6: the whole DAT replaces what was cached.
    XCTAssertEqual([thread count], 6);
    XCTAssertEqualObjects([[thread messageAtIndex:5] objectForKey:@"no"], [NSNumber numberWithInt:6]);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], [self wholeDat]);
}

- (void)testLostConnectionKeepsTheCache
{
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatConnectionLost;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadConnectionDidFailNotification);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], dat_);

    // The next update continues from the same place.
    mode_ = SFTestDatNormal;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertEqual([thread count], 6);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], [self wholeDat]);
}

- (void)testReplyCutMidLineKeepsOnlyWholeLines
{
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatCutMidLine;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertEqual([thread count], 5);
    XCTAssertEqualObjects([[thread messageAtIndex:4] objectForKey:@"body"], @" 5 つめ（差分） ");

    // The cache ends with a whole line, so the next Range request fetches
    // the rest of the cut line and nothing is duplicated.
    NSData* cached = [NSData dataWithContentsOfFile:[self cachePath]];
    XCTAssertEqual(((const char*) [cached bytes])[[cached length] - 1], '\n');

    mode_ = SFTestDatNormal;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertEqual([thread count], 6);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], [self wholeDat]);
}

- (void)testServerErrorKeepsTheCache
{
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatServerError;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], dat_);
}

- (void)testRangeThatDoesNotContinueTheCacheIsNotAppended
{
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatWrongRange;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], dat_);
}

- (void)testRangeWithoutContentRangeIsNotAppended
{
    // Where the reply starts can't be checked, so it may not continue the cache.
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatNoContentRange;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], dat_);
}

- (void)testUpdateWhileUpdatingIsIgnored
{
    // Two tabs showing the same thread ask for an update at the same time.
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatSlow;
    __block int finished = 0;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:Ch2ThreadDidFinishUpdatingNotification
                    object:thread
                     queue:nil
                usingBlock:^(NSNotification* n) {
                    finished++;
                }];
    [thread update];
    [thread update];
    XCTAssertTrue(SFTestWaitFor(10, ^BOOL {
        return finished > 0;
    }));
    SFTestWaitFor(0.5, ^BOOL {
        return finished > 1;
    });
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    XCTAssertEqual(finished, 1);
    XCTAssertEqual([[server_ requests] count], (NSUInteger) 1);
    XCTAssertEqual([thread count], 6);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], [self wholeDat]);
}

- (void)testCancelledUpdateChangesNothing
{
    // E.g. the tab was closed, or the log deleted, while updating.
    Ch2Thread* thread = [self threadWithCachedDat];
    mode_ = SFTestDatSlow;
    __block int ended = 0;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    id a = [center addObserverForName:Ch2ThreadDidFinishUpdatingNotification
                               object:thread
                                queue:nil
                           usingBlock:^(NSNotification* n) {
                               ended++;
                           }];
    id b = [center addObserverForName:Ch2ThreadConnectionDidFailNotification
                               object:thread
                                queue:nil
                           usingBlock:^(NSNotification* n) {
                               ended++;
                           }];
    [thread update];
    [thread cancel];
    XCTAssertFalse([thread isUpdating]);

    // Give the reply time to arrive (the server waits 1 second).
    SFTestWaitFor(2, ^BOOL {
        return ended > 0;
    });
    [center removeObserver:a];
    [center removeObserver:b];
    XCTAssertEqual(ended, 0);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile:[self cachePath]], dat_);

    // The thread can be updated again.
    mode_ = SFTestDatNormal;
    XCTAssertEqualObjects([self updateAndWait:thread], Ch2ThreadDidFinishUpdatingNotification);
    XCTAssertEqual([thread count], 6);
}

@end
