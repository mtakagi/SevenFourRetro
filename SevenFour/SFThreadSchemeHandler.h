/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// Serves sevenfour:// URLs to the pages (SFPageView, WKWebView, #28): a thread
// page (sevenfour://host/test/read.cgi/BOARD/NUMBER[/RANGE] or the dat
// form) after updating the thread, and the skin's files
// (sevenfour://skin/...). WebKit calls it on the main thread, where the
// threads live.
@interface SFThreadSchemeHandler : NSObject <WKURLSchemeHandler> {
    // Tasks waiting for their thread to finish updating, with the thread,
    // the formatter and the observer of each.
    NSMutableArray* pending_;
}

+ (SFThreadSchemeHandler*) sharedHandler;

@end
