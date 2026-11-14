/* This file is not copyrighted and may be used freely. */

#import "Ch2ShiftJIS.h"

// Code page 932: 0x81-0x9F and 0xE0-0xFC start a two-byte character, whose
// second byte is 0x40-0x7E or 0x80-0xFC. 0x00-0x7F and 0xA1-0xDF (half-width
// katakana) are characters by themselves. 0x80, 0xA0 and 0xFD-0xFF are not.
static BOOL isLeadByte(unsigned char c)
{
    return (0x81 <= c && c <= 0x9F) || (0xE0 <= c && c <= 0xFC);
}

static BOOL isTrailByte(unsigned char c)
{
    return (0x40 <= c && c <= 0x7E) || (0x80 <= c && c <= 0xFC);
}

static BOOL isSingleByte(unsigned char c)
{
    return c <= 0x7F || (0xA1 <= c && c <= 0xDF);
}

static NSString* decode(const unsigned char* bytes, NSUInteger length)
{
    return [(NSString*) CFStringCreateWithBytes(NULL, bytes, length, kCFStringEncodingDOSJapanese, false)
        autorelease];
}

// Appends bytes that are well-formed character by character; a code with
// no character in it becomes U+FFFD.
static void appendWellFormed(NSMutableString* result, const unsigned char* bytes, NSUInteger length)
{
    if (length == 0) {
        return;
    }
    NSString* s = decode(bytes, length);
    if (s) {
        [result appendString:s];
        return;
    }
    NSUInteger i = 0;
    while (i < length) {
        NSUInteger n = isLeadByte(bytes[i]) ? 2 : 1;
        s = decode(bytes + i, n);
        [result appendString:s ? s : @"\uFFFD"];
        i += n;
    }
}

NSString* Ch2StringFromShiftJIS(NSData* data)
{
    if (!data) {
        return nil;
    }

    const unsigned char* bytes = [data bytes];
    NSUInteger length = [data length];

    // Most text is well-formed: decode it at once.
    NSString* whole = decode(bytes, length);
    if (whole) {
        return whole;
    }

    NSMutableString* result = [NSMutableString stringWithCapacity:length];
    NSUInteger start = 0; // the well-formed run not appended yet
    NSUInteger i = 0;
    while (i < length) {
        unsigned char c = bytes[i];
        if (isSingleByte(c)) {
            i += 1;
        } else if (isLeadByte(c) && i + 1 < length && isTrailByte(bytes[i + 1])) {
            i += 2;
        } else if (isLeadByte(c) && i + 1 == length) {
            // Cut off after its first byte: drop it.
            appendWellFormed(result, bytes + start, i - start);
            return result;
        } else {
            // Not a character here; go on with the next byte.
            appendWellFormed(result, bytes + start, i - start);
            [result appendString:@"\uFFFD"];
            i += 1;
            start = i;
        }
    }
    appendWellFormed(result, bytes + start, i - start);
    return result;
}
