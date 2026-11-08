/* This file is not copyrighted and may be used freely. */

#import "Ch2Thread.h"

extern NSString* SFThreadDidFinishUpdatingNotification;

@class QuickLiteDatabase;

@interface SFThread : NSObject {
    NSURL* board_;
    int number_;
	BOOL offline_;
    
    NSString* subject_;
    int index_, count_;
    
    int local_, rate_;
    NSString* comment_;
	NSCalendarDate* visitedTime_;
	BOOL isNew_;
	BOOL cacheDeleted_;
	// A post is being sent. Kept here rather than only in thread_, which is
	// replaced when the log is deleted (#26).
	BOOL posting_;
    
    NSMutableDictionary* idCounts_;
	
    Ch2Thread* thread_;
}

- (id) initWithNumber: (int) number
				board: (NSURL*) board;

- (int) number;

// From subject.txt
- (NSString*) subject;
- (int) index;
- (int) count;

- (void) setSubject: (NSString*) subject;
- (void) setIndex:   (int) index;
- (void) setCount:   (int) count;

- (NSDate*) creationDate;

// Meta data
- (void) loadMetadata;
- (void) saveMetadata;

- (BOOL) isNew;
- (int) local;
- (int) delta;
- (int) rate;
- (void) setRate: (int) rate;
- (int) newCount;
- (float) pace;

// URL
- (NSURL*) URLOfBoard;
- (NSURL*) URLOfHTML;
- (NSURL*) URLOfDat;

//
- (void) update;
- (void) removeCache;
- (NSDictionary*) messageAtIndex: (int) index;
- (int) countOfID: (NSString*) key;

//
// See -[Ch2Thread postWithName:mail:body:completionHandler:].
- (BOOL) postWithName: (NSString*) name
				 mail: (NSString*) mail
				 body: (NSString*) body
	completionHandler: (Ch2ThreadPostHandler) handler;
- (NSString*) alertMessage;

- (BOOL) isEqualToThread: (SFThread*) th;

- (void) setOffline: (BOOL) flag;
- (BOOL) offline;
- (int) countOfID: (NSString*) s;

+ (QuickLiteDatabase*) sharedDatabase;

@end
