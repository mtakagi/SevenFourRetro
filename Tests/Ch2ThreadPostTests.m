/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Thread.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

static NSString* const OK_PAGE = @"<html><head><title>書きこみました。</title></head><body>書きこみが終わりました。</body></html>";
static NSString* const ERROR_PAGE = @"<html><head><title>ＥＲＲＯＲ！</title></head><body><ul><br></ul><b>ERROR: テスト用のエラーです<br>もう一度どうぞ</b><form method=POST></form></body></html>";

// Posting against a local bbs.cgi that behaves like 5ch: the first post gets
// a confirmation page that sets a cookie and carries its own form; only that
// form sent back unchanged (action, time, submit, hidden values, cookie and
// Referer) is accepted.
@interface Ch2ThreadPostTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSMutableDictionary* confirmed_; // fields of the last confirmation page
}
@end

@implementation Ch2ThreadPostTests

- (NSData*)confirmationPageFor:(NSDictionary*)form
{
    NSMutableString* page = [NSMutableString stringWithString:
            @"<html><head><title>■ 書き込み確認 ■</title></head><body><!-- 2ch_X:cookie -->"
            @"<b>書き込み＆クッキー確認</b><br>投稿確認<br>この書き込みで本当にいいですか？<br>"];
    // Long notes, as 5ch's terms of posting (#66).
    if (SFTestContains([form objectForKey:@"MESSAGE"], @"LONGTEST")) {
        int i;
        for (i = 1; i <= 20; i++) {
            [page appendFormat:@"・注意書き %d。長い確認のページでも、最後まで読めることを確かめるための文章です。<br>", i];
        }
        [page appendString:@"以上を承諾します。<br>"];
    }
    [page appendString:@"<form method=\"POST\" action=\"../test/bbs.cgi?guid=ON\">"];
    NSArray* names = [NSArray arrayWithObjects:@"FROM", @"mail", @"MESSAGE", @"bbs", @"time", @"key", nil];
    NSEnumerator* enumerator = [names objectEnumerator];
    NSString* name;
    while ((name = [enumerator nextObject]) != nil) {
        NSString* value = [form objectForKey:name];
        [page appendFormat:@"<input type=hidden name=\"%@\" value=\"%@\">\n",
            name, SFTestHTMLEscape(value ? value : @"")];
    }
    [page appendString:@"<input type=hidden name=\"feature\" value=\"確認済み&amp;ok\">\n"];
    [page appendString:@"<input type=submit value=\"上記全てを承諾して書き込む\" name=\"submit\"><br>"];
    [page appendString:@"</form></body></html>"];
    return SFTestShiftJIS(page);
}

