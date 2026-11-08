/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Thread.h"
#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

static NSString* const OK_PAGE =
    @"<html><head><title>書きこみました。</title></head><body>書きこみが終わりました。</body></html>";
static NSString* const ERROR_PAGE =
    @"<html><head><title>ＥＲＲＯＲ！</title></head><body><ul><br></ul><b>ERROR: テスト用のエラーです<br>もう一度どうぞ</b><form method=POST></form></body></html>";

// Posting against a local bbs.cgi that behaves like 5ch: the first post gets
// a confirmation page that sets a cookie and carries its own form; only that
// form sent back unchanged (action, time, submit, hidden values, cookie and
// Referer) is accepted.
@interface Ch2ThreadPostTests : XCTestCase {
    SFTestHTTPServer* server_;
    NSMutableDictionary* confirmed_;   // fields of the last confirmation page
}
@end

@implementation Ch2ThreadPostTests

- (NSData*) confirmationPageFor: (NSDictionary*) form
{
    NSMutableString* page = [NSMutableString stringWithString:
        @"<html><head><title>■ 書き込み確認 ■</title></head><body><!-- 2ch_X:cookie -->"
        @"<b>書き込み＆クッキー確認</b><br>投稿確認<br>この書き込みで本当にいいですか？<br>"
        @"<form method=\"POST\" action=\"../test/bbs.cgi?guid=ON\">"];
    NSArray* names = [NSArray arrayWithObjects: @"FROM", @"mail", @"MESSAGE", @"bbs", @"time", @"key", nil];
    NSEnumerator* enumerator = [names objectEnumerator];
    NSString* name;
    while ((name = [enumerator nextObject]) != nil) {
        NSString* value = [form objectForKey: name];
        [page appendFormat: @"<input type=hidden name=\"%@\" value=\"%@\">\n",
            name, SFTestHTMLEscape(value ? value : @"")];
    }
    [page appendString: @"<input type=hidden name=\"feature\" value=\"確認済み&amp;ok\">\n"];
    [page appendString: @"<input type=submit value=\"上記全てを承諾して書き込む\" name=\"submit\"><br>"];
    [page appendString: @"</form></body></html>"];
    return SFTestShiftJIS(page);
}

- (void) setUp
{
    SFTestClearLocalCookies();
    [Ch2Thread forgetConfirmationFormData];
    confirmed_ = [[NSMutableDictionary alloc] init];

    server_ = [[SFTestHTTPServer alloc] initWithHandler: ^SFTestHTTPResponse* (SFTestHTTPRequest* request) {
        NSDictionary* html = [NSDictionary dictionaryWithObject: @"text/html; charset=Shift_JIS" forKey: @"Content-Type"];
        NSDictionary* form = [request formFields];
        if ([[form objectForKey: @"MESSAGE"] rangeOfString: @"ERRORTEST"].location != NSNotFound) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: html body: SFTestShiftJIS(ERROR_PAGE)];
        }
        if ([[form objectForKey: @"MESSAGE"] rangeOfString: @"COMMENTTEST"].location != NSNotFound) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: html
                                                     body: SFTestShiftJIS(@"<html><!-- 2ch_X:true --><body>ok</body></html>")];
        }

        NSString* cookie = [request header: @"Cookie"];
        BOOL accepted;
        @synchronized (confirmed_) {
            accepted = [[request path] hasSuffix: @"bbs.cgi?guid=ON"]
                && [cookie rangeOfString: @"MID=confirmed"].location != NSNotFound
                && [[form objectForKey: @"feature"] isEqualToString: @"確認済み&ok"]
                && [[form objectForKey: @"submit"] isEqualToString: @"上記全てを承諾して書き込む"]
                && [[form objectForKey: @"time"] isEqualToString: [confirmed_ objectForKey: @"time"]]
                && [[form objectForKey: @"MESSAGE"] isEqualToString: [confirmed_ objectForKey: @"MESSAGE"]]
                && [[form objectForKey: @"FROM"] isEqualToString: [confirmed_ objectForKey: @"FROM"]]
                && [[request header: @"Referer"] hasSuffix: @"/test/bbs.cgi"];
            if (! accepted) {
                [confirmed_ setDictionary: form];
            }
        }
        if (accepted) {
            return [SFTestHTTPResponse responseWithStatus: 200 headers: html body: SFTestShiftJIS(OK_PAGE)];
        }
        NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary: html];
        [headers setObject: @"MID=confirmed; path=/" forKey: @"Set-Cookie"];
        return [SFTestHTTPResponse responseWithStatus: 200 headers: headers body: [self confirmationPageFor: form]];
    }];
    XCTAssertTrue([server_ start]);
}

- (void) tearDown
{
    [server_ stop];
    [server_ release];
    [confirmed_ release];
    SFTestClearLocalCookies();
    [Ch2Thread forgetConfirmationFormData];
}

- (Ch2Thread*) thread
{
    NSURL* board = [[NSURL URLWithString: @"test/" relativeToURL: [server_ baseURL]] absoluteURL];
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber: 1234567890 board: board] autorelease];
    [thread setUserAgent: @"Monazilla/1.00 (SevenFourTests)"];
    return thread;
}

