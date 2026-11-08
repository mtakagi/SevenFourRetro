/* This file is not copyrighted and may be used freely. */

#import "Ch2Thread.h"
#import "Ch2DatParser.h"
#import "Ch2ShiftJIS.h"

#import <OgreKit/OgreKit.h>

NSString* Ch2ThreadLoadingNotification = @"Ch2ThreadLoadingNotification";
NSString* Ch2ThreadDidFinishLoadingNotification = @"Ch2ThreadDidFinishLoadingNotification";

NSString* Ch2ThreadParsingNotification = @"Ch2ThreadParsingNotification";
NSString* Ch2ThreadDidFinishParsingNotification = @"Ch2ThreadDidFinishParsingNotification";

NSString* Ch2ThreadDidFinishUpdatingNotification = @"Ch2ThreadDidFinishUpdatingNotification";
NSString* Ch2ThreadConnectionDidFailNotification = @"Ch2ThreadConnectionDidFailNotification";

static NSString* POST_SUCCESS = NULL;
static NSString* POST_ERROR;
static NSString* POST_WAIT;
static NSString* POST_COOKIE;

// Hidden fields from the last confirmation page, sent back with the next post.
static NSMutableDictionary* sharedFormData_ = NULL;

@implementation NSString (PercentEscape)
#include <ctype.h>

- (NSString*) URLdecode
{
    NSData* data = [self dataUsingEncoding: NSASCIIStringEncoding];
    NSMutableString* result = [[NSMutableString alloc] init];
    
    int i;
    const unsigned char* bytes = [data bytes];
    for (i = 0; i < [data length]; i++) {
        if (bytes[i] == '%') {
            int c = 0;

            i++;
            if (isdigit(bytes[i])) {
                c += (bytes[i] - '0');
            } else if ('a' <= bytes[i] && bytes[i] <= 'f') {
                c += (10 + (bytes[i] - 'a'));
            }
            
            c <<= 4;
            
            i++;
            if (isdigit(bytes[i])) {
                c += (bytes[i] - '0');
            } else if ('a' <= bytes[i] && bytes[i] <= 'f') {
                c += (10 + (bytes[i] - 'a'));
            }
            
            [result appendFormat: @"%c", c];
        } else if (bytes[i] == '+') {
            [result appendString: @" "];
        } else {
            [result appendFormat: @"%c", bytes[i]];
        }
    }
    
    return [result autorelease];
}

// Shift_JIS bytes of s. Like a browser submitting a Shift_JIS form, characters
// Shift_JIS can't represent (e.g. emoji) are sent as numeric character
// references instead of making the whole value empty.
static NSData* shiftJISDataWithReferences(NSString* s)
{
    NSData* data = [s dataUsingEncoding: NSShiftJISStringEncoding];
    if (data) {
        return data;
    }

    NSMutableData* result = [NSMutableData data];
    NSUInteger i = 0;
    while (i < [s length]) {
        NSRange r = [s rangeOfComposedCharacterSequenceAtIndex: i];
        NSString* c = [s substringWithRange: r];
        NSData* d = [c dataUsingEncoding: NSShiftJISStringEncoding];
        if (d) {
            [result appendData: d];
        } else {
            NSUInteger j = 0;
            while (j < [c length]) {
                UTF32Char code = [c characterAtIndex: j];
                if (CFStringIsSurrogateHighCharacter(code) && j + 1 < [c length]) {
                    code = CFStringGetLongCharacterForSurrogatePair(code, [c characterAtIndex: j + 1]);
                    j++;
                }
                j++;
                [result appendData: [[NSString stringWithFormat: @"&#%u;", (unsigned) code]
                                       dataUsingEncoding: NSASCIIStringEncoding]];
            }
        }
        i = NSMaxRange(r);
    }
    return result;
}

- (NSString*) URLencode
{
    NSData* data = shiftJISDataWithReferences(self);
    NSMutableString* result = [[NSMutableString alloc] init];
    
    int i;
    const unsigned char* bytes = [data bytes];
    for (i = 0; i < [data length]; i++) {
        if(isalnum(bytes[i]) || 
           bytes[i] == '.' || bytes[i] == '-' || bytes[i] == '_') {
            [result appendFormat: @"%c", bytes[i]];
        } else if (bytes[i] == ' ') {
            [result appendString: @"+"];
        } else {
            [result appendFormat: @"%%%02x", bytes[i]];
        }
    }
    
    return [result autorelease];
}
@end

@interface NSDate (RFC1123)
- (NSString*) descriptionInRFC1123;
@end

