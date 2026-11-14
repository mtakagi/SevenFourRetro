/* This file is not copyrighted and may be used freely. */

#import "SFThread.h"

#import "SFAppController.h"
#import "Ch2Thread.h"
#import "Ch2DatParser.h"
#import "NSFileManagerAdditions.h"

#import <QuickLite/QuickLiteDatabase.h>
#import <QuickLite/QuickLiteCursor.h>
#import <QuickLite/QuickLiteDatabaseExtras.h>

#import <OgreKit/OgreKit.h>

NSString* SFThreadDidFinishUpdatingNotification = @"SFThreadDidFinishUpdatingNotification";

static QuickLiteDatabase* database_ = nil;

@implementation SFThread

+ (void)createTable
{
    NSLog(@"SFDocument + createTable");

    // Create Table
    // FIXME: Need to change column names...
    NSArray* columns = [NSArray arrayWithObjects:
            QLRecordUID,
        @"number", // -> index
        @"subject",
        @"dat", // -> number
        @"board",
        @"count", @"local", @"rate",
        @"live", @"new", @"comment",
        @"scroll",
        @"atime", // -> visitedTime ?
        nil];
    NSArray* columnTypes = [NSArray arrayWithObjects:
            QLRecordUIDDatatype,
        QLNumber, QLString, QLNumber,
        QLString,
        QLNumber, QLNumber, QLNumber,
        QLBoolean, QLBoolean, QLString,
        QLNumber, QLDateTime, nil];

    [database_ createTable:@"threads"
               withColumns:columns
              andDatatypes:columnTypes];

    // Create Index
    [database_ performQuery:
            @"CREATE UNIQUE INDEX IF NOT EXISTS threads_index ON threads (board, dat);"];
}

+ (void)openDatabase
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* path;

    path = [NSString stringWithFormat:@"%@/Index.db", SF_SUPPORT_DIRECTORY];
    BOOL found = [fm fileExistsAtPath:path];

    database_ = [[QuickLiteDatabase alloc] initWithFile:path];
    [database_ open:YES];

    if (!found) {
        [self createTable];
    }
}

+ (QuickLiteDatabase*)sharedDatabase
{
    if (!database_) {
        [self openDatabase];
    }

    return database_;
}

- (void)setOffline:(BOOL)flag
{
    offline_ = flag;
}

- (BOOL)offline
{
    return offline_;
}

- (BOOL)isEqualToThread:(SFThread*)th
{
    NSString* a = [[self URLOfDat] absoluteString];
    NSString* b = [[th URLOfDat] absoluteString];

    return [a isEqualToString:b];
}

- (NSString*)cachePath
{
#ifdef COMPAT
    NSString* path;

    path = [NSString stringWithFormat:@"%@/Thread/%@/%@/%d.dat",
        SF_SUPPORT_DIRECTORY, [board_ host], [board_ path], number_];

    return [path stringByStandardizingPath];
#else
    NSString* path;
    NSMutableString* host = [NSMutableString stringWithString:[board_ host]];

    [host replaceOccurrencesOfRegularExpressionString:@"^.+?\\."
                                           withString:@""
                                              options:0
                                                range:NSMakeRange(0, [host length])];

    path = [NSString stringWithFormat:@"%@/Thread/%@/%@/%d.dat",
        SF_SUPPORT_DIRECTORY, host, [board_ path], number_];

    return [path stringByStandardizingPath];
#endif
}

- (void)removeCache
{
    // Flag
    cacheDeleted_ = YES;

    // Remove file
    NSFileManager* manager = [NSFileManager defaultManager];
    [manager removeItemAtPath:[self cachePath] error:NULL];

    // Clear metadata
    local_ = 0;

    [self saveMetadata];
}

// local, rate, scroll
- (void)loadLightMetadata
{
    NSString* query;
    // FIXME
    query = [NSString stringWithFormat:
            @"SELECT subject, local, rate, scroll FROM threads WHERE board = '%@' AND dat = %d",
        [board_ absoluteString], number_];

    QuickLiteDatabase* db = [[self class] sharedDatabase];
    QuickLiteCursor* cursor = [db performQuery:query];

    if ([cursor rowCount] == 0) {
        query = [NSString stringWithFormat:
                @"INSERT OR IGNORE INTO threads (dat, board, subject, count, number) VALUES (%d, '%@', '%@', %d, %d)",
            number_, [board_ absoluteString],
            [QuickLiteDatabase prepareStringForQuery:subject_],
            count_, number_];
        [db performQuery:query];

        isNew_ = YES;
        local_ = 0;
        rate_ = 0;
        comment_ = [[NSMutableString alloc] init];
    } else {
        isNew_ = NO;

        QuickLiteRow* row = [cursor rowAtIndex:0];

        id value;

        value = [row valueForColumn:@"threads.local"];
        if (value != [NSNull null]) {
            local_ = [value intValue];
        }

        value = [row valueForColumn:@"threads.rate"];
        if (value != [NSNull null]) {
            rate_ = [value intValue];
        }

        [self setSubject:[row valueForColumn:@"threads.subject"]];
    }
}

