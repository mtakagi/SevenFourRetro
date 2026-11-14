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


#import "Ch2BoardTree.h"
#import "Ch2Board.h"
#import "Ch2Thread.h"

#define _(s) NSLocalizedString((s), @"")

NSMutableDictionary* sharedBoardTree_;
NSMutableArray* sharedSmartBoards_;

NSString* SFBoardTreeDidChangeNotification = @"SFBoardTreeDidChangeNotification";

// The board list being downloaded, if any (one at a time for all windows).
static Ch2BoardTree* updatingBoardTree_ = nil;

@implementation SFDocument
+ (NSDictionary*)sharedBoardTree
{
    return sharedBoardTree_;
}

- (void)setBoard:(SFBoard*)board
{
    [self willChangeValueForKey:@"threadList"];

    [board_ release];
    board_ = [board retain];

    [self didChangeValueForKey:@"threadList"];
}

- (SFBoard*)board
{
    return board_;
}

- (void)setupSmartBoards
{
    SFSmartBoard* board;

    board = [[SFSmartBoard alloc] initWithQuery:@"SELECT * FROM threads WHERE rate > 0 ORDER BY rate DESC"
                                          title:@"Top Rated"];
    [sharedSmartBoards_ addObject:board];
    [board release];

    board = [[SFSmartBoard alloc] initWithQuery:@"SELECT * FROM threads WHERE atime IS NOT NULL ORDER BY atime DESC LIMIT 50"
                                          title:@"Recent Read"];
    [sharedSmartBoards_ addObject:board];
    [board release];
}

- (BOOL)isOffline
{
    return offline_;
}

- (void)setOffline:(BOOL)flag
{
    offline_ = flag;
}

- (BOOL)isWorking
{
    return workingJobs_ > 0;
}

- (NSDictionary*)boardTree
{
    return sharedBoardTree_;
}

+ (SFThread*)threadWithURL:(NSURL*)url
{
    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
    return [factory threadWithURL:url];
}

- (NSArray*)threadList
{
    return [board_ threads];
}

- (BOOL)openBoard:(NSURL*)url
            title:(NSString*)title
{
    if (workingJobs_ > 0)
        return FALSE;

    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

    if ([board_ isKindOfClass:[SFNormalBoard class]]) {
        // [threadList_ removeAllObjects];
    }
    [center removeObserver:self];
    [board_ release];

    // Create Board
    if ([[url scheme] isEqualToString:@"sevenfour"]) {
        board_ = [sharedSmartBoards_ objectAtIndex:[[url fragment] intValue]];
        [board_ retain];
    } else {
        if (offline_) {
            NSString* query = [NSString stringWithFormat:@"SELECT * FROM threads WHERE board = '%@' AND local > 0", url];
            board_ = [[SFSmartBoard alloc] initWithQuery:query
                                                   title:title];
        } else {
            board_ = [[SFNormalBoard alloc] initWithURL:url
                                                  title:title];
        }
    }

    [center addObserver:self
               selector:@selector(finishUpdatingBoard:)
                   name:SFBoardDidFinishUpdatingNotification
                 object:board_];

    [self updateBoard];

    [windowController_ synchronizeWindowTitleWithDocumentName];

    return YES;
}

- (void)updateBoard
{
    if (workingJobs_ > 0)
        return;

    if (!board_)
        return;

    [self willChangeValueForKey:@"isWorking"];
    {
        [[SFThread sharedDatabase] beginTransaction];
        [board_ update];
        workingJobs_++;
    }
    [self didChangeValueForKey:@"isWorking"];
}


- (void)finishUpdatingBoard:(NSNotification*)n
{
    [self willChangeValueForKey:@"threadList"];
    ;
    [self didChangeValueForKey:@"threadList"];

    [self willChangeValueForKey:@"isWorking"];
    {
        workingJobs_--;
        [[SFThread sharedDatabase] commitTransaction];
    }
    [self didChangeValueForKey:@"isWorking"];
}

+ (NSString*)pathOfBoardTreePList
{
    return [NSString stringWithFormat:@"%@/BoardTree.plist", SF_SUPPORT_DIRECTORY];
}

