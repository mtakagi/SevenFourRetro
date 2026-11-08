/* This file is not copyrighted and may be used freely. */

#import "SFTestHTTPServer.h"
#import "SFTestSupport.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

@implementation SFTestHTTPRequest

- (id) initWithMethod: (NSString*) method
                 path: (NSString*) path
              headers: (NSDictionary*) headers
                 body: (NSData*) body
{
    self = [super init];
    method_ = [method copy];
    path_ = [path copy];
    headers_ = [headers copy];
    body_ = [body copy];
    return self;
}

- (void) dealloc
{
    [method_ release];
    [path_ release];
    [headers_ release];
    [body_ release];
    [super dealloc];
}

- (NSString*) method { return method_; }
- (NSString*) path { return path_; }
- (NSData*) body { return body_; }

- (NSString*) header: (NSString*) name
{
    return [headers_ objectForKey: [name lowercaseString]];
}

- (NSDictionary*) formFields
{
    NSString* s = [[[NSString alloc] initWithData: body_ encoding: NSASCIIStringEncoding] autorelease];
    return SFTestDecodeForm(s);
}

@end


@implementation SFTestHTTPResponse

+ (SFTestHTTPResponse*) responseWithStatus: (int) status
                                   headers: (NSDictionary*) headers
                                      body: (NSData*) body
{
    SFTestHTTPResponse* r = [[[SFTestHTTPResponse alloc] init] autorelease];
    r->status_ = status;
    r->headers_ = [headers copy];
    r->body_ = [body copy];
    return r;
}

- (void) dealloc
{
    [headers_ release];
    [body_ release];
    [super dealloc];
}

- (int) status { return status_; }
- (NSDictionary*) headers { return headers_; }
- (NSData*) body { return body_; }

@end


@implementation SFTestHTTPServer

- (id) initWithHandler: (SFTestHTTPHandler) handler
{
    self = [super init];
    handler_ = [handler copy];
    socket_ = -1;
    requests_ = [[NSMutableArray alloc] init];
    queue_ = dispatch_queue_create("SFTestHTTPServer", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (void) dealloc
{
    [self stop];
    [handler_ release];
    [requests_ release];
    dispatch_release(queue_);
    [super dealloc];
}

- (unsigned short) port
{
    return port_;
}

- (NSURL*) baseURL
{
    return [NSURL URLWithString: [NSString stringWithFormat: @"http://127.0.0.1:%u/", port_]];
}

- (NSArray*) requests
{
    @synchronized (requests_) {
        return [[requests_ copy] autorelease];
    }
}

- (BOOL) start
{
    socket_ = socket(AF_INET, SOCK_STREAM, 0);
    if (socket_ < 0) {
        return NO;
    }
    int yes = 1;
    setsockopt(socket_, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = 0;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(socket_, (struct sockaddr*) &addr, sizeof(addr)) != 0 || listen(socket_, 16) != 0) {
        close(socket_);
        socket_ = -1;
        return NO;
    }
    socklen_t len = sizeof(addr);
    getsockname(socket_, (struct sockaddr*) &addr, &len);
    port_ = ntohs(addr.sin_port);

    int listening = socket_;
    source_ = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, listening, 0, queue_);
    dispatch_source_set_event_handler(source_, ^{
        int client = accept(listening, NULL, NULL);
        if (client >= 0) {
            [self retain];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
                [self serveClient: client];
                [self release];
            });
        }
    });
    dispatch_source_set_cancel_handler(source_, ^{
        close(listening);
    });
    dispatch_resume(source_);
    return YES;
}

- (void) stop
{
    if (source_) {
        dispatch_source_cancel(source_);
        dispatch_release(source_);
        source_ = NULL;
        socket_ = -1;
    }
}

// Reads one request, answers it and closes the connection.
- (void) serveClient: (int) client
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    struct timeval timeout = { 10, 0 };
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    int nosigpipe = 1;
    setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, sizeof(nosigpipe));

    NSMutableData* data = [NSMutableData data];
    NSRange end = NSMakeRange(NSNotFound, 0);
    NSData* separator = [NSData dataWithBytes: "\r\n\r\n" length: 4];
    char buffer[8192];
    while (end.location == NSNotFound) {
        ssize_t n = read(client, buffer, sizeof(buffer));
        if (n <= 0) {
            close(client);
            [pool release];
            return;
        }
        [data appendBytes: buffer length: n];
        end = [data rangeOfData: separator options: 0 range: NSMakeRange(0, [data length])];
    }

    NSString* head = [[[NSString alloc] initWithData: [data subdataWithRange: NSMakeRange(0, end.location)]
                                            encoding: NSISOLatin1StringEncoding] autorelease];
    NSArray* lines = [head componentsSeparatedByString: @"\r\n"];
    NSArray* requestLine = [[lines objectAtIndex: 0] componentsSeparatedByString: @" "];
    NSMutableDictionary* headers = [NSMutableDictionary dictionary];
    NSUInteger i;
    for (i = 1; i < [lines count]; i++) {
        NSString* line = [lines objectAtIndex: i];
        NSRange colon = [line rangeOfString: @":"];
        if (colon.location == NSNotFound) {
            continue;
        }
        NSString* name = [[line substringToIndex: colon.location] lowercaseString];
        NSString* value = [[line substringFromIndex: colon.location + 1]
                              stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        [headers setObject: value forKey: name];
    }

    NSUInteger bodyStart = NSMaxRange(end);
    NSUInteger contentLength = (NSUInteger) [[headers objectForKey: @"content-length"] integerValue];
    while ([data length] < bodyStart + contentLength) {
        ssize_t n = read(client, buffer, sizeof(buffer));
        if (n <= 0) {
            break;
        }
        [data appendBytes: buffer length: n];
    }
    NSUInteger available = [data length] - bodyStart;
    NSData* body = [data subdataWithRange: NSMakeRange(bodyStart, MIN(contentLength, available))];

    SFTestHTTPRequest* request = [[[SFTestHTTPRequest alloc]
        initWithMethod: ([requestLine count] > 0 ? [requestLine objectAtIndex: 0] : @"")
                  path: ([requestLine count] > 1 ? [requestLine objectAtIndex: 1] : @"/")
               headers: headers
                  body: body] autorelease];
    @synchronized (requests_) {
        [requests_ addObject: request];
    }

    SFTestHTTPResponse* response = handler_(request);
    if (! response) {
        response = [SFTestHTTPResponse responseWithStatus: 404 headers: nil body: [NSData data]];
    }

    NSMutableString* responseHead = [NSMutableString stringWithFormat: @"HTTP/1.1 %d X\r\n", [response status]];
    [responseHead appendFormat: @"Content-Length: %lu\r\n", (unsigned long) [[response body] length]];
    [responseHead appendString: @"Connection: close\r\n"];
    NSEnumerator* enumerator = [[response headers] keyEnumerator];
    NSString* name;
    while ((name = [enumerator nextObject]) != nil) {
        [responseHead appendFormat: @"%@: %@\r\n", name, [[response headers] objectForKey: name]];
    }
    [responseHead appendString: @"\r\n"];

    NSMutableData* out = [NSMutableData dataWithData: [responseHead dataUsingEncoding: NSISOLatin1StringEncoding]];
    if ([response body]) {
        [out appendData: [response body]];
    }
    const char* bytes = [out bytes];
    NSUInteger written = 0;
    while (written < [out length]) {
        ssize_t n = write(client, bytes + written, [out length] - written);
        if (n <= 0) {
            break;
        }
        written += n;
    }
    close(client);
    [pool release];
}

@end