// Load local, rate, subject, number, count
- (void)loadMetadata
{
    NSString* query;

    query = [NSString stringWithFormat:
            @"SELECT * FROM threads WHERE board = '%@' AND dat = %d",
        [board_ absoluteString], number_];

    QuickLiteDatabase* db = [[self class] sharedDatabase];
    QuickLiteCursor* cursor = [db performQuery:query];

    if ([cursor rowCount] != 1) {
        return;
    }
    QuickLiteRow* row = [cursor rowAtIndex:0];

    id value;
    // NSLog(@"row = %@", row);

    value = [row valueForColumn:@"threads.local"];
    if (value != [NSNull null]) {
        local_ = [value intValue];
    }

    value = [row valueForColumn:@"threads.rate"];
    if (value != [NSNull null]) {
        rate_ = [value intValue];
    }

    [self setSubject:[row valueForColumn:@"threads.subject"]];

#if 0
    value = [row valueForColumn: @"threads.number"];
    if (value != [NSNull null]) {
        [self setIndex: [value intValue]];
    }
#endif

    value = [row valueForColumn:@"threads.count"];
    if (value != [NSNull null]) {
        [self setCount:[value intValue]];
    }

    [comment_ release];
    comment_ = [[row stringForColumn:@"threads.comment"] retain];
}

- (void)saveMetadata
{
    // NSLog(@"SFThread - saveMetadata");

    NSString* query;
    query = [NSString stringWithFormat:
            @"SELECT * FROM threads WHERE board = '%@' AND dat = %d",
        [board_ absoluteString], number_];

    QuickLiteDatabase* db = [[self class] sharedDatabase];
    QuickLiteCursor* cursor = [db performQuery:query];

    if ([cursor rowCount] != 1) {
        return;
    }

    [cursor setValue:subject_
           forColumn:@"threads.subject"];

    [cursor setValue:[NSNumber numberWithInt:local_] forColumn:@"threads.local"];
    [cursor setValue:[NSNumber numberWithInt:rate_] forColumn:@"threads.rate"];
    [cursor setValue:[NSNumber numberWithInt:count_] forColumn:@"threads.count"];
    [cursor setValue:[NSNumber numberWithInt:index_] forColumn:@"threads.number"];

    if (visitedTime_) {
        [cursor setValue:visitedTime_ forColumn:@"threads.atime"];
    }

    [cursor save];
}

- (id)initWithNumber:(int)number
               board:(NSURL*)board
{
    self = [self init];

    number_ = number;
    board_ = [board retain];

    [self loadLightMetadata];

    return self;
}

- (BOOL)isNew
{
    return isNew_;
}

- (int)index
{
    return index_;
}

- (void)setIndex:(int)index
{
    index_ = index;
}

- (NSString*)subject
{
    return subject_;
}

- (void)setSubject:(NSString*)s
{
    [subject_ release];
    subject_ = [s retain];
}

- (int)count
{
    return count_;
}

- (void)setCount:(int)count
{
    count_ = count;
}

- (int)number
{
    return number_;
}

- (NSDate*)creationDate
{
    return [NSDate dateWithTimeIntervalSince1970:[self number]];
}

- (float)pace
{
    float interval = [[self creationDate] timeIntervalSinceNow] / (60.0 * 60.0);
    if (interval != 0) {
        return [self count] / -interval;
    } else {
        return 0;
    }
}

- (int)local
{
    return local_;
}

- (int)delta
{
    if ([self local] == 0)
        return -1;
    else
        return [self count] - [self local];
}

- (void)setRate:(int)rate
{
    if (rate_ > 5) {
        rate_ = 5;
    } else {
        rate_ = rate;
    }
    [self saveMetadata];
}

- (int)rate
{
    return rate_;
}

- (int)newCount
{
    if (thread_) {
        return [thread_ newCount];
    } else {
        return -1;
    }
}

- (NSURL*)URLOfBoard
{
    return board_;
}

- (NSURL*)URLOfHTML
{
    return [Ch2Thread URLOfHTMLWithBoard:board_ number:number_];
}

- (NSURL*)URLOfDat
{
    return [Ch2Thread URLOfDatWithBoard:board_ number:number_];
}

- (int)countOfID:(NSString*)key
{
    NSNumber* number = [idCounts_ objectForKey:key];
    return [number intValue];
}

- (void)countAllIDs
{
    [idCounts_ removeAllObjects];

    int i;
    for (i = 0; i < [self count]; i++) {
        NSDictionary* message = [self messageAtIndex:i];
        NSString* s = [message objectForKey:Ch2MessageID];
        if (s && ![s isEqualTo:@"???"]) {
            int n = [[idCounts_ objectForKey:s] intValue];
            [idCounts_ setObject:[NSNumber numberWithInt:n + 1]
                          forKey:s];
        }
    }
}

