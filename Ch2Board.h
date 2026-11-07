/* This file is not copyrighted and may be used freely. */
#import <Cocoa/Cocoa.h>

extern NSString* Ch2BoardLoadingNotification;
extern NSString* Ch2BoardParsingNotification;
extern NSString* Ch2BoardDidFinishLoadingNotification;
extern NSString* Ch2BoardDidFinishParsingNotification;

@interface Ch2Board : NSObject {
    NSURL* url_;
    NSMutableArray* subjects_;
    NSMutableData* receivedData_;
    
    int contentLength_;
    float estimatedProgress_;
    NSString* userAgent_;
	
	id delegate_;
}

- (id) init;
- (void) dealloc;

- (id) initWithURL: url;

- (NSURL*) URL;
- (NSDictionary*) subjectAtIndex: (unsigned) index;
- (unsigned) count;
- (float) estimatedProgress;

- (NSString*) userAgent;
- (void) setUserAgent: (NSString*) name;

- (void) update;
- (BOOL) isUpdating;

- (void) setDelegate: (id) delagate;
- (id) delegate;
@end

@interface NSObject (Ch2BoardDelegate)
- (void) board: (Ch2Board*) board didFailWithError: (NSError*) err;
@end