// Rebuilds the shared tree from the smart boards and the given board list
// (the "children" of a Ch2BoardTree).
+ (void)setupBoardTreeWithBoards:(NSArray*)boards
{
    NSMutableArray* ary = [NSMutableArray array];

    // Smart Board
    int i;
    for (i = 0; i < [sharedSmartBoards_ count]; i++) {
        SFSmartBoard* sb = [sharedSmartBoards_ objectAtIndex:i];

        NSString* url = [NSString stringWithFormat:@"sevenfour://smartboard/#%d", i];

        [ary addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                               _([sb title]), @"title", url, @"url",
                           nil]];
    }

    if (boards) {
        [ary addObjectsFromArray:boards];
    }
    [sharedBoardTree_ setObject:ary forKey:@"children"];
}

// Rebuilds the shared tree from the smart boards and the saved board list.
+ (void)setupBoardTree
{
    NSDictionary* tree;
    tree = [NSDictionary dictionaryWithContentsOfFile:[self pathOfBoardTreePList]];
    [self setupBoardTreeWithBoards:[tree objectForKey:@"children"]];
}

+ (void)showBoardTreeError:(NSError*)error
{
    NSWindow* window = [NSApp mainWindow];
    if (!window) {
        return;
    }
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:_(@"Failed to update the board list.")];
    [alert setInformativeText:[error localizedDescription]];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

// Downloads the board list in the background. When it arrives, it is saved
// to BoardTree.plist and SFBoardTreeDidChangeNotification is posted. On
// failure the saved list is kept.
+ (void)updateBoardTree
{
    if (updatingBoardTree_) {
        return;
    }

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* url = [NSURL URLWithString:[defaults stringForKey:@"URLOfBoardTree"]];
    if (!url) {
        return;
    }

    updatingBoardTree_ = [[Ch2BoardTree alloc] initWithURL:url];
    [updatingBoardTree_ updateWithCompletionHandler:^(NSError* error) {
        Ch2BoardTree* bt = [updatingBoardTree_ autorelease];
        updatingBoardTree_ = nil;

        if (error) {
            [self showBoardTreeError:error];
            return;
        }
        if (![[bt tree] writeToFile:[self pathOfBoardTreePList] atomically:YES]) {
            NSLog(@"SFDocument: Failed to save %@", [self pathOfBoardTreePList]);
        }
        [self setupBoardTreeWithBoards:[[bt tree] objectForKey:@"children"]];
        [[NSNotificationCenter defaultCenter]
            postNotificationName:SFBoardTreeDidChangeNotification
                          object:nil];
    }];
}

+ (BOOL)isUpdatingBoardTree
{
    return updatingBoardTree_ != nil;
}

- (IBAction)updateBoardTreePList
{
    [[self class] updateBoardTree];
}

- (NSURL*)URLOfBoard
{
    return [board_ URL];
}

- (NSURL*)initialURL
{
    return URLOfThread_;
}

- (NSString*)boardName
{
    return [board_ title];
}

#pragma mark Override
- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    DEBUG_LOG(@"SFDocument %p - init", self);
    [self setOffline:NO];

    // [[self class] sharedDatabase];

    // [self setupUserDefaults];

    // Smart Board
    if (!sharedSmartBoards_) {
        sharedSmartBoards_ = [[NSMutableArray alloc] init];
        [self setupSmartBoards];
    }

    // Board Tree
    if (!sharedBoardTree_) {
        sharedBoardTree_ = [[NSMutableDictionary alloc] init];
        [[self class] setupBoardTree];
        // First launch: show the smart boards now, the board list when it arrives.
        if (![[NSFileManager defaultManager] fileExistsAtPath:[[self class] pathOfBoardTreePList]]) {
            [[self class] updateBoardTree];
        }
    }

    workingJobs_ = 0;

    return self;
}

- (void)dealloc
{
    DEBUG_LOG(@"SFDocument %p - dealloc", self);

    [super dealloc];
}

- (void)makeWindowControllers
{
    DEBUG_LOG(@"SFDocument %p - makeWindowControllers", self);

    SFMainWindowController* wc;
    wc = [[SFMainWindowController alloc] init];

    [self addWindowController:wc];
    [wc release];

    windowController_ = [wc retain];
}

// Nothing is saved: a document is a window on the boards.
- (NSData*)dataOfType:(NSString*)type error:(NSError**)error
{
    return nil;
}

- (NSString*)displayName
{
    return [self boardName];
}

@end
