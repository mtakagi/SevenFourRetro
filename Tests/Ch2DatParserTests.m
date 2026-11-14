/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2DatParser.h"
#import "SFTestSupport.h"

@interface Ch2DatParserTests : XCTestCase
@end

@implementation Ch2DatParserTests

- (void)testParsesSyntheticThread
{
    NSArray* messages = [Ch2DatParser parseData:SFTestFixtureShiftJIS(@"thread.dat")];
    XCTAssertEqual([messages count], (NSUInteger) 4);

    NSDictionary* first = [messages objectAtIndex:0];
    XCTAssertEqualObjects([first objectForKey:Ch2MessageName], @"名無しさん");
    XCTAssertEqualObjects([first objectForKey:Ch2MessageMail], @"sage");
    XCTAssertEqualObjects([first objectForKey:Ch2MessageTime], @"2026/11/08(日) 00:00:00.00");
    XCTAssertEqualObjects([first objectForKey:Ch2MessageID], @"abcd1234");
    XCTAssertEqualObjects([first objectForKey:Ch2MessageBody], @" 1 つめのレスです ");
    XCTAssertEqualObjects([first objectForKey:Ch2MessageThreadSubject], @"テストスレ");
}

- (void)testParsesIDAndBE
{
    NSDictionary* second = [[Ch2DatParser parseData:SFTestFixtureShiftJIS(@"thread.dat")] objectAtIndex:1];
    XCTAssertEqualObjects([second objectForKey:Ch2MessageMail], @"");
    XCTAssertEqualObjects([second objectForKey:Ch2MessageID], @"efgh5678");
    XCTAssertEqualObjects([second objectForKey:Ch2MessageBe], @"12345-2BP(1000)");
    XCTAssertEqualObjects([second objectForKey:Ch2MessageBody], @" 2 つめ<br>改行あり ");
    // Only the first line carries the thread title.
    XCTAssertNil([second objectForKey:Ch2MessageThreadSubject]);
}

- (void)testKeepsHTMLInBodyAndTimeWithoutID
{
    NSArray* messages = [Ch2DatParser parseData:SFTestFixtureShiftJIS(@"thread.dat")];
    // Bodies stay as the server sent them; the formatter renders the HTML.
    XCTAssertEqualObjects([[messages objectAtIndex:2] objectForKey:Ch2MessageBody], @" &gt;&gt;1 &amp; 記号 ");

    NSDictionary* fourth = [messages objectAtIndex:3];
    XCTAssertEqualObjects([fourth objectForKey:Ch2MessageTime], @"2026/11/08(日) 00:00:03.00");
    XCTAssertNil([fourth objectForKey:Ch2MessageID]);
}

- (void)testLineWithoutSubjectFieldDoesNotCrash
{
    // Four fields, without the trailing "<>" that holds the thread title.
    NSArray* messages = [Ch2DatParser parseData:SFTestShiftJIS(@"名無し<>sage<>2026/11/08<> 本文 \n")];
    XCTAssertEqual([messages count], (NSUInteger) 1);
    XCTAssertEqualObjects([[messages objectAtIndex:0] objectForKey:Ch2MessageBody], @" 本文 ");
    XCTAssertNil([[messages objectAtIndex:0] objectForKey:Ch2MessageThreadSubject]);
}

- (void)testBrokenLineFailsTheWholeParse
{
    // Current behavior: a line with fewer than four fields (e.g. a response
    // cut off mid-line) makes the whole parse fail, and the caller keeps its
    // cache. Partial responses are revisited in #25.
    NSData* data = SFTestShiftJIS(@"名無し<>sage<>2026/11/08<> 本文 <>スレ\n名無し<>sa");
    XCTAssertNil([Ch2DatParser parseData:data]);
}

- (void)testEmptyDataHasNoMessages
{
    XCTAssertEqual([[Ch2DatParser parseData:[NSData data]] count], (NSUInteger) 0);
}

- (void)testBadByteInABodyKeepsTheThread
{
    // 名無し<>sage<>time<> 髙 X <>title  with 0xFF in place of X, then a
    // second line. Before #31 a 髙 (IBM extension) was lost; a bad byte
    // must not lose the thread.
    NSMutableData* data = [NSMutableData data];
    [data appendData:[@"N<>sage<>T<> " dataUsingEncoding:NSASCIIStringEncoding]];
    const unsigned char taka[] = { 0xFB, 0xFC, 0x20, 0xFF, 0x20 };
    [data appendBytes:taka length:sizeof(taka)];
    [data appendData:[@"<>S\nN<><>T<> 2 <>\n" dataUsingEncoding:NSASCIIStringEncoding]];

    NSArray* messages = [Ch2DatParser parseData:data];
    XCTAssertEqual([messages count], (NSUInteger) 2);
    XCTAssertEqualObjects([[messages objectAtIndex:0] objectForKey:Ch2MessageBody], @" 髙 \uFFFD ");
    XCTAssertEqualObjects([[messages objectAtIndex:1] objectForKey:Ch2MessageBody], @" 2 ");
}

@end
