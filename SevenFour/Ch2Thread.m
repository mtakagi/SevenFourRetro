/* This file is not copyrighted and may be used freely. */

#import "Ch2Thread.h"
#import "Ch2DatParser.h"
#import "TEC.h"

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

static NSMutableDictionary* sharedFormData_ = NULL;
static NSString* sharedPon_ = NULL;

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
    
    return result;
}

- (NSString*) URLencode
{
    NSData* data = [self dataUsingEncoding: NSShiftJISStringEncoding];
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
    
    return result;
}
@end

@interface NSDate (RFC1123)
- (NSString*) descriptionInRFC1123;
@end

@implementation NSDate (RFC1123)
- (NSString*) descriptionInRFC1123
{
    return [self descriptionWithCalendarFormat: @"%a, %d %b %Y %H:%M:%S GMT"
                                      timeZone: [NSTimeZone timeZoneWithName: @"GMT"]
                                        locale: nil];
}
@end

static NSString* stripQuote(NSString* s)
{
    static NSCharacterSet* quoteSet = NULL;
    if (! quoteSet) {
        quoteSet = [NSCharacterSet characterSetWithCharactersInString: @"\"'"];
        [quoteSet retain];
    }
    
    if ([s rangeOfCharacterFromSet: quoteSet].location == 0) {
        return [s substringWithRange: NSMakeRange(1, [s length] - 2)];
    } else {
        return s;
    }
}

static NSDictionary* parseHTMLAttributes(NSString* s)
{
    static OGRegularExpression* pattern = NULL;
    if (! pattern) {
        pattern = [OGRegularExpression regularExpressionWithString:@"([^ ]+)=([^ >]+)"];
        [pattern retain];
    }

    NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
    
	NSEnumerator* enumerator = [pattern matchEnumeratorInString: s];
	OGRegularExpressionMatch* match;
	while ((match = [enumerator nextObject]) != nil) {
        [result setValue: stripQuote([match substringAtIndex: 2])
                  forKey: [[match substringAtIndex: 1] lowercaseString]];
	}	
    return [result autorelease];
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
    if (match = [p1 matchInString: html]) {
        return [p2 replaceAllMatchesInString: [match substringAtIndex: 1] 
                                  withString: @"\n"];
    } else {
        return nil;
    }
}
    

@implementation Ch2Thread