- (void)setUp
{
    SFTestClearLocalCookies();
    confirmed_ = [[NSMutableDictionary alloc] init];

    server_ = [[SFTestHTTPServer alloc] initWithHandler:^SFTestHTTPResponse*(SFTestHTTPRequest* request) {
        NSDictionary* html = [NSDictionary dictionaryWithObject:@"text/html; charset=Shift_JIS" forKey:@"Content-Type"];
        NSDictionary* form = [request formFields];
        if (SFTestContains([form objectForKey:@"MESSAGE"], @"ERRORTEST")) {
            return [SFTestHTTPResponse responseWithStatus:200 headers:html body:SFTestShiftJIS(ERROR_PAGE)];
        }
        if (SFTestContains([form objectForKey:@"MESSAGE"], @"SLOWTEST")) {
            [NSThread sleepForTimeInterval:1.0];
            return [SFTestHTTPResponse responseWithStatus:200
                                                  headers:html
                                                     body:SFTestShiftJIS(@"<html><!-- 2ch_X:true --><body>ok</body></html>")];
        }
        if (SFTestContains([form objectForKey:@"MESSAGE"], @"LOSTTEST")) {
            // The post arrived, but the reply breaks off: the client can't
            // tell whether it was written.
            NSData* page = SFTestShiftJIS(OK_PAGE);
            NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:html];
            [headers setObject:[NSString stringWithFormat:@"%lu", (unsigned long) [page length] * 2]
                        forKey:@"Content-Length"];
            return [SFTestHTTPResponse responseWithStatus:200 headers:headers body:page];
        }
        if (SFTestContains([form objectForKey:@"MESSAGE"], @"COMMENTTEST")) {
            return [SFTestHTTPResponse responseWithStatus:200
                                                  headers:html
                                                     body:SFTestShiftJIS(@"<html><!-- 2ch_X:true --><body>ok</body></html>")];
        }

        NSString* cookie = [request header:@"Cookie"];
        BOOL accepted;
        @synchronized(confirmed_) {
            accepted = [[request path] hasSuffix:@"bbs.cgi?guid=ON"]
                && SFTestContains(cookie, @"MID=confirmed")
                && [[form objectForKey:@"feature"] isEqualToString:@"確認済み&ok"]
                && [[form objectForKey:@"submit"] isEqualToString:@"上記全てを承諾して書き込む"]
                && [[form objectForKey:@"time"] isEqualToString:[confirmed_ objectForKey:@"time"]]
                && [[form objectForKey:@"MESSAGE"] isEqualToString:[confirmed_ objectForKey:@"MESSAGE"]]
                && [[form objectForKey:@"FROM"] isEqualToString:[confirmed_ objectForKey:@"FROM"]]
                && [[request header:@"Referer"] hasSuffix:@"/test/bbs.cgi"];
            if (!accepted) {
                [confirmed_ setDictionary:form];
            }
        }
        if (accepted) {
            return [SFTestHTTPResponse responseWithStatus:200 headers:html body:SFTestShiftJIS(OK_PAGE)];
        }
        NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:html];
        [headers setObject:@"MID=confirmed; path=/" forKey:@"Set-Cookie"];
        return [SFTestHTTPResponse responseWithStatus:200 headers:headers body:[self confirmationPageFor:form]];
    }];
    XCTAssertTrue([server_ start]);
}

- (void)tearDown
{
    [server_ stop];
    [server_ release];
    [confirmed_ release];
    SFTestClearLocalCookies();
}

- (Ch2Thread*)thread
{
    NSURL* board = [[NSURL URLWithString:@"test/" relativeToURL:[server_ baseURL]] absoluteURL];
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber:1234567890 board:board] autorelease];
    [thread setUserAgent:@"Monazilla/1.00 (SevenFourTests)"];
    return thread;
}

// Sends a post and waits for its result, which must arrive on the main thread.
- (Ch2ThreadPostResult)post:(Ch2Thread*)thread
                       name:(NSString*)name
                       mail:(NSString*)mail
                       body:(NSString*)body
{
    __block BOOL finished = NO;
    __block Ch2ThreadPostResult result = Ch2ThreadPostClientError;
    BOOL started = [thread postWithName:name
                                   mail:mail
                                   body:body
                      completionHandler:^(Ch2ThreadPostResult r) {
                          XCTAssertTrue([NSThread isMainThread]);
                          result = r;
                          finished = YES;
                      }];
    XCTAssertTrue(started);
    // Sending runs in the background.
    XCTAssertFalse(finished);
    XCTAssertTrue([thread isPosting]);
    XCTAssertTrue(SFTestWaitFor(10, ^BOOL {
        return finished;
    }));
    XCTAssertFalse([thread isPosting]);
    return result;
}

- (NSUInteger)postCount
{
    NSUInteger n = 0;
    NSEnumerator* e = [[server_ requests] objectEnumerator];
    SFTestHTTPRequest* r;
    while ((r = [e nextObject]) != nil) {
        if ([[r method] isEqualToString:@"POST"]) {
            n++;
        }
    }
    return n;
}

- (NSDictionary*)lastForm
{
    return [[[server_ requests] lastObject] formFields];
}

