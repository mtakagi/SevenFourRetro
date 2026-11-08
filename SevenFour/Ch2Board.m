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
    
    // The delegate methods run on the main thread, where the model and the
    // UI live. The session keeps the board alive until it is invalidated.
    session_ = [[NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration]
                                              delegate: self
                                         delegateQueue: [NSOperationQueue mainQueue]] retain];
    receivedData_ = [[NSMutableData alloc] init];
    failedStatus_ = NO;
    contentLength_ = 0;
    estimatedProgress_ = 0;
    [[session_ dataTaskWithRequest: req] resume];
}

- (void) finishUpdating
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

#pragma mark NSURLSessionDataDelegate

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
 didReceiveResponse: (NSURLResponse*) resp
  completionHandler: (void (^)(NSURLSessionResponseDisposition)) completionHandler
{
    NSLog(@"Ch2Board - didReceiveResponse:");
    
    if (session != session_) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;
    if ([http statusCode] == 200) {
        contentLength_ = [http expectedContentLength];
        [receivedData_ setLength: 0];
        completionHandler(NSURLSessionResponseAllow);
    } else {
        NSLog(@"Ch2Board: HTTP status code = %ld", (long) [http statusCode]);
        // The update ends in -URLSession:task:didCompleteWithError:.
        failedStatus_ = YES;
        completionHandler(NSURLSessionResponseCancel);
    }
}

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
     didReceiveData: (NSData*) data
{
    if (session != session_) {
        return;
    }
    
    [receivedData_ appendData: data];
    if (contentLength_ > 0) {
        estimatedProgress_ = (float) [receivedData_ length] / contentLength_;
    }

    [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardLoadingNotification
                          object: self
                        userInfo: nil];
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
    
    if (failedStatus_) {
        // An HTTP error ends the update quietly, as before.
        [self finishUpdating];
        [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardDidFinishParsingNotification
                          object: self
                        userInfo: nil];
    } else if (error) {
        NSLog(@"Ch2Board - didCompleteWithError: %@", error);
        [self finishUpdating];
        [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardDidFinishParsingNotification
                          object: self
                        userInfo: nil];
        [delegate_ board: self didFailWithError: error];
    } else {
        NSLog(@"Ch2Board - didComplete");
        if ([receivedData_ length] == 0) {
            NSLog(@"Ch2Board - [receivedData_ length] == 0");
        } else {
            TECConverter* converter;
            converter = [[TECConverter alloc] initWithEncoding: NSShiftJISStringEncoding];
            NSString* content = [converter convertToString: receivedData_];
            [converter release];
            
            if (content != nil) {
                [self parse: content];
            } else {
                NSLog(@"Ch2Board: Failed to convert encoding.");
            }
        }
        [self finishUpdating];
        [[NSNotificationCenter defaultCenter]
            postNotificationName: Ch2BoardDidFinishParsingNotification
                          object: self
                        userInfo: nil];
    }
}

#pragma mark Override
- (id) init
{
    self = [super init];
    
    subjects_ = [[NSMutableArray alloc] init];
    receivedData_ = nil;
    session_ = nil;
    contentLength_ = 0;
    userAgent_ = nil;
    
    url_ = nil;
    
    return self;
}

- (void) dealloc
{
    // NSLog(@"Board - dealloc");
    [self cancel];
    [subjects_ release];
    [url_ release];
    [userAgent_ release];
    [delegate_ release];
    
    [super dealloc];
}



@end
