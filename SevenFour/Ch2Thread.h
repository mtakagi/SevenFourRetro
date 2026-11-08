/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

typedef enum {
    Ch2ThreadPostSuccess,
    Ch2ThreadPostWarning,
    Ch2ThreadPostError,
    Ch2ThreadPostCheck,
    Ch2ThreadPostCheckCookie,
    // The post could not be sent (e.g. no connection to the server).
    Ch2ThreadPostClientError,
    // The post was sent but no whole reply came back (timeout, connection
    // lost): it may or may not have been written. Don't send it again
    // without checking the thread.
    Ch2ThreadPostUnknown,
} Ch2ThreadPostResult;

typedef void (^Ch2ThreadPostHandler)(Ch2ThreadPostResult result);

extern NSString* Ch2ThreadLoadingNotification;
extern NSString* Ch2ThreadDidFinishLoadingNotification;

extern NSString* Ch2ThreadParsingNotification;
extern NSString* Ch2ThreadDidFinishParsingNotification;

extern NSString* Ch2ThreadDidFinishUpdatingNotification;

extern NSString* Ch2ThreadConnectionDidFailNotification;

@interface Ch2Thread : NSObject <NSURLSessionDataDelegate> {
    NSMutableArray* messages_;
    NSString* subject_;

    NSURL* board_;
    int number_;
    int oldCount_;
    
    NSMutableData* receivedData_;
    // The DAT download: its session, the cache size it asked to continue
    // from (0 for the whole DAT), and the HTTP status it got.
    NSURLSession* session_;
    NSUInteger requestedOffset_;
    NSInteger status_;
    
    NSString* alertMessage_;
    
    BOOL isUpdating_;
    BOOL isPosting_;
    
    id delegate_;
    
    NSString* userAgent_;

    // The form of the last confirmation page bbs.cgi returned, and the post it
    // confirms. Posting the same name, mail and body again submits this form
    // as a browser would.
    NSURL* confirmAction_;
    NSURL* confirmPage_;
    NSArray* confirmFields_;
    NSString* confirmedPost_;
}

- (id) initWithNumber: (int) number
				board: (NSURL*) board;

- (NSString*) subject;
- (int) count;
- (int) newCount;
- (int) number;

- (NSURL*) URLOfBoard;
- (NSURL*) URLOfHTML;
- (NSURL*) URLOfDat;

// The read.cgi and DAT URLs of a thread. Both keep the board's port.
+ (NSURL*) URLOfHTMLWithBoard: (NSURL*) board
                       number: (int) number;
+ (NSURL*) URLOfDatWithBoard: (NSURL*) board
                      number: (int) number;

// The board of a thread URL, keeping its host and port, and the thread
// number in *number:
//   <scheme>://host[:port]/test/read.cgi/BOARD/NUMBER[/RANGE]
//   <scheme>://host[:port]/BOARD/dat/NUMBER.dat
// The board's scheme is SFSchemeOfURL(url). Returns nil for other URLs.
+ (NSURL*) boardOfThreadURL: (NSURL*) url
                     number: (int*) number;

- (NSDictionary*) messageAtIndex: (int) no;

- (NSString*) userAgent;
- (void) setUserAgent: (NSString*) name;

- (void) setDelegate: (id) delegate;

// Downloads the DAT (only what the cache lacks) in the background. When it
// is over, Ch2ThreadDidFinishUpdatingNotification (loaded, unchanged or an
// HTTP error) or Ch2ThreadConnectionDidFailNotification (no reply) is posted
// on the main thread. An -update while one is running is ignored.
- (void) update;
// Stops the current update without posting any notification or writing the
// cache.
- (void) cancel;
- (BOOL) isUpdating;

// Sends a post in the background and calls the handler on the main thread
// with the result; -alertMessage then holds the server's message. Returns
// NO, without sending or calling the handler, while another post of this
// thread is being sent.
- (BOOL) postWithName: (NSString*) name
                 mail: (NSString*) mail
                 body: (NSString*) body
    completionHandler: (Ch2ThreadPostHandler) handler;
- (BOOL) isPosting;
- (NSString*) alertMessage;

// Forgets the hidden fields kept from earlier confirmation pages.
+ (void) forgetConfirmationFormData;
@end

@interface NSObject (Ch2ThreadCacheNotification)
- (NSData*) threadLoadCache: (Ch2Thread*) t;
- (void) thread: (Ch2Thread*) t writeCache: (NSData*) data;
- (NSDate*) threadCacheModificationDate: (Ch2Thread*) t;
@end

@interface NSString (URLencode)
- (NSString*) URLencode;
- (NSString*) URLdecode;
@end