- (NSDictionary*) lastForm
{
    return [[[server_ requests] lastObject] formFields];
}

- (void) testFirstPostSendsTheForm
{
    Ch2Thread* thread = [self thread];
    Ch2ThreadPostResult result = [thread postWithName: @"名無し" mail: @"sage" body: @"本文です"];
    XCTAssertEqual(result, Ch2ThreadPostCheckCookie);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request method], @"POST");
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi");
    XCTAssertEqualObjects([request header: @"Content-Type"], @"application/x-www-form-urlencoded");
    XCTAssertEqualObjects([request header: @"User-Agent"], @"Monazilla/1.00 (SevenFourTests)");

    NSDictionary* form = [request formFields];
    XCTAssertEqualObjects([form objectForKey: @"bbs"], @"test");
    XCTAssertEqualObjects([form objectForKey: @"key"], @"1234567890");
    XCTAssertEqualObjects([form objectForKey: @"FROM"], @"名無し");
    XCTAssertEqualObjects([form objectForKey: @"mail"], @"sage");
    XCTAssertEqualObjects([form objectForKey: @"MESSAGE"], @"本文です");
    XCTAssertEqualObjects([form objectForKey: @"submit"], @"書き込む");
    // time is the current Unix time.
    long long time = [[form objectForKey: @"time"] longLongValue];
    XCTAssertTrue(llabs(time - (long long) [[NSDate date] timeIntervalSince1970]) < 60);

    // The confirmation text is shown to the user.
    XCTAssertTrue([[thread alertMessage] rangeOfString: @"この書き込みで本当にいいですか？"].location != NSNotFound);
}

- (void) testConfirmationFormIsSentBackUnchanged
{
    Ch2Thread* thread = [self thread];
    NSString* body = @"it's \"q\" <b> & 😀 (´・ω・`)\n2 行目";
    XCTAssertEqual([thread postWithName: @"名無し" mail: @"sage" body: body], Ch2ThreadPostCheckCookie);
    NSDictionary* first = [self lastForm];

    // OK in the confirmation dialog: the same post again.
    XCTAssertEqual([thread postWithName: @"名無し" mail: @"sage" body: body], Ch2ThreadPostSuccess);

    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi?guid=ON");
    XCTAssertTrue([[request header: @"Referer"] hasSuffix: @"/test/bbs.cgi"]);
    XCTAssertTrue([[request header: @"Cookie"] rangeOfString: @"MID=confirmed"].location != NSNotFound);
    NSDictionary* second = [request formFields];
    XCTAssertEqualObjects([second objectForKey: @"time"], [first objectForKey: @"time"]);
    XCTAssertEqualObjects([second objectForKey: @"submit"], @"上記全てを承諾して書き込む");
    // The emoji can't be written in Shift_JIS, so it travels as &#128512;.
    XCTAssertEqualObjects([second objectForKey: @"MESSAGE"],
                          @"it's \"q\" <b> & &#128512; (´・ω・`)\n2 行目");
    XCTAssertEqualObjects([second objectForKey: @"MESSAGE"], [first objectForKey: @"MESSAGE"]);
}

- (void) testEditedPostIsBuiltAgain
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([thread postWithName: @"名無し" mail: @"sage" body: @"最初の本文"], Ch2ThreadPostCheckCookie);

    // Cancel in the dialog, edit the text and post: not the old form.
    [thread postWithName: @"名無し" mail: @"sage" body: @"直した本文"];
    SFTestHTTPRequest* request = [[server_ requests] lastObject];
    XCTAssertEqualObjects([request path], @"/test/bbs.cgi");
    XCTAssertEqualObjects([[request formFields] objectForKey: @"MESSAGE"], @"直した本文");
    XCTAssertEqualObjects([[request formFields] objectForKey: @"submit"], @"書き込む");
}

- (void) testErrorPageShowsItsMessage
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([thread postWithName: @"" mail: @"" body: @"ERRORTEST"], Ch2ThreadPostError);
    XCTAssertEqualObjects([thread alertMessage], @"ERROR: テスト用のエラーです\nもう一度どうぞ");
}

- (void) testResultCommentMeansSuccess
{
    Ch2Thread* thread = [self thread];
    XCTAssertEqual([thread postWithName: @"" mail: @"" body: @"COMMENTTEST"], Ch2ThreadPostSuccess);
}

- (void) testUnreachableServerReportsTheError
{
    Ch2Thread* thread = [[[Ch2Thread alloc] initWithNumber: 1
                                                     board: [NSURL URLWithString: @"http://127.0.0.1:9/test/"]] autorelease];
    XCTAssertEqual([thread postWithName: @"" mail: @"" body: @"本文"], Ch2ThreadPostClientError);
    XCTAssertTrue([[thread alertMessage] length] > 0);
}

- (void) testURLencodeUsesShiftJIS
{
    XCTAssertEqualObjects([@"書き込む" URLencode], @"%8f%91%82%ab%8d%9e%82%de");
    XCTAssertEqualObjects([@"a b&c=d" URLencode], @"a+b%26c%3dd");
    // A character Shift_JIS can't hold is sent as a numeric reference
    // instead of emptying the whole value.
    XCTAssertEqualObjects([@"x😀" URLencode], @"x%26%23128512%3b");
}

@end
