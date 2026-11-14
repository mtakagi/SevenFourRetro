/* This file is not copyrighted and may be used freely. */
#import <Cocoa/Cocoa.h>

extern NSString* Ch2BoardLoadingNotification;
extern NSString* Ch2BoardParsingNotification;
extern NSString* Ch2BoardDidFinishLoadingNotification;
extern NSString* Ch2BoardDidFinishParsingNotification;

@interface Ch2Board : NSObject <NSURLSessionDataDelegate> {
    NSURL* url_;
    NSMutableArray* subjects_;
    NSMutableData* receivedData_;
    NSURLSession* session_;
    BOOL failedStatus_;

    long long contentLength_;
    float estimatedProgress_;
    NSString* userAgent_;

    id delegate_;
}

- (id)init;
- (void)dealloc;

- (id)initWithURL:url;

- (NSURL*)URL;
- (NSDictionary*)subjectAtIndex:(unsigned)index;
- (unsigned)count;
- (float)estimatedProgress;

- (NSString*)userAgent;
- (void)setUserAgent:(NSString*)name;

// Starts loading subject.txt in the background. When it is over (loaded,
// failed or an HTTP error), Ch2BoardDidFinishParsingNotification is posted
// on the main thread.
- (void)update;
// Stops the current update without posting any notification.
- (void)cancel;
- (BOOL)isUpdating;

- (void)setDelegate:(id)delagate;
- (id)delegate;
@end

@interface NSObject (Ch2BoardDelegate)
- (void)board:(Ch2Board*)board didFailWithError:(NSError*)err;
@end
