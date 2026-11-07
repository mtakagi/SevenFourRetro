/* This file is not copyrighted and may be used freely. */

#import "SFDocument.h"

#import <QuickLite/QuickLiteDatabaseExtras.h>

#import "SFAppController.h"
#import "SFMainWindowController.h"
#import "SFThread.h"
#import "SFThreadFactory.h"

#import "SFBoard.h"
#import "SFNormalBoard.h"
#import "SFSmartBoard.h"

#import "SFURLProtocol.h"

#import "Ch2BoardTree.h"
#import "Ch2Board.h"
#import "Ch2Thread.h"

#define _(s) NSLocalizedString((s), @"")

NSMutableDictionary* sharedBoardTree_;
NSMutableArray* sharedSmartBoards_;

@implementation SFDocument
+ (NSDictionary*) sharedBoardTree
{
	return sharedBoardTree_;
}

- (void) setBoard: (SFBoard*) board
{
    [self willChangeValueForKey: @"threadList"];
    
    [board_ release];
    board_ = [board retain];

    [self didChangeValueForKey: @"threadList"];
}

- (SFBoard*) board
{
    return board_;
}

- (void) setupSmartBoards
{
    SFSmartBoard* board;
	
	board = [[SFSmartBoard alloc] initWithQuery: @"SELECT * FROM threads WHERE rate > 0 ORDER BY rate DESC"
										  title: @"Top Rated"];
    [sharedSmartBoards_ addObject: board];
    [board release];
	
	board = [[SFSmartBoard alloc] initWithQuery: @"SELECT * FROM threads WHERE atime IS NOT NULL ORDER BY atime DESC LIMIT 50"
										  title: @"Recent Read"];
    [sharedSmartBoards_ addObject: board];
    [board release];
}

- (BOOL) isOffline
{
	return offline_;
}

- (void) setOffline: (BOOL) flag
{
	offline_ = flag;
}

- (BOOL) isWorking
{
    return workingJobs_ > 0;
}

- (NSDictionary*) boardTree
{
    return sharedBoardTree_;
}

+ (SFThread*) threadWithURL: (NSURL*) url
{
	SFThreadFactory* factory = [SFThreadFactory sharedFactory];
	return [factory threadWithURL: url];
}

- (NSArray*) threadList
{
	return [board_ threads];
}

- (BOOL) openBoard: (NSURL*) url
			 title: (NSString*) title
{
	if (workingJobs_ > 0) 
		return FALSE;
	
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

	if ([board_ isKindOfClass: [SFNormalBoard class]]) {
		// [threadList_ removeAllObjects];
	}
	[center removeObserver: self];
	[board_ release];
	
	// Create Board
    if ([[url scheme] isEqualToString: @"sevenfour"]) {
		board_ = [sharedSmartBoards_ objectAtIndex: [[url fragment] intValue]];
		[board_ retain];
    } else {
		if (offline_) {
			NSString* query = [NSString stringWithFormat: @"SELECT * FROM threads WHERE board = '%@' AND local > 0", url];
			board_ = [[SFSmartBoard alloc] initWithQuery: query
												   title: title];
		} else {
			board_ = [[SFNormalBoard alloc] initWithURL: url
												  title: title];
		}
    }
	
	[center addObserver: self
			   selector: @selector(finishUpdatingBoard:)
				   name: SFBoardDidFinishUpdatingNotification
				 object: board_];

	[self updateBoard];
	
	[windowController_ synchronizeWindowTitleWithDocumentName];
	
	return YES;
}

- (void) updateBoard
{
	if (workingJobs_ > 0) 
		return;
	
	if (! board_)
		return;
	
	[self willChangeValueForKey: @"isWorking"];
	{
		[[SFThread sharedDatabase] beginTransaction];
		[board_ update];
		workingJobs_++;
	}
    [self  didChangeValueForKey: @"isWorking"];        
}


- (void) finishUpdatingBoard: (NSNotification*) n
{
    [self willChangeValueForKey: @"threadList"];
	;
    [self didChangeValueForKey: @"threadList"];
    
    [self willChangeValueForKey: @"isWorking"];
	{
		workingJobs_--;
		[[SFThread sharedDatabase] commitTransaction];
	}
    [self  didChangeValueForKey: @"isWorking"];        
}

- (void) setupBoardTree
{
    NSMutableArray* ary = [NSMutableArray array];
    
	// Smart Board
	int i;
	for (i = 0; i < [sharedSmartBoards_ count]; i++) {
		SFSmartBoard* sb = [sharedSmartBoards_ objectAtIndex: i];
		
		NSString* url = [NSString stringWithFormat: @"sevenfour://smartboard/#%d", i];
		
		[ary addObject: [NSDictionary dictionaryWithObjectsAndKeys: 
			_([sb title]), @"title", url, @"url",
			nil]];
	}
	
    NSString* path;
    path = [NSString stringWithFormat: @"%@/BoardTree.plist",  SF_SUPPORT_DIRECTORY];
    
    NSDictionary* tree;
    tree = [[NSDictionary alloc] initWithContentsOfFile: path];
    if (! tree) {
        [self updateBoardTreePList];
    }
    tree = [[NSDictionary alloc] initWithContentsOfFile: path];

    [ary addObjectsFromArray: [tree objectForKey: @"children"]];
    [sharedBoardTree_ setObject: ary forKey: @"children"];
}

- (void) updateBoardTreePList
{
    NSString* path;
    path = [NSString stringWithFormat: @"%@/BoardTree.plist", SF_SUPPORT_DIRECTORY];

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    NSURL* url;
	url = [NSURL URLWithString: [defaults stringForKey: @"URLOfBoardTree"]];
        
    Ch2BoardTree* bt;
    bt = [[Ch2BoardTree alloc] initWithURL: url];
    [bt update];
    [[bt tree] writeToFile: path atomically: YES];

    [bt release];
}    

- (NSURL*) URLOfBoard
{
	return [board_ URL];
}

- (NSURL*) initialURL
{
	return URLOfThread_;
}

- (NSString*) boardName
{
	return [board_ title];
}

#pragma mark Override
- (id) init
{
    self = [super init];
    if (! self) {
        return nil;
    }
        
    DEBUG_LOG(@"SFDocument %p - init", self);
	[self setOffline: NO];
    
    // [[self class] sharedDatabase];
    
    // [self setupUserDefaults];
    
    // Smart Board
	if (! sharedSmartBoards_) {
		sharedSmartBoards_ = [[NSMutableArray alloc] init];
		[self setupSmartBoards];
	}
    
    // Board Tree
	if (! sharedBoardTree_) {
		sharedBoardTree_ = [[NSMutableDictionary alloc] init];
		[self setupBoardTree];
	}
	
    workingJobs_ = 0;
    
    return self;
}

- (void) dealloc
{
	DEBUG_LOG(@"SFDocument %p - dealloc", self);
	
	[super dealloc];
}

- (void) makeWindowControllers
{
	DEBUG_LOG(@"SFDocument %p - makeWindowControllers", self);
	
    NSWindowController* wc;
    wc = [[SFMainWindowController alloc] init];

    [self addWindowController: wc];
    [wc release];
	
	windowController_ = [wc retain];
}

- (NSData*) dataRepresentationOfType: (NSString*) type
{
    return nil;
}

- (NSString*) displayName
{
	return [self boardName];
}

@end
