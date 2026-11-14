/* This file is not copyrighted and may be used freely. */

#import <Foundation/Foundation.h>

// One request received by SFTestHTTPServer.
@interface SFTestHTTPRequest : NSObject {
    NSString* method_;
    NSString* path_;
    NSDictionary* headers_;
    NSData* body_;
}
- (NSString*)method;
// The request target, including the query (e.g. "/test/bbs.cgi?guid=ON").
- (NSString*)path;
// Header value by case-insensitive name.
- (NSString*)header:(NSString*)name;
- (NSData*)body;
// application/x-www-form-urlencoded body decoded as Shift_JIS.
- (NSDictionary*)formFields;
@end

// A response: status, extra headers and body. Content-Length is added from
// the body unless the headers set it.
@interface SFTestHTTPResponse : NSObject {
    int status_;
    NSDictionary* headers_;
    NSData* body_;
}
+ (SFTestHTTPResponse*)responseWithStatus:(int)status
                                  headers:(NSDictionary*)headers
                                     body:(NSData*)body;
- (int)status;
- (NSDictionary*)headers;
- (NSData*)body;
@end

typedef SFTestHTTPResponse* (^SFTestHTTPHandler)(SFTestHTTPRequest* request);

// A minimal HTTP/1.1 server on 127.0.0.1 and a free port, for tests that
// exercise the real URL loading system (cookies, redirects, Range) without
// the network. Each connection is answered once and closed. The handler runs
// on a background queue.
@interface SFTestHTTPServer : NSObject {
    SFTestHTTPHandler handler_;
    int socket_;
    unsigned short port_;
    dispatch_source_t source_;
    dispatch_queue_t queue_;
    NSMutableArray* requests_;
}
- (id)initWithHandler:(SFTestHTTPHandler)handler;
- (BOOL)start;
- (void)stop;
- (unsigned short)port;
// e.g. http://127.0.0.1:54321/
- (NSURL*)baseURL;
// Requests received so far, in order.
- (NSArray*)requests;
@end
