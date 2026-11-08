/* This file is not copyrighted and may be used freely. */
#import "Ch2Board.h"
#import "TEC.h"

NSString* Ch2BoardLoadingNotification = @"Ch2BoardLoadingNotification";
NSString* Ch2BoardDidFinishLoadingNotification = @"Ch2BoardDidFinishLoadingNotification";

NSString* Ch2BoardParsingNotification = @"Ch2BoardParsingNotification";
NSString* Ch2BoardDidFinishParsingNotification = @"Ch2BoardDidFinishParsingNotification";

@implementation Ch2Board

- (id) initWithURL: url
{
    self = [self init];
    
    url_ = [url retain];
    
    return self;
}

#pragma mark Getter/Setter

- (id) delegate
{
	return delegate_;
}

- (void) setDelegate: (id) delegate
{
    [delegate_ release];
    delegate_ = [delegate retain];
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

- (NSURL*) URL
{
    return url_;
}

- (unsigned) count
{
    return [subjects_ count];
}

- (float) estimatedProgress
{
    return estimatedProgress_;
}

- (NSDictionary*) subjectAtIndex: (unsigned) index
{
    if (index < [subjects_ count]) {
        return [subjects_ objectAtIndex: index];
    } else {
        return nil;
    }
}

- (BOOL) isUpdating
{
    return receivedData_ != nil;
}

- (void) update
{
    if (receivedData_ != nil) {
        return;
    }
    
    [subjects_ removeAllObjects];
    
    NSURL* url = [NSURL URLWithString: @"subject.txt" relativeToURL: url_];
    
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: url];
    
    [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    [req setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    
    NSURLConnection* connection;
    connection = [[NSURLConnection alloc] initWithRequest: req delegate: self];
    if (connection) {
        receivedData_ = [[NSMutableData alloc] init];
    }
}

// One line of subject.txt: "<dat number>.dat<><title> (<count>)".
// A malformed line yields 0 for what can't be read instead of raising.
- (NSMutableDictionary*) parseLine: (NSString*) line
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    line = [line stringByTrimmingCharactersInSet: [NSCharacterSet newlineCharacterSet]];
    NSArray* ary = [line componentsSeparatedByString: @"<>"];
    
    if ([ary count] != 2) {
        return nil;
    }
    
    // "title (n)": the count is the last parenthesized number. The space
    // before it stays in the title, as before.
    NSString* title = [ary objectAtIndex: 1];
    int count = 0;
    NSRange open = [title rangeOfString: @"(" options: NSBackwardsSearch];
    if (open.location != NSNotFound && [title hasSuffix: @")"]) {
        NSRange digits = NSMakeRange(open.location + 1, [title length] - open.location - 2);
        count = [[title substringWithRange: digits] intValue];
        title = [title substringToIndex: open.location];
    }
    
    // "n.dat" to n
    NSString* filename = [ary objectAtIndex: 0];
    if ([filename hasSuffix: @".dat"]) {
        filename = [filename substringToIndex: [filename length] - 4];
    }
    
    [result setObject: [NSNumber numberWithInt: [filename intValue]] forKey: @"dat"];
    [result setObject: title forKey: @"subject"];
    [result setObject: [NSNumber numberWithInt: count] forKey: @"count"];
    
    return result;
}

- (void) parse: (NSString*) source
{
    NSLog(@"Ch2Board - parse:");
    
    size_t length = [source length];
    NSRange range;

    range.location = 0;

    int i;
    for (i = 0; length > 0; i++) {
        NSMutableDictionary* item;
        
        range.length = 0;
        range = [source lineRangeForRange: range];
        
        item = [self parseLine: [source substringWithRange: range]];
        if (! item) {
            break;
        }
        
        [item setObject: [NSNumber numberWithInt: i + 1] forKey: @"no"];
        
        [subjects_ addObject: item];
        
        [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardParsingNotification
                          object: self
                        userInfo: nil];
        
        estimatedProgress_ = (float)([source length] - length) / [source length];
        
        range.location += range.length;
        length -= range.length;
    }
}

// NSURLConnection
- (void) connection: (NSURLConnection*) connection
    didReceiveResponse: (NSURLResponse*) resp
{
    NSLog(@"Ch2Board - connection:didReceiveResponce:");
        
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;
    if ([http statusCode] == 200) {
        contentLength_ = [[[http allHeaderFields] objectForKey: @"Content-Length"] intValue];
        [receivedData_ setLength: 0];
    } else {
        NSLog(@"Ch2Board: HTTP status code = %d", [http statusCode]);
        [connection cancel];
        // The update is over: allow the next one.
        [connection release];
        [receivedData_ release];
        receivedData_ = nil;

        [[NSNotificationCenter defaultCenter]
        postNotificationName: Ch2BoardDidFinishParsingNotification
                      object: self
                    userInfo: nil];
    }
}

- (void) connection: (NSURLConnection*) connection
    didReceiveData: (NSData*) data
{
    [receivedData_ appendData: data];
    estimatedProgress_ = (float) [receivedData_ length] / contentLength_;

    [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardLoadingNotification
                          object: self
                        userInfo: nil];
}

- (void) connection: (NSURLConnection*) connection
    didFailWithError: (NSError*) error
{
    NSLog(@"Ch2Board - connection:didFailWithError:");

    [connection release];
    [receivedData_ release];
    receivedData_ = nil;
	
    [[NSNotificationCenter defaultCenter]
        postNotificationName: Ch2BoardDidFinishParsingNotification
                      object: self
                    userInfo: nil];

	[delegate_ board: self didFailWithError: error];
}

- (void) connectionDidFinishLoading: (NSURLConnection*) connection
{
    NSLog(@"Ch2Board - connectionDidFinishLoading:");

    if ([receivedData_ length] == 0) {
        NSLog(@"Ch2Board - connectionDidFinishLoading: [receivedData_ length] == 0");
    } else {    
        NSString* content;
        
        TECConverter* converter;
        converter = [[TECConverter alloc] initWithEncoding: NSShiftJISStringEncoding];
        content = [converter convertToString: receivedData_];
        [converter release];
        
        if (content != nil) {
            [self parse: content];
        } else {
            NSLog(@"Ch2Board: Failed to convert encoding.");
        }
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName: Ch2BoardDidFinishParsingNotification
                      object: self
                    userInfo: nil];
    
    [connection release];
    
    [receivedData_ release];
    receivedData_ = nil;
}

#pragma mark Override
- (id) init
{
    self = [super init];
    
    subjects_ = [[NSMutableArray alloc] init];
    receivedData_ = nil;
    contentLength_ = 0;
    userAgent_ = nil;
    
    url_ = nil;
    
    return self;
}

- (void) dealloc
{
    // NSLog(@"Board - dealloc");
    [subjects_ dealloc];
    [receivedData_ dealloc];
    
    [url_ release];
    
    [super dealloc];
}



@end
