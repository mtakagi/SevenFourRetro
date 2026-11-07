/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

typedef enum {
    Ch2ThreadPostSuccess,
    Ch2ThreadPostWarning,
    Ch2ThreadPostError,
    Ch2ThreadPostCheck,
    Ch2ThreadPostCheckCookie,
    Ch2ThreadPostClientError,
} Ch2ThreadPostResult;

extern NSString* Ch2ThreadLoadingNotification;
extern NSString* Ch2ThreadDidFinishLoadingNotification;

extern NSString* Ch2ThreadParsingNotification;
extern NSString* Ch2ThreadDidFinishParsingNotification;

extern NSString* Ch2ThreadDidFinishUpdatingNotification;

extern NSString* Ch2ThreadConnectionDidFailNotification;

@interface Ch2Thread : NSObject {
    NSMutableArray* messages_;
    NSString* subject_;

    NSURL* board_;
    int number_;
    int oldCount_;
    
    NSMutableData* receivedData_;
    
    NSString* alertMessage_;
    
    BOOL isUpdating_;
    
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

+ (NSURL*) URLOfDatWithBoard: (NSURL*) board
                      number: (int) number;

- (NSDictionary*) messageAtIndex: (int) no;

- (NSString*) userAgent;
- (void) setUserAgent: (NSString*) name;

- (void) setDelegate: (id) delegate;

- (void) update;
- (BOOL) isUpdating;

- (Ch2ThreadPostResult) postWithName: (NSString*) name
                                mail: (NSString*) mail
                                body: (NSString*) body;
- (NSString*) alertMessage;
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

