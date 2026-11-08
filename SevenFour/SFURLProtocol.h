/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import "SFThread.h"

@class SFThreadHTMLFormatter;

// Serves sevenfour:// URLs to the thread WebViews.
//
// NSURLProtocol runs on a CFNetwork thread, but SFThread, Ch2Thread and the
// WebViews observing their notifications are main-thread objects. So the
// thread is looked up, updated and formatted on the main thread, and the
// result is handed back to the client on the thread that started loading.
@interface SFURLProtocol : NSURLProtocol {
    SFThreadHTMLFormatter* formatter_;

    NSThread* clientThread_;
    NSArray* clientModes_;
    BOOL stopped_;
}

// The thread of a sevenfour:// thread URL, and its range (retained; release
// it) when the URL has one. Main thread.
+ (void) parseURL: (NSURL*) url
		   thread: (SFThread**) thread
			range: (NSString**) range;

// The file of a sevenfour://skin/ URL: the user's skin (Application
// Support) first, then the app's. nil when there is none.
+ (NSString*) pathOfSkinFile: (NSURL*) url;

@end
