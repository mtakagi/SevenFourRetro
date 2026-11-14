/* This file is not copyrighted and may be used freely. */

#import "SFTestSupport.h"

@interface SFTestSupportAnchor : NSObject
@end
@implementation SFTestSupportAnchor
@end

NSData* SFTestShiftJIS(NSString* s)
{
    NSMutableData* result = [NSMutableData data];
    NSUInteger i = 0;
    while (i < [s length]) {
        NSRange r = [s rangeOfComposedCharacterSequenceAtIndex:i];
        NSString* c = [s substringWithRange:r];
        NSData* d = [c dataUsingEncoding:NSShiftJISStringEncoding];
        if (!d) {
            NSUInteger j = 0;
            NSMutableString* refs = [NSMutableString string];
            while (j < [c length]) {
                UTF32Char code = [c characterAtIndex:j];
                if (CFStringIsSurrogateHighCharacter(code) && j + 1 < [c length]) {
                    code = CFStringGetLongCharacterForSurrogatePair(code, [c characterAtIndex:j + 1]);
                    j++;
                }
                j++;
                [refs appendFormat:@"&#%u;", (unsigned) code];
            }
            d = [refs dataUsingEncoding:NSASCIIStringEncoding];
        }
        [result appendData:d];
        i = NSMaxRange(r);
    }
    return result;
}

BOOL SFTestContains(NSString* s, NSString* part)
{
    return s != nil && [s rangeOfString:part].location != NSNotFound;
}

NSString* SFTestHTMLEscape(NSString* s)
{
    NSMutableString* m = [NSMutableString stringWithString:s];
    NSArray* pairs = [NSArray arrayWithObjects:
            @"&", @"&amp;", @"<", @"&lt;", @">", @"&gt;", @"\"", @"&quot;", @"'", @"&#x27;", nil];
    NSUInteger i;
    for (i = 0; i < [pairs count]; i += 2) {
        [m replaceOccurrencesOfString:[pairs objectAtIndex:i]
                           withString:[pairs objectAtIndex:i + 1]
                              options:0
                                range:NSMakeRange(0, [m length])];
    }
    return m;
}

static NSString* decodeComponent(NSString* s)
{
    NSData* ascii = [[s stringByReplacingOccurrencesOfString:@"+" withString:@" "]
        dataUsingEncoding:NSASCIIStringEncoding];
    const unsigned char* bytes = [ascii bytes];
    NSMutableData* out = [NSMutableData data];
    NSUInteger i;
    for (i = 0; i < [ascii length]; i++) {
        unsigned char c = bytes[i];
        if (c == '%' && i + 2 < [ascii length]) {
            char hex[3] = { (char) bytes[i + 1], (char) bytes[i + 2], 0 };
            c = (unsigned char) strtoul(hex, NULL, 16);
            i += 2;
        }
        [out appendBytes:&c length:1];
    }
    return [[[NSString alloc] initWithData:out encoding:NSShiftJISStringEncoding] autorelease];
}

NSDictionary* SFTestDecodeForm(NSString* s)
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    NSEnumerator* enumerator = [[s componentsSeparatedByString:@"&"] objectEnumerator];
    NSString* pair;
    while ((pair = [enumerator nextObject]) != nil) {
        if ([pair length] == 0) {
            continue;
        }
        NSRange eq = [pair rangeOfString:@"="];
        NSString* name = (eq.location == NSNotFound) ? pair : [pair substringToIndex:eq.location];
        NSString* value = (eq.location == NSNotFound) ? @"" : [pair substringFromIndex:eq.location + 1];
        NSString* decoded = decodeComponent(value);
        [result setObject:(decoded ? decoded : @"") forKey:decodeComponent(name)];
    }
    return result;
}

NSString* SFTestFixture(NSString* name)
{
    NSBundle* bundle = [NSBundle bundleForClass:[SFTestSupportAnchor class]];
    NSString* path = [[bundle resourcePath] stringByAppendingPathComponent:
            [@"Fixtures" stringByAppendingPathComponent:name]];
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

NSData* SFTestFixtureShiftJIS(NSString* name)
{
    NSString* s = SFTestFixture(name);
    return s ? SFTestShiftJIS(s) : nil;
}

NSString* SFTestTemporaryDirectory(void)
{
    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [@"SevenFourTests-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createDirectoryAtPath:path
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    return path;
}

BOOL SFTestWaitFor(NSTimeInterval timeout, BOOL (^condition)(void))
{
    NSDate* limit = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition()) {
        if ([limit timeIntervalSinceNow] <= 0) {
            return NO;
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return YES;
}

void SFTestClearLocalCookies(void)
{
    NSHTTPCookieStorage* storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSEnumerator* enumerator = [[[[storage cookies] copy] autorelease] objectEnumerator];
    NSHTTPCookie* cookie;
    while ((cookie = [enumerator nextObject]) != nil) {
        if ([[cookie domain] isEqualToString:@"127.0.0.1"] || [[cookie domain] isEqualToString:@"localhost"]) {
            [storage deleteCookie:cookie];
        }
    }
}