- (void)threadFinishUpdating:(NSNotification*)n
{
    DEBUG_LOG(@"SFThread %p - threadFinishUpdating:", self);

    [self setSubject:[thread_ subject]];

    count_ = [thread_ count];
    local_ = count_;

    [self saveMetadata];

    [self countAllIDs];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SFThreadDidFinishUpdatingNotification
                      object:self
                    userInfo:nil];

    // [thread_ setDelegate: nil];
}

// Create the underlying Ch2Thread on demand. It used to be created only by
// -update, so posting to a thread that had not been updated yet messaged nil
// and silently reported success.
- (void)prepareCh2Thread
{
    if (cacheDeleted_) {
        // An update still running would write the deleted log back.
        [thread_ cancel];
        [thread_ release];
        thread_ = nil;
        cacheDeleted_ = NO;
    }

    if (thread_ == nil) {
        thread_ = [[Ch2Thread alloc] initWithNumber:number_ board:board_];
        [thread_ setUserAgent:SEVENFOUR_USER_AGENT];

        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(threadFinishUpdating:)
                       name:Ch2ThreadDidFinishUpdatingNotification
                     object:thread_];
        [center addObserver:self
                   selector:@selector(threadFinishUpdating:)
                       name:Ch2ThreadConnectionDidFailNotification
                     object:thread_];

        [thread_ setDelegate:self];
        DEBUG_LOG(@"SFThread %p - [thread_ count] = %d", self, [thread_ count]);
    }
}

- (void)update
{
    DEBUG_LOG(@"SFThread %p - update", self);

    [self prepareCh2Thread];

#if 1
    if (!offline_) {
        [thread_ update];
    } else {
        [self threadFinishUpdating:nil];
    }
#else
    if ([thread_ count] >= 1000) {
        offline_ = YES;
    }

    if (!offline_) {
        [thread_ update];
    } else {
        [self threadFinishUpdating:nil];
    }
#endif

    [visitedTime_ release];
    visitedTime_ = [[NSDate date] retain];
}

- (NSDictionary*)messageAtIndex:(int)index
{
    if (0 <= index && index < [self count])
        return [thread_ messageAtIndex:index];
    else
        return nil;
}

- (NSData*)threadLoadCache:(Ch2Thread*)t
{
    return [NSData dataWithContentsOfFile:[self cachePath]];
}

- (void)thread:(Ch2Thread*)th writeCache:(NSData*)data
{
    // The log was deleted while this update was running: don't bring it back.
    if (cacheDeleted_) {
        return;
    }
    NSFileManager* manager;
    manager = [NSFileManager defaultManager];
    [manager createDirectoryAtPath:[[self cachePath] stringByDeletingLastPathComponent]
                        attributes:nil
                         recursive:true];

    if (![data writeToFile:[self cachePath] atomically:YES]) {
        NSLog(@"SFThread: Failed to write %@", [self cachePath]);
    } else {
        // NSLog(@"Cache Wrote: %@", [self cachePath]);
    }
}

- (NSDate*)threadCacheModificationDate:(Ch2Thread*)t
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSDictionary* attr;
    // Follows a symbolic link, as fileAttributesAtPath:traverseLink: did.
    attr = [manager attributesOfItemAtPath:[[self cachePath] stringByResolvingSymlinksInPath]
                                     error:NULL];
    return [attr objectForKey:NSFileModificationDate];
}

- (BOOL)postWithName:(NSString*)name
                 mail:(NSString*)mail
                 body:(NSString*)body
    completionHandler:(Ch2ThreadPostHandler)handler
{
    if (poster_ == nil) {
        poster_ = [[Ch2Thread alloc] initWithNumber:number_ board:board_];
        [poster_ setUserAgent:SEVENFOUR_USER_AGENT];
    }

    // poster_ refuses a second post while one is being sent.
    return [poster_ postWithName:name
                            mail:mail
                            body:body
               completionHandler:handler];
}

- (NSString*)alertMessage
{
    return [poster_ alertMessage];
}

#pragma mark Override

- (id)init
{
    self = [super init];

    board_ = nil;
    number_ = 0;

    subject_ = nil;
    count_ = 0;
    index_ = 0;

    thread_ = nil;

    rate_ = 0;
    local_ = 0;

    visitedTime_ = nil;
    cacheDeleted_ = NO;
    poster_ = nil;

    offline_ = NO;

    idCounts_ = [[NSMutableDictionary alloc] init];

    return self;
}

- (void)dealloc
{
    // [self saveMetadata];

    // Becaouse [thread_ delegate] == self!
    [self retain];
    [thread_ setDelegate:nil];
    [thread_ release];
    [poster_ release];

    [board_ release];
    [subject_ release];
    [comment_ release];

    [super dealloc];
}

@end
