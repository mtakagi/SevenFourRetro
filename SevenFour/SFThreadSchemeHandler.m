/* This file is not copyrighted and may be used freely. */

#import "SFThreadSchemeHandler.h"

#import "SFThread.h"
#import "SFThreadHTMLFormatter.h"
#import "SFThreadView.h"
#import "SFThreadFactory.h"

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
    NSString* path = [SFThreadHTMLFormatter pathOfSkinFile: [[[task request] URL] path]];
    NSData* data = path ? [NSData dataWithContentsOfFile: path] : nil;
    if (! data) {
        [task didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                    code: NSURLErrorFileDoesNotExist
                                                userInfo: nil]];
        return;
    }
    respond(task, data, typeOfSkinFile(path), @"utf-8");
}

// The thread of a sevenfour:// thread URL, and its range (retained; release
// it) when the URL has one.
+ (void) parseURL: (NSURL*) url
           thread: (SFThread**) thread
            range: (NSString**) range
{
    *range = nil;

    // The board keeps the host and port of the URL (#37).
    *thread = [[SFThreadFactory sharedFactory] threadWithURL: url];

    NSArray* ary = [[url path] pathComponents];
    if (*thread && [ary count] > 5 &&
        [[ary objectAtIndex: 1] isEqualTo: @"test"] &&
        [[ary objectAtIndex: 2] isEqualTo: @"read.cgi"]) {
        // 0: /, 1: test, 2: read.cgi, 3: BOARD, 4: NUMBER, 5: RANGE
        *range = [[ary objectAtIndex: 5] retain];
    }
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

- (void) startThreadTask: (id<WKURLSchemeTask>) task webView: (WKWebView*) webView
{
    SFThread* thread;
    NSString* range;
    [SFThreadSchemeHandler parseURL: [[task request] URL] thread: &thread range: &range];
    if (! thread) {
        NSLog(@"SFThreadSchemeHandler: %@ is not a thread.", [[task request] URL]);
        [range release];
        respond(task, [NSData data], @"text/html", @"utf-8");
        return;
    }

    SFThreadHTMLFormatter* formatter = [[[SFThreadHTMLFormatter alloc] init] autorelease];
    [formatter setRange: range];
    [range release];

    // Shown once the thread has been updated.
    NSMutableDictionary* entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        task, @"task", thread, @"thread", formatter, @"formatter", webView, @"webView", nil];
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
        SFThread* th = [e objectForKey: @"thread"];
        // The thread may be updated again before the page has loaded: the
        // view adds the messages after the ones in this page.
        WKWebView* view = [e objectForKey: @"webView"];
        if ([view isKindOfClass: [SFThreadView class]]) {
            [(SFThreadView*) view setPageCount: [th count]];
        }
        NSString* html = [[e objectForKey: @"formatter"] formatThread: th];
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
        [self startThreadTask: task webView: webView];
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
