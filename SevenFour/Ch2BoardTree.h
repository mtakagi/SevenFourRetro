/* This file is not copyrighted and may be used freely. */
#import <Cocoa/Cocoa.h>

@interface Ch2BoardTree : NSObject {
    NSMutableDictionary* root_;
    NSURL* url_;
    NSURLSessionDataTask* task_;
}

- (id) initWithURL: (NSURL*) url;

// Loads the board list in the background and calls the handler on the main
// thread. On failure (no connection, an HTTP error or an undecodable reply)
// the handler gets the error and -tree keeps what it had.
- (void) updateWithCompletionHandler: (void (^)(NSError* error)) handler;
// Stops the current update; its handler is not called.
- (void) cancel;
- (BOOL) isUpdating;

- (NSDictionary*) tree;

@end