- (void)testFirstPostSendsTheForm
{
    Ch2Thread* thread = [self thread];
    Ch2ThreadPostResult result = [self post:thread name:@"名無し" mail:@"sage" body:@"本文です"];
    XCTAssertEqual(result, Ch2ThreadPostCheckCookie);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request method], @"POST");
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi");
    XCTAssertEqualObjects([request header:@"Content-Type"], @"application/x-www-form-urlencoded");
    XCTAssertEqualObjects([request header:@"User-Agent"], @"Monazilla/1.00 (SevenFourTests)");

    NSDictionary* form = [request formFields];
    XCTAssertEqualObjects([form objectForKey:@"bbs"], @"test");
    XCTAssertEqualObjects([form objectForKey:@"key"], @"1234567890");
    XCTAssertEqualObjects([form objectForKey:@"FROM"], @"名無し");
    XCTAssertEqualObjects([form objectForKey:@"mail"], @"sage");
    XCTAssertEqualObjects([form objectForKey:@"MESSAGE"], @"本文です");
    XCTAssertEqualObjects([form objectForKey:@"submit"], @"書き込む");
    // time is the current Unix time.
    long long time = [[form objectForKey:@"time"] longLongValue];
    XCTAssertTrue(llabs(time - (long long) [[NSDate date] timeIntervalSince1970]) < 60);

    // The confirmation text is shown to the user.
    XCTAssertTrue(SFTestContains([thread alertMessage], @"この書き込みで本当にいいですか？"));
}

- (void)testConfirmationFormIsSentBackUnchanged
{
    Ch2Thread* thread = [self thread];
    NSString* body = @"it's \"q\" <b> & 😀 (´・ω・`)\n2 行目";
    XCTAssertEqual([self post:thread name:@"名無し" mail:@"sage" body:body], Ch2ThreadPostCheckCookie);
    NSDictionary* first = [self lastForm];

    // OK in the confirmation dialog: the same post again.
    XCTAssertEqual([self post:thread name:@"名無し" mail:@"sage" body:body], Ch2ThreadPostSuccess);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi?guid=ON");
    XCTAssertTrue([[request header:@"Referer"] hasSuffix:@"/test/bbs.cgi"]);
    XCTAssertTrue(SFTestContains([request header:@"Cookie"], @"MID=confirmed"));
    NSDictionary* second = [request formFields];
    XCTAssertEqualObjects([second objectForKey:@"time"], [first objectForKey:@"time"]);
    XCTAssertEqualObjects([second objectForKey:@"submit"], @"上記全てを承諾して書き込む");
    // The emoji can't be written in Shift_JIS, so it travels as &#128512;.
    XCTAssertEqualObjects([second objectForKey:@"MESSAGE"],
        @"it's \"q\" <b> & &#128512; (´・ω・`)\n2 行目");
    XCTAssertEqualObjects([second objectForKey:@"MESSAGE"], [first objectForKey:@"MESSAGE"]);
}

// After a post went through its confirmation page, the next post to the
// thread sends only the fields of the thread page's form, as a browser would:
// none of the confirmation page's hidden fields, such as its feature (#65).
- (void)testNextPostSendsOnlyTheThreadForm
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"" mail:@"sage" body:@"一つ目"], Ch2ThreadPostCheckCookie);
    XCTAssertEqual([self post:thread name:@"" mail:@"sage" body:@"一つ目"], Ch2ThreadPostSuccess);

    XCTAssertEqual([self post:thread name:@"" mail:@"sage" body:@"二つ目"], Ch2ThreadPostCheckCookie);
    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi");
    NSDictionary* form = [request formFields];
    NSArray* names = [[form allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSArray* expected = [[NSArray arrayWithObjects:@"FROM", @"MESSAGE", @"bbs", @"key", @"mail", @"submit", @"time", nil]
        sortedArrayUsingSelector:@selector(compare:)];
    XCTAssertEqualObjects(names, expected);
    XCTAssertEqualObjects([form objectForKey:@"MESSAGE"], @"二つ目");

    // And its own confirmation page goes through too.
    XCTAssertEqual([self post:thread name:@"" mail:@"sage" body:@"二つ目"], Ch2ThreadPostSuccess);
    XCTAssertEqualObjects([[self lastForm] objectForKey:@"MESSAGE"], @"二つ目");
    XCTAssertEqual([self postCount], 4u);
}

// A long confirmation page is shown whole: 5ch's, with its terms of
// posting, is longer than the 500 characters it was once cut to (#66).
- (void)testLongConfirmationIsKeptWhole
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"LONGTEST"], Ch2ThreadPostCheckCookie);
    NSString* message = [thread alertMessage];
    XCTAssertTrue([message length] > 500);
    XCTAssertTrue([message hasSuffix:@"以上を承諾します。"]);
    XCTAssertTrue(SFTestContains(message, @"・注意書き 20。"));
}

