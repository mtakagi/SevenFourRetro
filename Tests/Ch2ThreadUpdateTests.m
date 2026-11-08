/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Thread.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

// Plays the part of SFThread: keeps the DAT cache in a temporary directory.
@interface SFTestThreadCache : NSObject {
    NSString* path_;
}
- (id) initWithPath: (NSString*) path;
@end

@implementation SFTestThreadCache
- (id) initWithPath: (NSString*) path
{
    self = [super init];
    path_ = [path copy];
    return self;
}
- (void) dealloc
{
    [path_ release];
    [super dealloc];
}
// Like SFThread, returns a retained object; Ch2Thread releases it.
- (NSData*) threadLoadCache: (Ch2Thread*) t
{
    return [[NSData alloc] initWithContentsOfFile: path_];
}
- (void) thread: (Ch2Thread*) t writeCache: (NSData*) data
{
    [data writeToFile: path_ atomically: YES];
}
- (NSDate*) threadCacheModificationDate: (Ch2Thread*) t
{
    return [[[NSFileManager defaultManager] attributesOfItemAtPath: path_ error: NULL]
               objectForKey: NSFileModificationDate];
}
@end


@interface Ch2ThreadUpdateTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSString* directory_;
    NSData* dat_;
    NSData* append_;
    int mode_;   // 0: serve the DAT (206 for a Range), 1: answer 416
}
@end

@implementation Ch2ThreadUpdateTests

- (void) setUp
{
    directory_ = [SFTestTemporaryDirectory() retain];
    dat_ = [SFTestFixtureShiftJIS(@"thread.dat") retain];
    append_ = [SFTestFixtureShiftJIS(@"thread-append.dat") retain];
    mode_ = 0;

    server_ = [[SFTestHTTPServer alloc] initWithHandler: ^SFTestHTTPResponse* (SFTestHTTPRequest* request) {
        if (! [[request path] isEqualToString: @"/test/dat/1234567890.dat"]) {
            return nil;
        }
        if (mode_ == 1) {
            return [SFTestHTTPResponse responseWithStatus: 416 headers: nil body: [NSData data]];
        }
        NSMutableData* all = [NSMutableData dataWithData: dat_];
        [all appendData: append_];
        NSString* range = [request header: @"Range"];
        if ([range hasPrefix: @"bytes="]) {
            NSUInteger from = (NSUInteger) [[range substringFromIndex: 6] integerValue];
            NSData* rest = [all subdataWithRange: NSMakeRange(from, [all length] - from)];
            return [SFTestHTTPResponse responseWithStatus: 206 headers: nil body: rest];
        }
        return [SFTestHTTPResponse responseWithStatus: 200 headers: nil body: dat_];
    }];
    XCTAssertTrue([server_ start]);
}

- (void) tearDown
{
    [server_ stop];
    [server_ release];
    [[NSFileManager defaultManager] removeItemAtPath: directory_ error: NULL];
    [directory_ release];
    [dat_ release];
    [append_ release];
}

- (Ch2Thread*) threadWithCache: (SFTestThreadCache*) cache
{
    NSURL* board = [NSURL URLWithString: @"test/" relativeToURL: [server_ baseURL]];
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber: 1234567890 board: [board absoluteURL]] autorelease];
    [thread setUserAgent: @"Monazilla/1.00 (SevenFourTests)"];
    [thread setDelegate: cache];
    return thread;
}

// Runs -update and waits until it finishes or fails.
- (BOOL) update: (Ch2Thread*) thread
{
    __block BOOL finished = NO;
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    id a = [center addObserverForName: Ch2ThreadDidFinishUpdatingNotification object: thread queue: nil
                           usingBlock: ^(NSNotification* n) { finished = YES; }];
    id b = [center addObserverForName: Ch2ThreadConnectionDidFailNotification object: thread queue: nil
                           usingBlock: ^(NSNotification* n) { finished = YES; }];
    [thread update];
    BOOL result = SFTestWaitFor(10, ^BOOL { return finished; });
    [center removeObserver: a];
    [center removeObserver: b];
    return result;
}

- (void) testDatURLKeepsThePort
{
    NSURL* url = [Ch2Thread URLOfDatWithBoard: [NSURL URLWithString: @"http://127.0.0.1:8765/test"]
                                       number: 42];
    XCTAssertEqualObjects([url absoluteString], @"http://127.0.0.1:8765/test/dat/42.dat");

    url = [Ch2Thread URLOfDatWithBoard: [NSURL URLWithString: @"https://egg.5ch.io/software"] number: 42];
    XCTAssertEqualObjects([url absoluteString], @"https://egg.5ch.io/software/dat/42.dat");
}

- (void) testFetchesNewThreadAndWritesCache
{
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath:
        [directory_ stringByAppendingPathComponent: @"1234567890.dat"]] autorelease];
    Ch2Thread* thread = [self threadWithCache: cache];

    XCTAssertTrue([self update: thread]);
    XCTAssertEqual([thread count], 4);
    XCTAssertEqualObjects([thread subject], @"テストスレ");
    XCTAssertEqualObjects([[thread messageAtIndex: 3] objectForKey: @"no"], [NSNumber numberWithInt: 4]);
    XCTAssertFalse([thread isUpdating]);

    NSData* written = [NSData dataWithContentsOfFile: [directory_ stringByAppendingPathComponent: @"1234567890.dat"]];
    XCTAssertEqualObjects(written, dat_);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request header: @"User-Agent"], @"Monazilla/1.00 (SevenFourTests)");
    XCTAssertNil([request header: @"Range"]);
}

- (void) testFetchesOnlyTheDifference
{
    NSString* path = [directory_ stringByAppendingPathComponent: @"1234567890.dat"];
    [dat_ writeToFile: path atomically: YES];
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath: path] autorelease];
    Ch2Thread* thread = [self threadWithCache: cache];

    XCTAssertTrue([self update: thread]);
    XCTAssertEqual([thread count], 6);
    XCTAssertEqual([thread newCount], 2);
    XCTAssertEqualObjects([[thread messageAtIndex: 4] objectForKey: @"body"], @" 5 つめ（差分） ");

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request header: @"Range"],
                          ([NSString stringWithFormat: @"bytes=%lu-", (unsigned long) [dat_ length]]));

    // The cache now holds the whole DAT, once.
    NSMutableData* expected = [NSMutableData dataWithData: dat_];
    [expected appendData: append_];
    XCTAssertEqualObjects([NSData dataWithContentsOfFile: path], expected);
}

- (void) testRangeNotSatisfiableKeepsTheCache
{
    NSString* path = [directory_ stringByAppendingPathComponent: @"1234567890.dat"];
    [dat_ writeToFile: path atomically: YES];
    SFTestThreadCache* cache = [[[SFTestThreadCache alloc] initWithPath: path] autorelease];
    Ch2Thread* thread = [self threadWithCache: cache];

    mode_ = 1;
    XCTAssertTrue([self update: thread]);
    XCTAssertEqual([thread count], 4);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqualObjects([NSData dataWithContentsOfFile: path], dat_);
}

- (void) testFailedFetchAllowsTheNextUpdate
{
    // Nothing listens on port 9 of the loopback interface.
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber: 1234567890
                                                     board: [NSURL URLWithString: @"http://127.0.0.1:9/test/"]] autorelease];
    XCTAssertTrue([self update: thread]);
    XCTAssertFalse([thread isUpdating]);
    XCTAssertEqual([thread count], 0);
}

@end
