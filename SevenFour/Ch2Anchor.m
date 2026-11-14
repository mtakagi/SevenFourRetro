/* This file is not copyrighted and may be used freely. */

#import "Ch2Anchor.h"

// The numbers of an anchor in half-width ASCII: full-width digits, comma and
// hyphens (－, −, ‐) as 0-9 , and -.
static NSString* asciiNumbers(NSString* numbers)
{
    NSMutableString* result = [NSMutableString stringWithCapacity: [numbers length]];
    NSUInteger i;
    for (i = 0; i < [numbers length]; i++) {
        unichar c = [numbers characterAtIndex: i];
        if (c >= 0xFF10 && c <= 0xFF19) {          // ０-９
            c = '0' + (c - 0xFF10);
        } else if (c == 0xFF0C) {                   // ，
            c = ',';
        } else if (c == 0xFF0D || c == 0x2212 || c == 0x2010) {   // －, −, ‐
            c = '-';
        }
        [result appendFormat: @"%C", c];
    }
    return result;
}

NSString* Ch2MarkupAnchors(NSString* body)
{
    static NSRegularExpression* pattern = nil;
    if (! pattern) {
        // One or more of &gt; ＞ ≫, then numbers joined by commas or hyphens,
        // half-width or full-width.
        pattern = [[NSRegularExpression alloc]
            initWithPattern: @"((?:&gt;|\\x{FF1E}|\\x{226B})+)"
                             @"([0-9\\x{FF10}-\\x{FF19}]+(?:[,\\x{FF0C}\\-\\x{FF0D}\\x{2212}\\x{2010}][0-9\\x{FF10}-\\x{FF19}]+)*)"
                    options: 0
                      error: NULL];
    }

    NSMutableString* result = [NSMutableString stringWithCapacity: [body length]];
    NSUInteger last = 0;
    NSArray* matches = [pattern matchesInString: body options: 0 range: NSMakeRange(0, [body length])];
    for (NSTextCheckingResult* match in matches) {
        NSRange range = [match range];
        NSString* marks = [body substringWithRange: [match rangeAtIndex: 1]];
        NSString* numbers = [body substringWithRange: [match rangeAtIndex: 2]];
        [result appendString: [body substringWithRange: NSMakeRange(last, range.location - last)]];
        [result appendFormat: @"<a href='#%@'>%@%@</a>", asciiNumbers(numbers), marks, numbers];
        last = NSMaxRange(range);
    }
    [result appendString: [body substringFromIndex: last]];
    return result;
}
