/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Board.h"
#import "Ch2BoardTree.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

// Records what Ch2Board tells its delegate.
@interface SFTestBoardDelegate : NSObject {
@public
    NSError* error_;
}
@end

@implementation SFTestBoardDelegate
- (void)board:(Ch2Board*)board didFailWithError:(NSError*)err
{
    [error_ release];
    error_ = [err retain];
}

- (void)dealloc
{
    [error_ release];
    [super dealloc];
}
@end

@interface Ch2BoardTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSData* subject_;
    // Path to reply for /bbsmenu.html ("status" and "body" keys), shared with the server.
    NSMutableDictionary* menu_;
}
@end

@implementation Ch2BoardTests

- (void)setUp
{
    subject_ = [SFTestFixtureShiftJIS(@"subject.txt") retain];
    NSData* menu = SFTestFixtureShiftJIS(@"bbsmenu.html");
    NSData* subject = subject_;
    menu_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
            [NSNumber numberWithInt:200], @"status", menu, @"body", nil];
    NSMutableDictionary* menuState = menu_;
    server_ = [[SFTestHTTPServer alloc] initWithHandler:^SFTestHTTPResponse*(SFTestHTTPRequest* request) {
        NSDictionary* type = [NSDictionary dictionaryWithObject:@"text/plain; charset=Shift_JIS"
                                                         forKey:@"Content-Type"];
        if ([[request path] isEqualToString:@"/slow/subject.txt"]) {
            [NSThread sleepForTimeInterval:1.0];
            return [SFTestHTTPResponse responseWithStatus:200 headers:type body:subject];
        } else if ([[request path] isEqualToString:@"/test/subject.txt"]) {
            return [SFTestHTTPResponse responseWithStatus:200 headers:type body:subject];
        } else if ([[request path] isEqualToString:@"/badbyte/subject.txt"]) {
            // 0xFF in the first title, 髙 (an IBM extension) in the second.
            NSMutableData* body = [NSMutableData dataWithData:SFTestShiftJIS(@"1.dat<>A")];
            const unsigned char bad = 0xFF;
            [body appendBytes:&bad length:1];
            [body appendData:SFTestShiftJIS(@"B (2)\n2.dat<>")];
            const unsigned char taka[] = { 0xFB, 0xFC };
            [body appendBytes:taka length:sizeof(taka)];
            [body appendData:SFTestShiftJIS(@"橋さんのスレ (3)\n")];
            return [SFTestHTTPResponse responseWithStatus:200 headers:type body:body];
        } else if ([[request path] isEqualToString:@"/broken/subject.txt"]) {
            return [SFTestHTTPResponse responseWithStatus:200
                                                  headers:type
                                                     body:SFTestShiftJIS(@"1.dat<>レス数なし\nx<>短い (3)\n")];
        } else if ([[request path] isEqualToString:@"/bbsmenu.html"]) {
            NSInteger status;
            NSData* body;
            @synchronized(menuState) {
                status = [[menuState objectForKey:@"status"] integerValue];
                body = [[[menuState objectForKey:@"body"] retain] autorelease];
            }
            return [SFTestHTTPResponse responseWithStatus:(int) status headers:type body:body];
        } else if ([[request path] isEqualToString:@"/slow/bbsmenu.html"]) {
            [NSThread sleepForTimeInterval:1.0];
            return [SFTestHTTPResponse responseWithStatus:200 headers:type body:menu];
        }
        return [SFTestHTTPResponse responseWithStatus:404 headers:nil body:[NSData data]];
    }];
    XCTAssertTrue([server_ start]);
}

- (void)tearDown
{
    [server_ stop];
    [server_ release];
    [subject_ release];
    [menu_ release];
}

