/* This file is not copyrighted and may be used freely. */

#import "SFNormalBoard.h"

#import "SFThread.h"
#import "SFDocument.h"
#import "SFThreadFactory.h"
#import "Ch2Board.h"

@implementation SFNormalBoard

- (id) initWithURL: (NSURL*) url
			 title: (NSString*) title
{
	self = [self init];

	board_ = [[Ch2Board alloc] initWithURL: url];
	[board_ setDelegate: [NSApp delegate]];
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver: self
			   selector: @selector(finishParsingBoard:)
				   name: Ch2BoardDidFinishParsingNotification
				 object: board_];	

	[self setTitle: title];
	
	return self;
}

- (void) finishParsingBoard: (NSNotification*) n
{
	[threads_ removeAllObjects];

    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
    
    int i;
    for (i = 0; i < [board_ count]; i++) {
        NSDictionary* s = [board_ subjectAtIndex: i];
        
        SFThread* th;
        th = [factory threadWithBoard: [board_ URL]
                               number: [[s objectForKey: @"dat"] intValue]];
        [th setIndex: i + 1];
        [th setCount: [[s objectForKey: @"count"] intValue]];
        [th setSubject: [s objectForKey: @"subject"]];
        
        [threads_ addObject: th];
    }
	
    [factory garbageCollect];

    [[NSNotificationCenter defaultCenter]
        postNotificationName: SFBoardDidFinishUpdatingNotification
                      object: self
                    userInfo: nil];
}

#pragma mark Override

- (id) init
{
	self = [super init];
	
	url_ = nil;
	board_ = nil;
	threads_ = [[NSMutableArray alloc] init];
	
	return self;
}

- (void) dealloc
{
	// A board that is switched away from stops loading and reports nothing.
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[board_ cancel];
	[url_ release];
	[board_ release];
	[threads_ release];
	
	[super dealloc];
}

- (NSURL*) URL
{
	return [board_ URL];
}

- (NSArray*) threads
{
	return threads_;
}

- (void) update
{
	[board_ update];
}

@end