@implementation NSDate (RFC1123)
// e.g. "Sun, 08 Nov 2026 00:00:00 GMT", for If-Modified-Since.
- (NSString*) descriptionInRFC1123
{
    static NSDateFormatter* formatter = nil;
    if (! formatter) {
        formatter = [[NSDateFormatter alloc] init];
        // English names and the Gregorian calendar whatever the user's settings.
        [formatter setLocale: [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"]];
        [formatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
        [formatter setDateFormat: @"EEE, dd MMM yyyy HH:mm:ss 'GMT'"];
    }
    return [formatter stringFromDate: self];
}
@end

// Decodes HTML character references: decimal (&#39;), hexadecimal (&#x27;)
// and the named ones a bbs.cgi page uses. Unknown names are left as they are.
static NSString* unescapeHTML(NSString* s)
{
    if ([s rangeOfString: @"&"].location == NSNotFound) {
        return s;
    }

    static NSRegularExpression* pattern = nil;
    static NSDictionary* named = nil;
    if (! pattern) {
        pattern = [[NSRegularExpression alloc] initWithPattern: @"&(#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);"
                                                       options: 0
                                                         error: NULL];
        named = [[NSDictionary alloc] initWithObjectsAndKeys:
            @"&", @"amp", @"<", @"lt", @">", @"gt", @"\"", @"quot", @"'", @"apos",
            @" ", @"nbsp", @"©", @"copy", @"®", @"reg", @"…", @"hellip", nil];
    }

    NSMutableString* result = [NSMutableString string];
    NSUInteger last = 0;
    NSArray* matches = [pattern matchesInString: s options: 0 range: NSMakeRange(0, [s length])];
    NSEnumerator* enumerator = [matches objectEnumerator];
    NSTextCheckingResult* match;
    while ((match = [enumerator nextObject]) != nil) {
        NSString* ref = [s substringWithRange: [match rangeAtIndex: 1]];
        NSString* replacement = nil;
        if ([ref hasPrefix: @"#"]) {
            unsigned long long code = 0;
            if ([ref length] > 1 && ([ref characterAtIndex: 1] == 'x' || [ref characterAtIndex: 1] == 'X')) {
                [[NSScanner scannerWithString: [ref substringFromIndex: 2]] scanHexLongLong: &code];
            } else {
                code = strtoull([[ref substringFromIndex: 1] UTF8String], NULL, 10);
            }
            if (code > 0 && code <= 0x10FFFF && ! (code >= 0xD800 && code <= 0xDFFF)) {
                UTF32Char c = (UTF32Char) code;
                replacement = [[[NSString alloc] initWithBytes: &c
                                                        length: sizeof(c)
                                                      encoding: NSUTF32LittleEndianStringEncoding] autorelease];
            }
        } else {
            replacement = [named objectForKey: ref];
        }
        if (! replacement) {
            continue;
        }
        [result appendString: [s substringWithRange: NSMakeRange(last, [match range].location - last)]];
        [result appendString: replacement];
        last = NSMaxRange([match range]);
    }
    [result appendString: [s substringFromIndex: last]];
    return result;
}

// Attributes of one HTML tag, with lowercase names. Values may be quoted with
// " or ', or unquoted, and are HTML-unescaped.
static NSDictionary* parseHTMLAttributes(NSString* s)
{
    static NSRegularExpression* pattern = nil;
    if (! pattern) {
        pattern = [[NSRegularExpression alloc]
            initWithPattern: @"([A-Za-z_:][-A-Za-z0-9_:.]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))"
                    options: 0
                      error: NULL];
    }

    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    NSArray* matches = [pattern matchesInString: s options: 0 range: NSMakeRange(0, [s length])];
    NSEnumerator* enumerator = [matches objectEnumerator];
    NSTextCheckingResult* match;
    while ((match = [enumerator nextObject]) != nil) {
        NSString* name = [[s substringWithRange: [match rangeAtIndex: 1]] lowercaseString];
        NSString* value = @"";
        int i;
        for (i = 2; i <= 4; i++) {
            if ([match rangeAtIndex: i].location != NSNotFound) {
                value = [s substringWithRange: [match rangeAtIndex: i]];
                break;
            }
        }
        [result setObject: unescapeHTML(value) forKey: name];
    }
    return result;
}

// The first POST form of a page: its action and its successful controls in
// document order, as {name, value} pairs. Hidden inputs and named submit
// buttons are included, as a browser submitting that form would send them.
static NSDictionary* postFormFromHTML(NSString* html)
{
    NSRegularExpression* formPattern = [NSRegularExpression
        regularExpressionWithPattern: @"<form\\b([^>]*)>(.*?)</form>"
                             options: NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                               error: NULL];
    NSRegularExpression* inputPattern = [NSRegularExpression
        regularExpressionWithPattern: @"<input\\b[^>]*>"
                             options: NSRegularExpressionCaseInsensitive
                               error: NULL];

    NSArray* forms = [formPattern matchesInString: html options: 0 range: NSMakeRange(0, [html length])];
    NSEnumerator* formEnumerator = [forms objectEnumerator];
    NSTextCheckingResult* form;
    while ((form = [formEnumerator nextObject]) != nil) {
        NSDictionary* formAttrs = parseHTMLAttributes([html substringWithRange: [form rangeAtIndex: 1]]);
        NSString* method = [[formAttrs objectForKey: @"method"] lowercaseString];
        if (! [method isEqualToString: @"post"]) {
            continue;
        }

        NSString* body = [html substringWithRange: [form rangeAtIndex: 2]];
        NSMutableArray* fields = [NSMutableArray array];
        BOOL hasSubmit = NO;
        NSArray* inputs = [inputPattern matchesInString: body options: 0 range: NSMakeRange(0, [body length])];
        NSEnumerator* inputEnumerator = [inputs objectEnumerator];
        NSTextCheckingResult* input;
        while ((input = [inputEnumerator nextObject]) != nil) {
            NSDictionary* attrs = parseHTMLAttributes([body substringWithRange: [input range]]);
            NSString* type = [[attrs objectForKey: @"type"] lowercaseString];
            NSString* name = [attrs objectForKey: @"name"];
            NSString* value = [attrs objectForKey: @"value"];
            if ([name length] == 0) {
                continue;
            }
            // Only the clicked (first) submit button is sent.
            if ([type isEqualToString: @"submit"]) {
                if (hasSubmit) {
                    continue;
                }
                hasSubmit = YES;
            } else if (! [type isEqualToString: @"hidden"]) {
                continue;
            }
            [fields addObject: [NSArray arrayWithObjects: name, (value ? value : @""), nil]];
        }

        if ([fields count] == 0) {
            continue;
        }
        NSString* action = [formAttrs objectForKey: @"action"];
        return [NSDictionary dictionaryWithObjectsAndKeys:
            fields, @"fields",
            (action ? action : @""), @"action", nil];
    }
    return nil;
}

// Plain text of an HTML page, for showing a server message we can't parse.
static NSString* textFromHTML(NSString* html)
{
    NSMutableString* text = [NSMutableString stringWithString: html];
    NSString* patterns[] = { @"<!--.*?-->", @"<(?:script|style)[^>]*>.*?</(?:script|style)>", @"<br\\s*/?>", @"<[^>]*>" };
    NSString* replacements[] = { @"", @"", @"\n", @"" };
    int i;
    for (i = 0; i < 4; i++) {
        NSRegularExpression* regex = [NSRegularExpression
            regularExpressionWithPattern: patterns[i]
                                 options: NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                   error: NULL];
        [regex replaceMatchesInString: text options: 0 range: NSMakeRange(0, [text length]) withTemplate: replacements[i]];
    }

    // Collapse blank lines and surrounding spaces.
    NSMutableArray* lines = [NSMutableArray array];
    NSEnumerator* enumerator = [[unescapeHTML(text) componentsSeparatedByString: @"\n"] objectEnumerator];
    NSString* line;
    while ((line = [enumerator nextObject]) != nil) {
        line = [line stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([line length] > 0) {
            [lines addObject: line];
        }
    }
    NSString* result = [lines componentsJoinedByString: @"\n"];
    if ([result length] > 500) {
        result = [[result substringToIndex: 500] stringByAppendingString: @"…"];
    }
    return result;
}

static NSString* alertMessageFromHTML(NSString* html)
{
    static OGRegularExpression* p1 = NULL;
    static OGRegularExpression* p2 = NULL;
    if (! p1) {
        p1 = [OGRegularExpression regularExpressionWithString: @"<br></ul><b>(.*?)</b><form"];
        [p1 retain];

        p2 = [OGRegularExpression regularExpressionWithString: @"<br>"];
        [p2 retain];
    }
    
    OGRegularExpressionMatch* match;
    if ((match = [p1 matchInString: html])) {
        return [p2 replaceAllMatchesInString: [match substringAtIndex: 1] 
                                  withString: @"\n"];
    } else {
        NSString* text = textFromHTML(html);
        return ([text length] > 0) ? text : nil;
    }
}
    

@implementation Ch2Thread

- (void) addMessages: (NSArray*) ary
{
	int start = (int) [messages_ count];
	int i;
	for (i = 0; i < [ary count]; i++) {
		NSMutableDictionary* entry = [ary objectAtIndex: i];
		
		if ([entry objectForKey: Ch2MessageThreadSubject] && ! subject_) {
			subject_ = [[entry objectForKey: Ch2MessageThreadSubject] retain];
		}
		
		[entry setObject: [NSNumber numberWithInt: 1 + start + i]
				  forKey: Ch2MessageNumber];
		[messages_ addObject: entry];
	}
}

- (void) parseData: (NSData*) data
{
	NSArray* ary = [Ch2DatParser parseData: data];
	[self addMessages: ary];
}

- (void) loadCache
{
    NSData* data = [delegate_ threadLoadCache: self];
    if (data) {
        [self parseData: data];
        oldCount_ = (int) [messages_ count];    
        // NSLog(@"oldCount = %d", oldCount_);
    }
}

- (NSString*) userAgent
{
    return userAgent_;
}

- (void) setUserAgent: (NSString*) name
{
    [userAgent_ release];
    userAgent_ = [name retain];
}

- (NSURL*) URLOfBoard
{
    return board_;
}

- (NSString*) boardName
{
    NSArray* ary;
    ary = [[[self URLOfBoard] path] componentsSeparatedByString: @"/"];
    return [ary objectAtIndex: 1];
}

- (int) number
{
    return number_;
}

- (NSString*) subject
{
    return subject_;
}

// "host" or "host:port" of url.
static NSString* hostAndPort(NSURL* url)
{
    return [url port] ? [NSString stringWithFormat: @"%@:%@", [url host], [url port]] : [url host];
}

+ (NSURL*) URLOfHTMLWithBoard: (NSURL*) board
                       number: (int) number
{
    NSString* s = [NSString stringWithFormat:
                      @"%@://%@/test/read.cgi%@/%d/",
                      SFSchemeOfURL(board), hostAndPort(board), [board path], number]; 
    
    return [NSURL URLWithString: s];
}

- (NSURL*) URLOfHTML
{
    return [Ch2Thread URLOfHTMLWithBoard: board_ number: number_];
}

+ (NSURL*) URLOfDatWithBoard: (NSURL*) board
                      number: (int) number
{
    NSString* s = [NSString stringWithFormat:
                                      @"%@://%@%@/dat/%d.dat",
        SFSchemeOfURL(board), hostAndPort(board), [board path], number]; 
    
    return [NSURL URLWithString: s];
}

+ (NSURL*) boardOfThreadURL: (NSURL*) url
                     number: (int*) number
{
    NSArray* ary = [[url path] pathComponents];
    NSString* board;
    NSString* thread;
    
    if ([ary count] >= 5 &&
        [[ary objectAtIndex: 1] isEqualToString: @"test"] &&
        [[ary objectAtIndex: 2] isEqualToString: @"read.cgi"]) {
        // 0: /, 1: test, 2: read.cgi, 3: BOARD, 4: NUMBER, 5: RANGE
        board = [ary objectAtIndex: 3];
        thread = [ary objectAtIndex: 4];
    } else if ([ary count] == 4 &&
               [[ary objectAtIndex: 2] isEqualToString: @"dat"] &&
               [[ary objectAtIndex: 3] hasSuffix: @".dat"]) {
        // 0: /, 1: BOARD, 2: dat, 3: NUMBER.dat
        board = [ary objectAtIndex: 1];
        thread = [[ary objectAtIndex: 3] stringByDeletingPathExtension];
    } else {
        return nil;
    }
    
    if ([url host] == nil || [thread intValue] <= 0) {
        return nil;
    }
    if (number) {
        *number = [thread intValue];
    }
    return [NSURL URLWithString: [NSString stringWithFormat: @"%@://%@/%@",
                                     SFSchemeOfURL(url), hostAndPort(url), board]];
}

+ (void) forgetConfirmationFormData
{
    [sharedFormData_ removeAllObjects];
}

- (NSURL*) URLOfDat
{
    return [Ch2Thread URLOfDatWithBoard: board_ number: number_];
}

- (NSDictionary*) messageAtIndex: (int) index
{
    return [messages_ objectAtIndex: index];
}

- (int) count
{
    return (int) [messages_ count];
}

- (int) newCount
{
    return [self count] - oldCount_;
}

- (NSString*) alertMessage
{
    return alertMessage_;
}

- (BOOL) isUpdating
{
    return isUpdating_;
}

- (id) delegate
{
	return delegate_;
}

- (void) setDelegate: (id) delegate
{
    [delegate_ release];
    delegate_ = [delegate retain];
}

- (void) finishUpdate
{
    isUpdating_ = NO;
	
    [[NSNotificationCenter defaultCenter]
        postNotificationName: Ch2ThreadDidFinishUpdatingNotification
                      object: self
                    userInfo: nil];
}

- (void) finishSession
{
    [session_ finishTasksAndInvalidate];
    [session_ release];
    session_ = nil;
    [receivedData_ release];
    receivedData_ = nil;
}

- (void) cancel
{
    [session_ invalidateAndCancel];
    [session_ release];
    session_ = nil;
    [receivedData_ release];
    receivedData_ = nil;
    isUpdating_ = NO;
}

// The offset a 206 reply starts at, from "Content-Range: bytes 100-199/200",
// or NSNotFound when the header is missing or unreadable.
static NSUInteger startOfContentRange(NSHTTPURLResponse* http)
{
    NSString* value = [[http allHeaderFields] objectForKey: @"Content-Range"];
    if (! [value hasPrefix: @"bytes "]) {
        return NSNotFound;
    }
    NSScanner* scanner = [NSScanner scannerWithString: [value substringFromIndex: 6]];
    long long start;
    if (! [scanner scanLongLong: &start] || start < 0) {
        return NSNotFound;
    }
    return (NSUInteger) start;
}

// Keeps the complete lines of a DAT reply. A reply cut in the middle of a
// line would otherwise put half a message in the cache, and the next Range
// request would continue from the wrong place.
static NSData* completeLines(NSData* data)
{
    const char* bytes = [data bytes];
    NSUInteger length = [data length];
    while (length > 0 && bytes[length - 1] != '\n') {
        length--;
    }
    return [data subdataWithRange: NSMakeRange(0, length)];
}

#pragma mark NSURLSessionDataDelegate

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
 didReceiveResponse: (NSURLResponse*) resp
  completionHandler: (void (^)(NSURLSessionResponseDisposition)) completionHandler
{
    if (session != session_) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;
    status_ = [http statusCode];

    switch (status_) {
    case 200:
    case 304:
        break;
    case 206:
        // Appending to the cache is right only if the reply continues it.
        // A 206 must say where it starts (RFC 9110); without a readable
        // Content-Range it can't be shown to, so it isn't appended either.
        if (requestedOffset_ == 0
            || startOfContentRange(http) != requestedOffset_) {
            NSLog(@"Ch2Thread: Content-Range %@ does not continue the cache (%lu bytes).",
                  [[http allHeaderFields] objectForKey: @"Content-Range"],
                  (unsigned long) requestedOffset_);
            completionHandler(NSURLSessionResponseCancel);
            return;
        }
        break;
    case 416:
        NSLog(@"Ch2Thread: 'Abone' detected?");
        completionHandler(NSURLSessionResponseCancel);
        return;
    case 302:
        NSLog(@"Ch2Thread: Thread is down.");
        completionHandler(NSURLSessionResponseCancel);
        return;
    default:
        NSLog(@"Ch2Thread: Unknown status code: %ld on %@", 
			  (long) status_, [http URL]);
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    [receivedData_ setLength: 0];
    completionHandler(NSURLSessionResponseAllow);
}

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
     didReceiveData: (NSData*) data
{
    if (session != session_) {
        return;
    }
    [receivedData_ appendData: data];
}

// Adds a DAT reply to the cache and the messages. A 200 reply to a Range
// request is the whole DAT (the server ignored the Range), so it replaces
// the cache instead of being appended to it.
- (void) addReceivedData: (NSData*) data replacing: (BOOL) replacing
{
    data = completeLines(data);
    if ([data length] == 0) {
        return;
    }
    
    NSArray* newMessages = [Ch2DatParser parseData: data];
    if (! newMessages) {
        NSLog(@"Ch2Thread(%p) - Couldn't parse the DAT reply.", self);
        return;
    }
    
    NSMutableData* all = [NSMutableData data];
    if (! replacing) {
        NSData* cached = [delegate_ threadLoadCache: self];
        [all appendData: cached];
        [cached release];
    }
    [all appendData: data];
    [delegate_ thread: self writeCache: all];
    
    if (replacing) {
        [messages_ removeAllObjects];
    }
    [self addMessages: newMessages];
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didCompleteWithError: (NSError*) error
{
    // A cancelled or replaced update reports nothing.
    if (session != session_) {
        return;
    }
    
    // Keep self alive: the session releases its delegate once invalidated.
    [[self retain] autorelease];
    NSData* data = [[receivedData_ retain] autorelease];
    BOOL accepted = (status_ == 200 || status_ == 206 || status_ == 304);
    
    if (error && ! (status_ != 0 && [[error domain] isEqualToString: NSURLErrorDomain]
                    && [error code] == NSURLErrorCancelled)) {
        // No reply, or the connection was lost midway: keep the cache.
        NSLog(@"Ch2Thread - didCompleteWithError: %@", error);
        [self finishSession];
        isUpdating_ = NO;
        [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2ThreadConnectionDidFailNotification
                          object: self
                        userInfo: nil];
        return;
    }
    
    [self finishSession];
    if (! error && accepted && status_ != 304) {
        [self addReceivedData: data replacing: (status_ == 200 && requestedOffset_ > 0)];
    }
	[self finishUpdate];
}

- (void) update
{
    // NSLog(@"Ch2Thread - update");
    
    if (isUpdating_) {
        return;
    } else {
        isUpdating_ = YES;
    }
    
    oldCount_ = (int) [messages_ count];
    if (oldCount_ == 0) {
        [self loadCache];
    }
	
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: [self URLOfDat]
                                  cachePolicy: NSURLRequestReloadIgnoringCacheData
                              timeoutInterval: 60.0];
    // NSLog(@"  URL = %@", [self URLOfDat]);
    
    [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    
    NSData* cached = [delegate_ threadLoadCache: self];
    requestedOffset_ = [cached length];
    if (requestedOffset_ > 0) {
        [req setValue: @"identity" forHTTPHeaderField: @"Accept-Encoding"];

        NSString* value;
        
        value = [NSString stringWithFormat: @"bytes=%lu-", (unsigned long) requestedOffset_];
        [req setValue: value forHTTPHeaderField: @"Range"];
        // NSLog(@"  Range: %@", value);
        
        value = [[delegate_ threadCacheModificationDate: self] descriptionInRFC1123];
        [req setValue: value forHTTPHeaderField: @"If-Modified-Since"];
    } else {
        [req setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    }
    [cached release];
    
    // The delegate methods run on the main thread, where the messages and
    // the views using them live. The session keeps the thread alive until it
    // is invalidated.
    session_ = [[NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration]
                                              delegate: self
                                         delegateQueue: [NSOperationQueue mainQueue]] retain];
    receivedData_ = [[NSMutableData alloc] init];
    status_ = 0;
    [[session_ dataTaskWithRequest: req] resume];
}

- (Ch2ThreadPostResult) resultFromHTMLComment: (NSString*) content
{
    OGRegularExpression* regex;
    OGRegularExpressionMatch* match;
    
    regex = [OGRegularExpression regularExpressionWithString:@"<!-- 2ch_X:([a-z]+) -->"];
    NSString* name = nil;    
    if ((match = [regex matchInString: content])) {
        name = [match substringAtIndex: 1];
    }
    
    if ([name isEqualToString: @"true"]) {
        return Ch2ThreadPostSuccess;
    } else if ([name isEqualToString: @"false"]) {
        return Ch2ThreadPostWarning;
    } else if ([name isEqualToString: @"error"]) {
        return Ch2ThreadPostError;
    } else if ([name isEqualToString: @"check"]) {
        return Ch2ThreadPostCheck;
    } else if ([name isEqualToString: @"cookie"]) {
        return Ch2ThreadPostCheckCookie;
    } else {
        return Ch2ThreadPostClientError;
    }
}

- (Ch2ThreadPostResult) resultFromHTMLTitle: (NSString*) content
{
    OGRegularExpression* regex;
    OGRegularExpressionMatch* match;

    regex = [OGRegularExpression regularExpressionWithString:@"<title>(.*?)</title>"
                                                     options: OgreIgnoreCaseOption];
    NSString* title = nil;
    if ((match = [regex matchInString: content])) {
        title = [[match substringAtIndex: 1] retain];
        // NSLog(@"title = %@", title);
    }
    if ([title rangeOfString: POST_SUCCESS].length > 0) {
        return Ch2ThreadPostSuccess;
    } else if ([title rangeOfString: POST_ERROR].length > 0) {
        return Ch2ThreadPostError;
    } else if ([title rangeOfString: POST_WAIT].length > 0) {
        return Ch2ThreadPostError;
    } else if ([title rangeOfString: POST_COOKIE].length > 0) {
        return Ch2ThreadPostCheckCookie;
    } else {
        return Ch2ThreadPostClientError;
    }
}

- (void) clearConfirmation
{
    [confirmAction_ release];
    confirmAction_ = nil;
    [confirmPage_ release];
    confirmPage_ = nil;
    [confirmFields_ release];
    confirmFields_ = nil;
    [confirmedPost_ release];
    confirmedPost_ = nil;
}

// Saves the last response when the DebugPostResponse default is set, so a
// failing post can be investigated without posting through other tools.
- (void) saveResponseForDebugging: (NSData*) data URL: (NSURL*) url
{
    if (! [[NSUserDefaults standardUserDefaults] boolForKey: @"DebugPostResponse"]) {
        return;
    }
    NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Logs/SevenFour"];
    [[NSFileManager defaultManager] createDirectoryAtPath: dir
                              withIntermediateDirectories: YES
                                               attributes: nil
                                                    error: NULL];
    [data writeToFile: [dir stringByAppendingPathComponent: @"LastPostResponse.html"] atomically: YES];
    NSLog(@"Ch2Thread: saved the post response from %@ to %@", url, dir);
}

- (Ch2ThreadPostResult) resultFromHTML: (NSData*) data
                                   URL: (NSURL*) url
                                  post: (NSString*) post
{
    if ([data length] == 0) {
        [alertMessage_ release];
        alertMessage_ = nil;
        return Ch2ThreadPostClientError;
    }

    NSString* content = Ch2StringFromShiftJIS(data);
    
    
    Ch2ThreadPostResult result;

    result = [self resultFromHTMLComment: content];
    if (result == Ch2ThreadPostClientError) {
        result = [self resultFromHTMLTitle: content];
    }
    
    [alertMessage_ release];

	// Keep the hidden fields of a confirmation page; bbs.cgi expects them back.
	// The fields this class sets itself are left out.
	static NSSet* ownFields = nil;
	if (! ownFields) {
		ownFields = [[NSSet alloc] initWithObjects:
			@"bbs", @"key", @"time", @"submit", @"FROM", @"mail", @"MESSAGE", nil];
	}
	OGRegularExpression* pattern = [OGRegularExpression regularExpressionWithString: @"<input\\s[^>]*>"
	                                                                        options: OgreIgnoreCaseOption];
	NSEnumerator* enumerator = [pattern matchEnumeratorInString: content];
	OGRegularExpressionMatch* match;
	while ((match = [enumerator nextObject]) != nil) {
        NSDictionary* attrs = parseHTMLAttributes([match matchedString]);
        NSString* type = [[attrs objectForKey: @"type"] lowercaseString];
        NSString* name = [attrs objectForKey: @"name"];
        if (! [type isEqualToString: @"hidden"] || [name length] == 0 || [ownFields containsObject: name]) {
            continue;
        }
        NSString* value = [attrs objectForKey: @"value"];
        [sharedFormData_ setObject: (value ? value : @"") forKey: name];
	}	

    alertMessage_ = [alertMessageFromHTML(content) retain];

    // A confirmation page holds the form to submit for the same post.
    [self clearConfirmation];
    if (result != Ch2ThreadPostSuccess && url) {
        NSDictionary* form = postFormFromHTML(content);
        if (form) {
            NSString* action = [form objectForKey: @"action"];
            confirmAction_ = [[[NSURL URLWithString: action relativeToURL: url] absoluteURL] retain];
            if (! confirmAction_) {
                confirmAction_ = [url retain];
            }
            confirmFields_ = [[form objectForKey: @"fields"] retain];
            confirmPage_ = [url retain];
            confirmedPost_ = [post copy];
        }
    }
    
    return result;
}

// application/x-www-form-urlencoded body from {name, value} pairs, in Shift_JIS.
static NSData* formBody(NSArray* fields)
{
    NSMutableArray* pairs = [NSMutableArray array];
    NSEnumerator* enumerator = [fields objectEnumerator];
    NSArray* field;
    while ((field = [enumerator nextObject]) != nil) {
        [pairs addObject: [NSString stringWithFormat: @"%@=%@",
            [[field objectAtIndex: 0] URLencode], [[field objectAtIndex: 1] URLencode]]];
    }
    return [[pairs componentsJoinedByString: @"&"] dataUsingEncoding: NSASCIIStringEncoding];
}

- (BOOL) isPosting
{
    return isPosting_;
}

// YES when an error means the request never reached the server, so the post
// was certainly not written. Any other error leaves the result unknown.
static BOOL postWasNotSent(NSError* error)
{
    if (! [[error domain] isEqualToString: NSURLErrorDomain]) {
        return NO;
    }
    switch ([error code]) {
    case NSURLErrorBadURL:
    case NSURLErrorUnsupportedURL:
    case NSURLErrorCannotFindHost:
    case NSURLErrorCannotConnectToHost:
    case NSURLErrorDNSLookupFailed:
    case NSURLErrorNotConnectedToInternet:
    case NSURLErrorInternationalRoamingOff:
    case NSURLErrorDataNotAllowed:
    case NSURLErrorAppTransportSecurityRequiresSecureConnection:
    case NSURLErrorSecureConnectionFailed:
    case NSURLErrorServerCertificateHasBadDate:
    case NSURLErrorServerCertificateUntrusted:
    case NSURLErrorServerCertificateHasUnknownRoot:
    case NSURLErrorServerCertificateNotYetValid:
    case NSURLErrorClientCertificateRejected:
    case NSURLErrorClientCertificateRequired:
        return YES;
    default:
        return NO;
    }
}

- (BOOL) postWithName: (NSString*) name
                 mail: (NSString*) mail
                 body: (NSString*) body
    completionHandler: (Ch2ThreadPostHandler) handler
{
    // Pressing the button again, or a second window, must not send twice.
    if (isPosting_) {
        return NO;
    }

    NSString* post = [NSString stringWithFormat: @"%@\n%@\n%@", name, mail, body];
    NSURL* url;
    NSURL* referer;
    NSArray* fields;

    if (confirmFields_ && [confirmedPost_ isEqualToString: post]) {
        // OK on the confirmation page: submit its form as it is.
        url = [[confirmAction_ retain] autorelease];
        // The page the form came from, as a browser would send.
        referer = [[confirmPage_ retain] autorelease];
        fields = [[confirmFields_ retain] autorelease];
    } else {
        url = [NSURL URLWithString: @"/test/bbs.cgi" relativeToURL: [self URLOfBoard]];
        referer = [self URLOfBoard];

        NSMutableArray* ary = [NSMutableArray array];
        [ary addObject: [NSArray arrayWithObjects: @"submit", @"書き込む", nil]];
        [ary addObject: [NSArray arrayWithObjects: @"FROM", name, nil]];
        [ary addObject: [NSArray arrayWithObjects: @"mail", mail, nil]];
        [ary addObject: [NSArray arrayWithObjects: @"MESSAGE", body, nil]];
        [ary addObject: [NSArray arrayWithObjects: @"bbs", [self boardName], nil]];
        [ary addObject: [NSArray arrayWithObjects: @"key", [NSString stringWithFormat: @"%d", number_], nil]];
        // bbs.cgi rejects a form whose time is far from now.
        [ary addObject: [NSArray arrayWithObjects: @"time",
            [NSString stringWithFormat: @"%lld", (long long) [[NSDate date] timeIntervalSince1970]], nil]];

        // Hidden fields kept from an earlier confirmation page.
        NSEnumerator* enumerator = [sharedFormData_ keyEnumerator];
        NSString* key;
        while ((key = [enumerator nextObject])) {
            [ary addObject: [NSArray arrayWithObjects: key, [sharedFormData_ objectForKey: key], nil]];
        }
        fields = ary;
    }
    [self clearConfirmation];

    // Cookies are left to the shared cookie storage, so the ones bbs.cgi sets
    // on its confirmation page are sent back with the next post.
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: url
                                  cachePolicy: NSURLRequestReloadIgnoringCacheData
                              timeoutInterval: 60.0];
    [req setHTTPMethod: @"POST"];
    [req setHTTPShouldHandleCookies: YES];
    [req setMainDocumentURL: url];
    [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    [req setValue: [referer absoluteString] forHTTPHeaderField: @"Referer"];
    [req setValue: @"application/x-www-form-urlencoded" forHTTPHeaderField: @"Content-Type"];
    [req setHTTPBody: formBody(fields)];

    // A session of its own for each post: the request goes out on a new
    // connection, never on a reused one that CFNetwork might retry on
    // behind our back (a POST must not be sent twice). The shared cookie
    // storage is still used.
    NSURLSession* session = [NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate: nil
                                                     delegateQueue: [NSOperationQueue mainQueue]];
    isPosting_ = YES;
    handler = [[handler copy] autorelease];
    // The block keeps self alive until the reply arrives.
    NSURLSessionDataTask* task;
    task = [session dataTaskWithRequest: req
                      completionHandler: ^(NSData* data, NSURLResponse* response, NSError* error) {
        isPosting_ = NO;
        NSHTTPURLResponse* resp = (NSHTTPURLResponse*) response;
        [self saveResponseForDebugging: data URL: [resp URL]];

        Ch2ThreadPostResult result;
        if (error) {
            // Nothing to read; forget any old confirmation page as well.
            [self clearConfirmation];
            [alertMessage_ release];
            alertMessage_ = [[error localizedDescription] retain];
            result = postWasNotSent(error) ? Ch2ThreadPostClientError : Ch2ThreadPostUnknown;
        } else {
            result = [self resultFromHTML: data
                                      URL: ([resp URL] ? [resp URL] : url)
                                     post: post];
        }
        if (handler) {
            handler(result);
        }
    }];
    [task resume];
    [session finishTasksAndInvalidate];
    return YES;
}

- (id) initWithNumber: (int) number
				board: (NSURL*) url
{
    self = [self init];
    
    number_ = number;
    board_ = [url retain];
    
    return self;
}

#pragma mark Override
- (id) init
{
    self = [super init];

    messages_ = [[NSMutableArray alloc] init];
	subject_ = nil;
	
    board_ = nil;
	number_ = 0;
    oldCount_ = 0;
    
    receivedData_ = nil;
    delegate_ = nil;
    alertMessage_ = nil;
    isUpdating_ = NO;
    isPosting_ = NO;
    userAgent_ = nil;
    confirmAction_ = nil;
    confirmPage_ = nil;
    confirmFields_ = nil;
    confirmedPost_ = nil;
    
    /* Initialize static values */
    if (! sharedFormData_) {
        sharedFormData_ = [[NSMutableDictionary alloc] init];
    }

    if (! POST_SUCCESS) {
        // The bundle holding Ch2Thread.strings: the app, or the test bundle.
        NSBundle* bundle;
        bundle = [NSBundle bundleForClass: [Ch2Thread class]];

        POST_SUCCESS =  [bundle localizedStringForKey: @"POST_SUCCESS"
                                                value: nil
                                                table: @"Ch2Thread"];
        POST_ERROR   =  [bundle localizedStringForKey: @"POST_ERROR"
                                                value: nil
                                                table: @"Ch2Thread"];
        POST_WAIT    =  [bundle localizedStringForKey: @"POST_WAIT"
                                                value: nil
                                                table: @"Ch2Thread"];
        POST_COOKIE  =  [bundle localizedStringForKey: @"POST_COOKIE"
                                                value: nil
                                                table: @"Ch2Thread"];
    }
    
    return self;
}

- (void) dealloc
{
    [self cancel];
    [board_ release];
    
    [alertMessage_ release];
    [self clearConfirmation];
    
    [delegate_ release];
    
    [super dealloc];
}


@end