- (void)setMenuStatus:(NSInteger)status body:(NSData*)body
{
    @synchronized(menu_) {
        [menu_ setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
        [menu_ setObject:body forKey:@"body"];
    }
}

// Starts -updateWithCompletionHandler: and waits for the handler. Returns its
// error, or a "timed out" error when it wasn't called.
- (NSError*)updateTree:(Ch2BoardTree*)tree
{
    __block BOOL finished = NO;
    __block NSError* result = nil;
    [tree updateWithCompletionHandler:^(NSError* error) {
        finished = YES;
        result = [error retain];
    }];
    // The download runs in the background.
    XCTAssertFalse(finished);
    XCTAssertTrue([tree isUpdating]);
    if (!SFTestWaitFor(10, ^BOOL {
            return finished;
        })) {
        return [NSError errorWithDomain:@"Ch2BoardTests" code:1 userInfo:nil];
    }
    XCTAssertFalse([tree isUpdating]);
    return [result autorelease];
}

// Starts -update and waits for Ch2BoardDidFinishParsingNotification.
- (BOOL)updateBoard:(Ch2Board*)board
{
    __block BOOL finished = NO;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:Ch2BoardDidFinishParsingNotification
                    object:board
                     queue:nil
                usingBlock:^(NSNotification* n) {
                    finished = YES;
                }];
    [board update];
    BOOL result = SFTestWaitFor(10, ^BOOL {
        return finished;
    });
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    return result;
}

- (void)testLoadsSubjectTxt
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"test/"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard:board]);

    XCTAssertEqual([board count], 3u);
    NSDictionary* first = [board subjectAtIndex:0];
    XCTAssertEqualObjects([first objectForKey:@"dat"], [NSNumber numberWithInt:1234567890]);
    XCTAssertEqualObjects([first objectForKey:@"count"], [NSNumber numberWithInt:4]);
    XCTAssertEqualObjects([first objectForKey:@"no"], [NSNumber numberWithInt:1]);
    // The title keeps the space that separated it from "(n)".
    XCTAssertEqualObjects([first objectForKey:@"subject"], @"テストスレ ");

    XCTAssertEqualObjects([[board subjectAtIndex:1] objectForKey:@"count"], [NSNumber numberWithInt:1000]);
    // Parentheses inside the title are kept; the count is the last "(n)".
    NSDictionary* third = [board subjectAtIndex:2];
    XCTAssertEqualObjects([third objectForKey:@"subject"], @"(´・ω・`) 顔文字スレ ");
    XCTAssertEqualObjects([third objectForKey:@"count"], [NSNumber numberWithInt:12]);

    XCTAssertFalse([board isUpdating]);
    XCTAssertEqualObjects([[[[server_ requests] lastObject] header:@"Accept-Encoding"] lowercaseString], @"gzip");
}

- (void)testMalformedLinesDoNotCrash
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"broken/"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard:board]);
    XCTAssertEqual([board count], 2u);
    XCTAssertEqualObjects([[board subjectAtIndex:0] objectForKey:@"subject"], @"レス数なし");
    XCTAssertEqualObjects([[board subjectAtIndex:0] objectForKey:@"count"], [NSNumber numberWithInt:0]);
    XCTAssertEqualObjects([[board subjectAtIndex:1] objectForKey:@"dat"], [NSNumber numberWithInt:0]);
}

- (void)testBadByteKeepsTheOtherSubjects
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"badbyte/"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard:board]);
    XCTAssertEqual([board count], 2u);
    XCTAssertEqualObjects([[board subjectAtIndex:0] objectForKey:@"subject"], @"A\uFFFDB ");
    XCTAssertEqualObjects([[board subjectAtIndex:1] objectForKey:@"subject"], @"髙橋さんのスレ ");
}

- (void)testMissingBoardFinishesWithoutSubjects
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"missing/"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard:board]);
    XCTAssertEqual([board count], 0u);
    // The failed update must not leave the board busy, or it never updates again.
    XCTAssertFalse([board isUpdating]);
}

