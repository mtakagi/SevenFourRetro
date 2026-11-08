/* This file is not copyrighted and may be used freely. */

#import "SFThreadSchemeHandler.h"

#import "SFThread.h"
#import "SFThreadHTMLFormatter.h"
#import "SFURLProtocol.h"

@implementation SFThreadSchemeHandler

+ (SFThreadSchemeHandler*) sharedHandler
{
    static SFThreadSchemeHandler* handler = nil;
    if (! handler) {
        handler = [[SFThreadSchemeHandler alloc] init];
    }
    return handler;
}

- (id) init
{
    self = [super init];
    pending_ = [[NSMutableArray alloc] init];
    return self;
}

- (void) dealloc
{
    [pending_ release];
    [super dealloc];
}

// The content type of a skin file, which WebKit needs to use a style sheet
// or a script.
static NSString* typeOfSkinFile(NSString* path)
{
    NSString* ext = [[path pathExtension] lowercaseString];
    NSDictionary* types = [NSDictionary dictionaryWithObjectsAndKeys:
        @"text/css", @"css",
        @"text/javascript", @"js",
        @"text/html", @"html",
        @"image/png", @"png",
        @"image/gif", @"gif",
        @"image/jpeg", @"jpg",
        @"image/jpeg", @"jpeg",
        nil];
    NSString* type = [types objectForKey: ext];
    return type ? type : @"application/octet-stream";
}

static void respond(id<WKURLSchemeTask> task, NSData* data, NSString* type, NSString* encoding)
{
    NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [[task request] URL]
                                                        MIMEType: type
                                           expectedContentLength: (NSInteger) [data length]
                                                textEncodingName: encoding];
    [task didReceiveResponse: response];
    [response release];
    [task didReceiveData: data];
    [task didFinish];
}

- (void) startSkinTask: (id<WKURLSchemeTask>) task
{
    NSString* path = [SFURLProtocol pathOfSkinFile: [[task request] URL]];
    NSData* data = path ? [NSData dataWithContentsOfFile: path] : nil;
    if (! data) {
        [task didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                    code: NSURLErrorFileDoesNotExist
                                                userInfo: nil]];
        return;
    }
    respond(task, data, typeOfSkinFile(path), @"utf-8");
}

- (NSMutableDictionary*) pendingForTask: (id<WKURLSchemeTask>) task
{
    NSEnumerator* e = [pending_ objectEnumerator];
    NSMutableDictionary* entry;
    while ((entry = [e nextObject]) != nil) {
        if ([entry objectForKey: @"task"] == task) {
            return entry;
        }
    }
    return nil;
}

- (void) finishEntry: (NSMutableDictionary*) entry
{
    [[NSNotificationCenter defaultCenter] removeObserver: [entry objectForKey: @"observer"]];
    [pending_ removeObjectIdenticalTo: entry];
}

- (void) startThreadTask: (id<WKURLSchemeTask>) task
{
    SFThread* thread;
    NSString* range;
    [SFURLProtocol parseURL: [[task request] URL] thread: &thread range: &range];
    if (! thread) {
        NSLog(@"SFThreadSchemeHandler: %@ is not a thread.", [[task request] URL]);
        [range release];
        respond(task, [NSData data], @"text/html", @"utf-8");
        return;
    }

    SFThreadHTMLFormatter* formatter = [[[SFThreadHTMLFormatter alloc] init] autorelease];
    [formatter setRange: range];
    [range release];

    // Shown once the thread has been updated, as SFURLProtocol does.
    NSMutableDictionary* entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        task, @"task", thread, @"thread", formatter, @"formatter", nil];
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName: SFThreadDidFinishUpdatingNotification
                    object: thread
                     queue: nil
                usingBlock: ^(NSNotification* n) {
        // Look the entry up again: the task may have been stopped.
        NSMutableDictionary* e = [self pendingForTask: task];
        if (! e) {
            return;
        }
        [[e retain] autorelease];
        [self finishEntry: e];
        NSString* html = [[e objectForKey: @"formatter"] formatThread: [e objectForKey: @"thread"]];
        NSData* data = [html dataUsingEncoding: NSUTF8StringEncoding];
        respond(task, data ? data : [NSData data], @"text/html", @"utf-8");
    }];
    [entry setObject: observer forKey: @"observer"];
    [pending_ addObject: entry];

    [thread update];
}

#pragma mark WKURLSchemeHandler

- (void) webView: (WKWebView*) webView startURLSchemeTask: (id<WKURLSchemeTask>) task
{
    if ([[[[task request] URL] host] isEqualToString: @"skin"]) {
        [self startSkinTask: task];
    } else {
        [self startThreadTask: task];
    }
}

- (void) webView: (WKWebView*) webView stopURLSchemeTask: (id<WKURLSchemeTask>) task
{
    // WebKit may not be sent anything about a stopped task.
    NSMutableDictionary* entry = [self pendingForTask: task];
    if (entry) {
        [self finishEntry: entry];
    }
}

@end
