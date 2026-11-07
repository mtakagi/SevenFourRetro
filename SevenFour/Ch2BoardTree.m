/* This file is not copyrighted and may be used freely. */
#import "Ch2BoardTree.h"
#import "TEC.h"
#import <OgreKit/OgreKit.h>

@implementation Ch2BoardTree
+ (NSString*) stringWithContentsOfURL: (NSURL*) url
{
    NSMutableURLRequest* req;
    req = [NSMutableURLRequest requestWithURL: url
                                  cachePolicy: NSURLRequestReloadIgnoringCacheData
                              timeoutInterval: 60.0];
    // [req setValue: userAgent_ forHTTPHeaderField: @"User-Agent"];
    [req setValue: @"gzip" forHTTPHeaderField: @"Accept-Encoding"];
    
    NSURLResponse* resp;
    NSError* error;
    NSData* data = [NSURLConnection sendSynchronousRequest: req
                                         returningResponse: &resp
                                                     error: &error];
    
    TECConverter* converter;
    converter = [[TECConverter alloc] initWithEncoding: NSShiftJISStringEncoding];
    
    NSString* result = [converter convertToString: data];
    [converter release];
    
    return result;
}


- (id) initWithURL: (NSURL*) url
{
    self = [super init];
    
    root_ = [[NSMutableDictionary alloc] init];
    [root_ setObject: [[NSMutableArray alloc] init] forKey: @"children"];
    
    url_ = [url retain];
    
    return self;
}

- (void) dealloc
{
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
    if (match = [regex matchInString: line]) {
        [result setObject: [match substringAtIndex: 1] 
                   forKey: @"title"];
        [result setObject: [[NSMutableArray alloc] init]
                   forKey: @"children"];
        
        return result;
    }

    regex = [OGRegularExpression regularExpressionWithString:@"^<A HREF=(.+?)>(.+?)</A>"
                                                    options: OgreIgnoreCaseOption];
    if (match = [regex matchInString: line]) {
        [result setObject: [match substringAtIndex: 1] 
                   forKey: @"url"];
        [result setObject: [match substringAtIndex: 2] 
                   forKey: @"title"];
        
        return result;
    }
    
    return nil;
}

- (void) update
{        
    [[root_ objectForKey: @"children"] removeAllObjects];
    
    NSString* source = [Ch2BoardTree stringWithContentsOfURL: url_];

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
            [[root_ objectForKey: @"children"] addObject: item];
            category = item;
        }
    }    
}

@end