- (void) addMessages: (NSArray*) ary
{
	int start = [messages_ count];
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
        oldCount_ = [messages_ count];    
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

- (NSURL*) URLOfHTML
{
    NSString* s = [NSString stringWithFormat:
                      @"%@://%@/test/read.cgi%@/%d/",
                      SFSchemeOfURL(board_), [board_ host], [board_ path], number_]; 
    
    return [NSURL URLWithString: s];
}

+ (NSURL*) URLOfDatWithBoard: (NSURL*) board
                      number: (int) number
{
    NSString* s = [NSString stringWithFormat:
                                      @"%@://%@%@/dat/%d.dat",
        SFSchemeOfURL(board), [board host], [board path], number]; 
    
    return [NSURL URLWithString: s];
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
    return [messages_ count];
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

- (void) connection: (NSURLConnection*) connection
    didReceiveResponse: (NSURLResponse*) resp
{
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;

    switch ([http statusCode]) {
    case 200:
        break;
    case 206:
        break;
    case 304:
        break;
    case 416:
        NSLog(@"Ch2Thread: 'Abone' detected?");
        [receivedData_ setLength: 0];
        [connection cancel];
		
		[self finishUpdate];
        break;
    case 302:
        NSLog(@"Ch2Thread: Thread is down.");
        [receivedData_ setLength: 0];
        [connection cancel];
		
		[self finishUpdate];
        break;
    default:
        NSLog(@"Ch2Thread: Unknown status code: %d on %@", 
			  [http statusCode], [http URL]);
        break;
    }
}

- (void) connection: (NSURLConnection*) connection
     didReceiveData: (NSData*) data
{
    [receivedData_ appendData: data];
}

- (void) connection: (NSURLConnection*) connection
   didFailWithError: (NSError*) error
{
    [connection release];
    [receivedData_ dealloc];
    receivedData_ = nil;

    [[NSNotificationCenter defaultCenter]
        postNotificationName: Ch2ThreadConnectionDidFailNotification
                      object: self
                    userInfo: nil];
}

- (void) connectionDidFinishLoading: (NSURLConnection*) connection
{    
    // NSLog(@"Ch2Thread - connectionDidFinishLoading:");
	
    NSArray* newMessages = [Ch2DatParser parseData: receivedData_];
	if (newMessages) {
		// Write cache
		NSMutableData* all = [[NSMutableData alloc] init];
		
		NSData* cached = [delegate_ threadLoadCache: self];
		[all appendData: cached];
		[all appendData: receivedData_];
		
		[delegate_ thread: self writeCache: all];
		
		[cached release];
		[all release];
		
		// Parse
		// FIXME: receivedData_ is parsed...
		[self addMessages: newMessages];
	} else {
        NSLog(@"Ch2Thread(%p) - connectionDidFinishLoading: - Cound't parse receivedData_.",
              self);
    }

    [receivedData_ release];
    receivedData_ = nil;
    
    [connection release];
    
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
    
    oldCount_ = [messages_ count];
    if (oldCount_ == 0) {
        [self loadCache];
    }
	
#if 0
	[self finishUpdate];
#else
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: [self URLOfDat]
                                  cachePolicy: NSURLRequestReloadIgnoringCacheData
                              timeoutInterval: 60.0];
    // NSLog(@"  URL = %@", [self URLOfDat]);
    
    [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    
    NSData* cached = [delegate_ threadLoadCache: self];
    if (cached) {
        [req setValue: @"identity" forHTTPHeaderField: @"Accept-Encoding"];

        NSString* value;
        
        value = [NSString stringWithFormat: @"bytes=%d-", [cached length]];
        [req setValue: value forHTTPHeaderField: @"Range"];
        // NSLog(@"  Range: %@", value);
        
        value = [[delegate_ threadCacheModificationDate: self] descriptionInRFC1123];
        [req setValue: value forHTTPHeaderField: @"If-Modified-Since"];
    } else {
        [req setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    }
    
    NSURLConnection* connection;
    connection = [[NSURLConnection alloc] initWithRequest: req delegate: self];
    if (connection) {
        receivedData_ = [[NSMutableData alloc] init];
    }
#endif
}

- (Ch2ThreadPostResult) resultFromHTMLComment: (NSString*) content
{
    OGRegularExpression* regex;
    OGRegularExpressionMatch* match;
    
    regex = [OGRegularExpression regularExpressionWithString:@"<!-- 2ch_X:[a-z]+ -->"];
    NSString* name = nil;    
    if (match = [regex matchInString: content]) {
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
    if (match = [regex matchInString: content]) {
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

- (Ch2ThreadPostResult) resultFromHTML: (NSData*) data
{
    TECConverter* converter;
    converter = [[TECConverter alloc] initWithEncoding: NSShiftJISStringEncoding];

    NSString* content;
    content = [converter convertToString: data];

    [converter release];    
    
    
    Ch2ThreadPostResult result;

    result = [self resultFromHTMLComment: content];
    if (result == Ch2ThreadPostClientError) {
        result = [self resultFromHTMLTitle: content];
    }
    
    [alertMessage_ release];

	OGRegularExpression* pattern = [OGRegularExpression regularExpressionWithString:@"<input .+?>"];
	NSEnumerator* enumerator = [pattern matchEnumeratorInString: content];
	OGRegularExpressionMatch* match;
	while ((match = [enumerator nextObject]) != nil) {
        NSDictionary* attrs = parseHTMLAttributes([match substringAtIndex: 0]);
        [sharedFormData_ setValue: [attrs valueForKey: @"value"]
                           forKey: [attrs valueForKey: @"name"]];
	}	

    alertMessage_ = [alertMessageFromHTML(content) retain];
    
    return result;
}

- (NSString*) ponFromCookie: (NSString*) cookie
{
	OGRegularExpression* pattern;
	OGRegularExpressionMatch* match;
	
	pattern = [OGRegularExpression regularExpressionWithString: @"PON=(.+?);"];		
	match = [pattern matchInString: cookie];
	if (match) {
		return [match substringAtIndex: 1];
	} else {
		return nil;
	}
}

- (Ch2ThreadPostResult) postWithName: (NSString*) name
                                mail: (NSString*) mail
                                body: (NSString*) body
{
    NSURL* url = [NSURL URLWithString: @"/test/bbs.cgi"
                        relativeToURL: [self URLOfBoard]];

    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithDictionary: sharedFormData_];
    
    [dict setValue: [self boardName]
            forKey: @"bbs"];
    [dict setValue: [NSString stringWithFormat: @"%d", number_] 
            forKey: @"key"];
    [dict setValue: [NSString stringWithFormat: @"%d", 1]
            forKey: @"time"];
    [dict setValue: @"%8F%91%82%AB%8D%9E%82%DE" 
            forKey: @"submit"];
        
    [dict setValue: [name URLencode]
            forKey: @"FROM"];
    [dict setValue: [mail URLencode] 
            forKey: @"mail"];
    [dict setValue: [body URLencode] 
            forKey: @"MESSAGE"];
    
    NSMutableString* string = [NSMutableString string]; 
    
    NSEnumerator* enumerator = [dict keyEnumerator];
    id key;
    while ((key = [enumerator nextObject])) {
        [string appendString: key];
        [string appendString: @"="];
        [string appendString: [dict objectForKey: key]];
        [string appendString: @"&"];
    }    
    [string deleteCharactersInRange: NSMakeRange([string length] - 1, 1)];

    NSData* data = [string dataUsingEncoding: NSASCIIStringEncoding];
    
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: url];
    [req setHTTPMethod: @"POST"];
    [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    [req setValue: [[self URLOfBoard] absoluteString] forHTTPHeaderField: @"Referer"];
    [req setValue: [NSString stringWithFormat:@"%d", [data length]] forHTTPHeaderField: @"Content-Length"];
    [req setHTTPBody: data];

	// Cookie
    NSString* cookie;
    cookie = [NSString stringWithFormat:
		@"NAME=%@; MAIL=%@; PON=%@; expires=%@; path=/",
		name, mail, 
		sharedPon_,
		[[NSDate dateWithTimeIntervalSinceNow: 60] descriptionInRFC1123]];    
    [req setValue: cookie forHTTPHeaderField: @"Cookie"];
    
    NSHTTPURLResponse* resp;
    NSError* error;
    data = [NSURLConnection sendSynchronousRequest: req
								 returningResponse: &resp
											 error: &error];
	[data writeToFile: @"/tmp/sevenfour-post.html"
           atomically: YES];
	Ch2ThreadPostResult	result = [self resultFromHTML: data];
	
	if (result == Ch2ThreadPostCheckCookie) {
		if (sharedPon_) {
			[sharedPon_ release];
		}
		
		sharedPon_ = [self ponFromCookie: [[resp allHeaderFields] objectForKey: @"Set-Cookie"]];
		[sharedPon_ retain];
	}
	
    return result;
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
    userAgent_ = nil;
    
    /* Initialize static values */
    if (! sharedFormData_) {
        sharedFormData_ = [[NSMutableDictionary alloc] init];
    }

    if (! POST_SUCCESS) {
        NSBundle* bundle;
        bundle = [NSBundle mainBundle];

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
    [board_ release];
    
    [receivedData_ release];
    [alertMessage_ release];
    
    [delegate_ release];
    
    [super dealloc];
}


@end
