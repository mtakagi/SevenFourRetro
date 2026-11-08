/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Board.h"
#import "Ch2BoardTree.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

@interface Ch2BoardTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSData* subject_;
}
@end

@implementation Ch2BoardTests

- (void) setUp
{
    subject_ = [SFTestFixtureShiftJIS(@"subject.txt") retain];
    NSData* menu = SFTestFixtureShiftJIS(@"bbsmenu.html");
    NSData* subject = subject_;
    server_ = [[SFTestHTTPServer alloc] initWithHandler: ^SFTestHTTPResponse* (SFTestHTTPRequest* request) {
        NSDictionary* type = [NSDictionary dictionaryWithObject: @"text/plain; charset=Shift_JIS"
                                                         forKey: @"Content-Type"];
        if ([[request path] isEqualToString: @"/test/subject.txt"]) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: type body: subject];
        } else if ([[request path] isEqualToString: @"/broken/subject.txt"]) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: type
                                                     body: SFTestShiftJIS(@"1.dat<>レス数なし\nx<>短い (3)\n")];
        } else if ([[request path] isEqualToString: @"/bbsmenu.html"]) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: type body: menu];
        }
        return [SFTestHTTPResponse responseWithStatus: 404 headers: nil body: [NSData data]];
    }];
    XCTAssertTrue([server_ start]);
}

- (void) tearDown
{
    [server_ stop];
    [server_ release];
    [subject_ release];
}

// Starts -update and waits for Ch2BoardDidFinishParsingNotification.
- (BOOL) updateBoard: (Ch2Board*) board
{
    __block BOOL finished = NO;
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName: Ch2BoardDidFinishParsingNotification
                    object: board
                     queue: nil
                usingBlock: ^(NSNotification* n) { finished = YES; }];
    [board update];
    BOOL result = SFTestWaitFor(10, ^BOOL { return finished; });
    [[NSNotificationCenter defaultCenter] removeObserver: observer];
    return result;
}

- (void) testLoadsSubjectTxt
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
        [NSURL URLWithString: @"test/" relativeToURL: [server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard: board]);

    XCTAssertEqual([board count], 3u);
    NSDictionary* first = [board subjectAtIndex: 0];
    XCTAssertEqualObjects([first objectForKey: @"dat"], [NSNumber numberWithInt: 1234567890]);
    XCTAssertEqualObjects([first objectForKey: @"count"], [NSNumber numberWithInt: 4]);
    XCTAssertEqualObjects([first objectForKey: @"no"], [NSNumber numberWithInt: 1]);
    // The title keeps the space that separated it from "(n)".
    XCTAssertEqualObjects([first objectForKey: @"subject"], @"テストスレ ");

    XCTAssertEqualObjects([[board subjectAtIndex: 1] objectForKey: @"count"], [NSNumber numberWithInt: 1000]);
    // Parentheses inside the title are kept; the count is the last "(n)".
    NSDictionary* third = [board subjectAtIndex: 2];
    XCTAssertEqualObjects([third objectForKey: @"subject"], @"(´・ω・`) 顔文字スレ ");
    XCTAssertEqualObjects([third objectForKey: @"count"], [NSNumber numberWithInt: 12]);

    XCTAssertFalse([board isUpdating]);
    XCTAssertEqualObjects([[[[server_ requests] lastObject] header: @"Accept-Encoding"] lowercaseString], @"gzip");
}

- (void) testMalformedLinesDoNotCrash
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
        [NSURL URLWithString: @"broken/" relativeToURL: [server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard: board]);
    XCTAssertEqual([board count], 2u);
    XCTAssertEqualObjects([[board subjectAtIndex: 0] objectForKey: @"subject"], @"レス数なし");
    XCTAssertEqualObjects([[board subjectAtIndex: 0] objectForKey: @"count"], [NSNumber numberWithInt: 0]);
    XCTAssertEqualObjects([[board subjectAtIndex: 1] objectForKey: @"dat"], [NSNumber numberWithInt: 0]);
}

- (void) testMissingBoardFinishesWithoutSubjects
{
    Ch2Board* board = [[[Ch2Board alloc] initWithURL:
        [NSURL URLWithString: @"missing/" relativeToURL: [server_ baseURL]]] autorelease];
    XCTAssertTrue([self updateBoard: board]);
    XCTAssertEqual([board count], 0u);
    // The failed update must not leave the board busy, or it never updates again.
    XCTAssertFalse([board isUpdating]);
}

- (void) testLoadsBoardTree
{
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
        [NSURL URLWithString: @"bbsmenu.html" relativeToURL: [server_ baseURL]]] autorelease];
    [tree update];

    NSArray* categories = [[tree tree] objectForKey: @"children"];
    XCTAssertEqual([categories count], (NSUInteger) 2);

    NSDictionary* test = [categories objectAtIndex: 0];
    XCTAssertEqualObjects([test objectForKey: @"title"], @"テスト");
    NSArray* boards = [test objectForKey: @"children"];
    XCTAssertEqual([boards count], (NSUInteger) 2);
    XCTAssertEqualObjects([[boards objectAtIndex: 0] objectForKey: @"title"], @"テスト板");
    XCTAssertEqualObjects([[boards objectAtIndex: 0] objectForKey: @"url"], @"https://test.example.invalid/test/");
    // Lowercase tags are accepted too.
    XCTAssertEqualObjects([[boards objectAtIndex: 1] objectForKey: @"title"], @"砂場");

    NSDictionary* hobby = [categories objectAtIndex: 1];
    XCTAssertEqualObjects([hobby objectForKey: @"title"], @"趣味");
    XCTAssertEqual([[hobby objectForKey: @"children"] count], (NSUInteger) 1);
}

- (void) testUnreachableBoardTreeIsEmpty
{
    // Nothing listens on port 9 of the loopback interface.
    Ch2BoardTree* tree = [[[Ch2BoardTree alloc] initWithURL:
        [NSURL URLWithString: @"http://127.0.0.1:9/bbsmenu.html"]] autorelease];
    [tree update];
    XCTAssertEqual([[[tree tree] objectForKey: @"children"] count], (NSUInteger) 0);
}

@end
