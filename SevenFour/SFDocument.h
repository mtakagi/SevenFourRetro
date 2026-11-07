/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class QuickLiteDatabase;
@class SFBoard;
@class SFThread;
@class SFWindowController;

@interface SFDocument : NSDocument
{        
    SFBoard* board_;

    BOOL offline_;
    int workingJobs_;
	
	NSURL* URLOfThread_;
	
	SFWindowController* windowController_;
}

- (BOOL) isWorking;

- (BOOL) openBoard: (NSURL*) url
			 title: (NSString*) title;
- (void) updateBoard;

- (NSString*) boardName;
- (NSURL*) URLOfBoard;
// - (NSURL*) initialURL;

+ (NSDictionary*) sharedBoardTree;

- (BOOL) isOffline;

- (IBAction) updateBoardTreePList;

+ (SFThread*) threadWithURL: (NSURL*) url;

- (void) setBoard: (SFBoard*) board;
- (SFBoard*) board;

@end