- (void)testEditedPostIsBuiltAgain
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"名無し" mail:@"sage" body:@"最初の本文"], Ch2ThreadPostCheckCookie);

    // Cancel in the dialog, edit the text and post: not the old form.
    [self post:thread name:@"名無し" mail:@"sage" body:@"直した本文"];
    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi");
    XCTAssertEqualObjects([[request formFields] objectForKey:@"MESSAGE"], @"直した本文");
    XCTAssertEqualObjects([[request formFields] objectForKey:@"submit"], @"書き込む");
}

- (void)testErrorPageShowsItsMessage
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"ERRORTEST"], Ch2ThreadPostError);
    XCTAssertEqualObjects([thread alertMessage], @"ERROR: テスト用のエラーです\nもう一度どうぞ");
}

- (void)testResultCommentMeansSuccess
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"COMMENTTEST"], Ch2ThreadPostSuccess);
}

- (void)testUnreachableServerReportsTheError
{
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber:1
                                                     board:[NSURL URLWithString:@"http://127.0.0.1:9/test/"]] autorelease];
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"本文"], Ch2ThreadPostClientError);
    XCTAssertTrue([[thread alertMessage] length] > 0);
}

- (void)testSecondPostWhileSendingIsRefused
{
    // The button pressed twice, or two windows for the same thread.
    Ch2Thread* thread = [self thread];
    __block int finished = 0;
    XCTAssertTrue([thread postWithName:@""
                                  mail:@""
                                  body:@"SLOWTEST"
                     completionHandler:^(Ch2ThreadPostResult r) {
                         finished++;
                     }]);
    XCTAssertFalse([thread postWithName:@""
                                   mail:@""
                                   body:@"SLOWTEST"
                      completionHandler:^(Ch2ThreadPostResult r) {
                          finished += 100;
                      }]);
    XCTAssertTrue(SFTestWaitFor(10, ^BOOL {
        return finished > 0;
    }));
    SFTestWaitFor(0.5, ^BOOL {
        return finished > 1;
    });
    XCTAssertEqual(finished, 1);
    XCTAssertEqual([self postCount], (NSUInteger) 1);

    // Once the first is done, the next post goes out.
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"COMMENTTEST"], Ch2ThreadPostSuccess);
    XCTAssertEqual([self postCount], (NSUInteger) 2);
}

- (void)testLostReplyIsUnknownAndNotSentAgain
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([self post:thread name:@"" mail:@"" body:@"LOSTTEST"], Ch2ThreadPostUnknown);
    XCTAssertTrue([[thread alertMessage] length] > 0);
    // Give a hidden retry time to show up: the post went out once.
    SFTestWaitFor(1, ^BOOL {
        return [self postCount] > 1;
    });
    XCTAssertEqual([self postCount], (NSUInteger) 1);
}

- (void)testURLencodeUsesShiftJIS
{
    XCTAssertEqualObjects([@"書き込む" URLencode], @"%8f%91%82%ab%8d%9e%82%de");
    XCTAssertEqualObjects([@"a b&c=d" URLencode], @"a+b%26c%3dd");
    // A character Shift_JIS can't hold is sent as a numeric reference
    // instead of emptying the whole value.
    XCTAssertEqualObjects([@"x😀" URLencode], @"x%26%23128512%3b");
}

@end
