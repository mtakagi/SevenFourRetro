/* This file is not copyrighted and may be used freely. */

#import "SFSmartBoard.h"
#import "SFDocument.h"
#import "SFThread.h"
#import "SFThreadFactory.h"
#import <QuickLite/QuickLiteCursor.h>
#import <QuickLite/QuickLiteDatabaseExtras.h>

@implementation SFSmartBoard

- (void) setQuery: (NSString*) query
{
	[query_ release];
	query_ = [query retain];
	
	[threads_ removeAllObjects];
}

- (NSArray*) threads
{
	return threads_;
}

- (NSString*) title
{
	return title_;
}

- (void) update
{
	if ([threads_ count] == 0 || 1) {
		QuickLiteDatabase* db = [SFThread sharedDatabase];    
		QuickLiteCursor* cursor = [db performQuery: query_];
		
		SFThreadFactory* factory = [SFThreadFactory sharedFactory];
		
		[threads_ removeAllObjects];
		
		int i;
		for (i = 0; i < [cursor rowCount]; i++) {
			QuickLiteRow* row = [cursor rowAtIndex: i];
			
			NSURL* board = [NSURL URLWithString: [row stringForColumn: @"threads.board"]];
			int number = [row intValueForColumn: @"threads.dat"];
			
			SFThread* th = [factory threadWithBoard: board number: number];
			
			[th loadMetadata];
			[threads_ addObject: th];
		}
		
		[[NSNotificationCenter defaultCenter]
        postNotificationName: SFBoardDidFinishUpdatingNotification
                      object: self
                    userInfo: nil];
	} else {
		int i;
		for (i = 0; i < [threads_ count]; i++) {
			SFThread* th = [threads_ objectAtIndex: i];
			[th update];
		}
	}
}

- (id) initWithQuery: (NSString*) query 
			   title: (NSString*) title
{
	self = [self init];
	
	[self setQuery: query];
	[self setTitle: title];
	
	return self;
}

#pragma mark Override
- (id) init
{
    self = [super init];
    
	query_ = nil;
	threads_ = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) dealloc
{
	[query_ release];
	[threads_ release];
	
	[super dealloc];
}

@end
