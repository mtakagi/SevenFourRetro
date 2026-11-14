/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2Anchor.h"

// Anchors in a message's body become links to the messages (#70).
@interface Ch2AnchorTests : XCTestCase
@end

@implementation Ch2AnchorTests

- (void)testHalfWidthAnchor
{
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;12 そうだね"),
        @"<a href='#12'>&gt;&gt;12</a> そうだね");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;5"), @"<a href='#5'>&gt;5</a>");
}

- (void)testRangesAndLists
{
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;1-5"), @"<a href='#1-5'>&gt;&gt;1-5</a>");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;1,3,7"), @"<a href='#1,3,7'>&gt;&gt;1,3,7</a>");
    // A trailing comma isn't part of the anchor.
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;1, 2"), @"<a href='#1'>&gt;&gt;1</a>, 2");
}

// "＞＞790", as written with the full-width ＞ (#70).
- (void)testFullWidthMarks
{
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"＞＞790"), @"<a href='#790'>＞＞790</a>");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"≫12"), @"<a href='#12'>≫12</a>");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;＞3"), @"<a href='#3'>&gt;＞3</a>");
}

// Full-width numbers link to their half-width form; the text is as written.
- (void)testFullWidthNumbers
{
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"＞＞７９０"), @"<a href='#790'>＞＞７９０</a>");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"＞＞１－３"), @"<a href='#1-3'>＞＞１－３</a>");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;１，２"), @"<a href='#1,2'>&gt;&gt;１，２</a>");
}

- (void)testSeveralAnchorsAndPlainText
{
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"&gt;&gt;1 と ＞＞2<br>ok"),
        @"<a href='#1'>&gt;&gt;1</a> と <a href='#2'>＞＞2</a><br>ok");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@"anchors: none &gt; here"), @"anchors: none &gt; here");
    XCTAssertEqualObjects(Ch2MarkupAnchors(@""), @"");
}

@end