- (void)testLoadsBoardTree
{
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
            [NSURL URLWithString:@"bbsmenu.html"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertNil([self updateTree:tree]);

    NSArray* categories = [[tree tree] objectForKey:@"children"];
    XCTAssertEqual([categories count], (NSUInteger) 2);

    NSDictionary* test = [categories objectAtIndex:0];
    XCTAssertEqualObjects([test objectForKey:@"title"], @"テスト");
    NSArray* boards = [test objectForKey:@"children"];
    XCTAssertEqual([boards count], (NSUInteger) 2);
    XCTAssertEqualObjects([[boards objectAtIndex:0] objectForKey:@"title"], @"テスト板");
    XCTAssertEqualObjects([[boards objectAtIndex:0] objectForKey:@"url"], @"https://test.example.invalid/test/");
    // Lowercase tags are accepted too.
    XCTAssertEqualObjects([[boards objectAtIndex:1] objectForKey:@"title"], @"砂場");

    NSDictionary* hobby = [categories objectAtIndex:1];
    XCTAssertEqualObjects([hobby objectForKey:@"title"], @"趣味");
    XCTAssertEqual([(NSArray*) [hobby objectForKey:@"children"] count], (NSUInteger) 1);
}

- (void)testUnreachableBoardTreeReportsAnError
{
    // Nothing listens on port 9 of the loopback interface.
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
            [NSURL URLWithString:@"http://127.0.0.1:9/bbsmenu.html"]] autorelease];
    NSError* error = [self updateTree:tree];
    XCTAssertEqualObjects([error domain], NSURLErrorDomain);
    XCTAssertEqual([(NSArray*) [[tree tree] objectForKey:@"children"] count], (NSUInteger) 0);
}

- (void)testFailedBoardTreeUpdateKeepsTheList
{
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
            [NSURL URLWithString:@"bbsmenu.html"
                   relativeToURL:[server_ baseURL]]] autorelease];
    XCTAssertNil([self updateTree:tree]);
    NSArray* before = [[[[tree tree] objectForKey:@"children"] retain] autorelease];
    XCTAssertEqual([before count], (NSUInteger) 2);

    // An HTTP error, and a page with no boards (a login or error page),
    // must not replace the list with an empty one.
    [self setMenuStatus:503 body:SFTestShiftJIS(@"<html>混雑しています</html>")];
    XCTAssertNotNil([self updateTree:tree]);
    XCTAssertEqualObjects([[tree tree] objectForKey:@"children"], before);

    [self setMenuStatus:200 body:SFTestShiftJIS(@"<html><body>メンテナンス中</body></html>\n")];
    XCTAssertNotNil([self updateTree:tree]);
    XCTAssertEqualObjects([[tree tree] objectForKey:@"children"], before);
}

- (void)testCancelledBoardTreeUpdateCallsNothing
{
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
            [NSURL URLWithString:@"slow/bbsmenu.html"
                   relativeToURL:[server_ baseURL]]] autorelease];
    __block BOOL called = NO;
    [tree updateWithCompletionHandler:^(NSError* error) {
        called = YES;
    }];
    [tree cancel];
    XCTAssertFalse([tree isUpdating]);

    // Give the reply time to arrive (the server waits 1 second).
    SFTestWaitFor(2, ^BOOL {
        return called;
    });
    XCTAssertFalse(called);
    XCTAssertEqual([(NSArray*) [[tree tree] objectForKey:@"children"] count], (NSUInteger) 0);
}

- (void)testUnreachableBoardTellsTheDelegate
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"http://127.0.0.1:9/test/"]] autorelease];
    SFTestBoardDelegate* delegate = [[[SFTestBoardDelegate alloc] init] autorelease];
    [board setDelegate:delegate];
    XCTAssertTrue([self updateBoard:board]);
    XCTAssertEqualObjects([delegate->error_ domain], NSURLErrorDomain);
    XCTAssertEqual([board count], 0u);
    XCTAssertFalse([board isUpdating]);
}

- (void)testCancelledBoardUpdatePostsNothing
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
            [NSURL URLWithString:@"slow/"
                   relativeToURL:[server_ baseURL]]] autorelease];
    __block int finished = 0;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:Ch2BoardDidFinishParsingNotification
                    object:board
                     queue:nil
                usingBlock:^(NSNotification* n) {
                    finished++;
                }];

    [board update];
    XCTAssertTrue([board isUpdating]);
    [board cancel];
    XCTAssertFalse([board isUpdating]);

    // Give the reply time to arrive (the server waits 1 second).
    SFTestWaitFor(2, ^BOOL {
        return finished > 0;
    });
    XCTAssertEqual(finished, 0);
    XCTAssertEqual([board count], 0u);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    // The board can be updated again.
    XCTAssertTrue([self updateBoard:board]);
    XCTAssertEqual([board count], 3u);
}

@end
