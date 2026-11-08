/* This file is not copyrighted and may be used freely. */
#import "Ch2BoardTree.h"
#import "Ch2ShiftJIS.h"
#import <OgreKit/OgreKit.h>

@implementation Ch2BoardTree
static NSError* Ch2BoardTreeError(NSString* description)
{
    return [NSError errorWithDomain: NSURLErrorDomain
                               code: NSURLErrorBadServerResponse
                           userInfo: [NSDictionary dictionaryWithObject: description
                                                                 forKey: NSLocalizedDescriptionKey]];
}

- (id) initWithURL: (NSURL*) url
{
    self = [super init];
    
    root_ = [[NSMutableDictionary alloc] init];
    [root_ setObject: [NSMutableArray array] forKey: @"children"];
    
    url_ = [url retain];
    
    return self;
}

- (void) dealloc
{
    [self cancel];
    [root_ release];
    [url_ release];
    [super dealloc];
}

- (NSDictionary*) tree
{
    return root_;
}

- (NSDictionary*) parseLine: (NSString*) line
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];

    OGRegularExpression* regex;
    OGRegularExpressionMatch* match;
    
    regex = [OGRegularExpression regularExpressionWithString:@"^<BR><BR><B>(.+?)</B><BR>"
                                                    options: OgreIgnoreCaseOption];
    if ((match = [regex matchInString: line])) {
        [result setObject: [match substringAtIndex: 1] 
                   forKey: @"title"];
        [result setObject: [NSMutableArray array]
                   forKey: @"children"];
        
        return result;
    }

    regex = [OGRegularExpression regularExpressionWithString:@"^<A HREF=(.+?)>(.+?)</A>"
                                                    options: OgreIgnoreCaseOption];
    if ((match = [regex matchInString: line])) {
        [result setObject: [match substringAtIndex: 1] 
                   forKey: @"url"];
        [result setObject: [match substringAtIndex: 2] 
                   forKey: @"title"];
        
        return result;
    }
    
    return nil;
}

// The categories in bbsmenu.html, each with its boards in "children".
- (NSMutableArray*) parse: (NSString*) source
{
    NSMutableArray* children = [NSMutableArray array];
    NSRange range;
    range.location = 0;
    NSDictionary* category = nil;

    for (;;) {
        NSDictionary* item;
        
        range.length = 0;
        range = [source lineRangeForRange: range];
        
        NSString* line = [source substringWithRange: range];
        if ([line length] > 0) {
            range.location += range.length;
        } else {
            break;
        }
        
        item = [self parseLine: line];
        if ([item objectForKey: @"url"]) {
            [[category objectForKey: @"children"] addObject: item];
        } else if (item) {
            [children addObject: item];
            category = item;
        }
    }
    
    return children;
}

- (BOOL) isUpdating
{
    return task_ != nil;
}

- (void) cancel
{
    [task_ cancel];
    [task_ release];
    task_ = nil;
}

- (void) updateWithCompletionHandler: (void (^)(NSError* error)) handler
{
    [self cancel];
    
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: url_
                                  cachePolicy: NSURLRequestReloadIgnoringCacheData
                              timeoutInterval: 60.0];
    [req setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    
    handler = [[handler copy] autorelease];
    __block NSURLSessionDataTask* task = nil;
    task = [[NSURLSession sharedSession] dataTaskWithRequest: req
                                           completionHandler: ^(NSData* data, NSURLResponse* resp, NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Cancelled, or replaced by a newer update.
            if (task != task_) {
                return;
            }
            [task_ release];
            task_ = nil;
            
            NSError* failure = error;
            NSInteger status = [resp isKindOfClass: [NSHTTPURLResponse class]]
                ? [(NSHTTPURLResponse*) resp statusCode] : 200;
            if (! failure && status != 200) {
                failure = Ch2BoardTreeError([NSHTTPURLResponse localizedStringForStatusCode: status]);
            }
            
            NSString* source = nil;
            if (! failure) {
                source = Ch2StringFromShiftJIS(data);
                if (source == nil) {
                    failure = Ch2BoardTreeError(@"Failed to convert the board list from Shift_JIS.");
                }
            }
            
            NSMutableArray* children = nil;
            if (! failure) {
                children = [self parse: source];
                // Not a board list (a login or error page, say).
                if ([children count] == 0) {
                    failure = Ch2BoardTreeError(@"The board list has no boards.");
                }
            }
            
            if (! failure) {
                [root_ setObject: children forKey: @"children"];
            } else {
                NSLog(@"Ch2BoardTree: %@", failure);
            }
            if (handler) {
                handler(failure);
            }
        });
    }];
    task_ = [task retain];
    [task resume];
}

@end
