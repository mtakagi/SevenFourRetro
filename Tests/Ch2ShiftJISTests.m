/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "Ch2ShiftJIS.h"

// Bytes written as hex, e.g. "82a0".
static NSData* bytes(NSString* hex)
{
    NSMutableData* d = [NSMutableData data];
    NSUInteger i;
    for (i = 0; i + 1 < [hex length]; i += 2) {
        unsigned v = 0;
        [[NSScanner scannerWithString: [hex substringWithRange: NSMakeRange(i, 2)]] scanHexInt: &v];
        unsigned char b = (unsigned char) v;
        [d appendBytes: &b length: 1];
    }
    return d;
}

// Characters written as code points, e.g. @[@0x3042].
static NSString* chars(NSArray* codes)
{
    NSMutableString* s = [NSMutableString string];
    NSEnumerator* e = [codes objectEnumerator];
    NSNumber* n;
    while ((n = [e nextObject]) != nil) {
        unichar c = (unichar) [n unsignedShortValue];
        [s appendString: [NSString stringWithCharacters: &c length: 1]];
    }
    return s;
}

// The decoding that replaced TEC (#31). Where TEC decoded differently, the
// comment says how; everything else is what TEC did too.
@interface Ch2ShiftJISTests : XCTestCase
@end

@implementation Ch2ShiftJISTests

- (void) assertBytes: (NSString*) hex decodeTo: (NSString*) expected
{
    XCTAssertEqualObjects(Ch2StringFromShiftJIS(bytes(hex)), expected, @"%@", hex);
}

- (void) testPlainText
{
    [self assertBytes: @"" decodeTo: @""];
    [self assertBytes: @"414243" decodeTo: @"ABC"];
    [self assertBytes: @"82a082a282a4" decodeTo: @"あいう"];
    // 0x5C and 0x7E stay a backslash and a tilde, as on Windows and 5ch.
    [self assertBytes: @"5c7e" decodeTo: @"\\~"];
    [self assertBytes: @"b1" decodeTo: @"ｱ"];
    // An emoji posted as a character reference arrives as plain text.
    [self assertBytes: @"26233132383531323b" decodeTo: @"&#128512;"];
    XCTAssertNil(Ch2StringFromShiftJIS(nil));
}

- (void) testWindowsExtensions
{
    // NEC special characters.
    [self assertBytes: @"8740" decodeTo: @"①"];
    [self assertBytes: @"878d" decodeTo: @"㍾"];
    // NEC-selected IBM extensions.
    [self assertBytes: @"ed40" decodeTo: @"纊"];
    // IBM extensions: TEC gave U+FFFD for these, losing e.g. 髙 in names.
    [self assertBytes: @"fa40" decodeTo: @"ⅰ"];
    [self assertBytes: @"fbfc" decodeTo: @"髙"];
    // User-defined characters go to the private use area.
    [self assertBytes: @"f040" decodeTo: chars(@[@0xE000])];
}

- (void) testWindowsMapping
{
    // Code page 932 mapping, as Windows decodes them.
    [self assertBytes: @"8160" decodeTo: chars(@[@0xFF5E])];   // ～
    [self assertBytes: @"8161" decodeTo: chars(@[@0x2225])];   // ∥
    // TEC gave U+2212, U+00A2, U+00A3 and U+00AC for these four. Both
    // encode back to the same bytes when posting (quoting is safe).
    [self assertBytes: @"817c" decodeTo: chars(@[@0xFF0D])];
    [self assertBytes: @"8191819281ca" decodeTo: chars(@[@0xFFE0, @0xFFE1, @0xFFE2])];
}

- (void) testBadBytesBecomeReplacementCharacters
{
    // Bytes that can't start a character.
    [self assertBytes: @"41ff42" decodeTo: @"A\uFFFDB"];
    [self assertBytes: @"418042" decodeTo: @"A\uFFFDB"];
    // TEC gave U+00A0 for 0xA0.
    [self assertBytes: @"41a042" decodeTo: @"A\uFFFDB"];
    // A lead byte followed by a byte that can't follow it: only the lead
    // byte is lost, the next byte is read again.
    [self assertBytes: @"41822042" decodeTo: @"A\uFFFD B"];
    // A well-formed code with no character (0x81AD is unassigned).
    [self assertBytes: @"4181ad4182a0" decodeTo: @"A\uFFFDAあ"];
    // Several in a row, and the text around them, all kept.
    [self assertBytes: @"82a0fffe82a2" decodeTo: @"あ\uFFFD\uFFFDい"];
}

- (void) testCharacterCutOffAtTheEndIsDropped
{
    // A reply cut in the middle of a character keeps what came before.
    [self assertBytes: @"4182" decodeTo: @"A"];
    [self assertBytes: @"82a082" decodeTo: @"あ"];
    [self assertBytes: @"82" decodeTo: @""];
}

- (void) testLongTextWithOneBadByte
{
    // One bad byte in a big DAT must not cost more than its character.
    NSMutableData* data = [NSMutableData data];
    NSData* line = bytes(@"96bc96b382b582b382f13c3e7361676582c6");   // 名無しさん<>sageと (18 bytes)
    int i;
    for (i = 0; i < 1000; i++) {
        [data appendData: line];
    }
    // 5000 = 277 * 18 + 14: the "g" of "sage" in the 278th line.
    unsigned char bad = 0xFF;
    [data replaceBytesInRange: NSMakeRange(5000, 1) withBytes: &bad];
    NSString* s = Ch2StringFromShiftJIS(data);
    XCTAssertNotNil(s);
    XCTAssertEqual([[s componentsSeparatedByString: @"\uFFFD"] count], (NSUInteger) 2);
    XCTAssertTrue([s hasSuffix: @"名無しさん<>sageと"]);
}

@end
