/* This file is not copyrighted and may be used freely. */

#import "SFThreadFactory.h"

#import "SFAppController.h"
#import "SFThread.h"
#import "Ch2Thread.h"

SFThreadFactory* instance_ = nil;

@implementation SFThreadFactory

+ (SFThreadFactory*)sharedFactory
{
    if (!instance_) {
        instance_ = [[self alloc] init];
    }

    return instance_;
}

- (SFThread*)threadWithBoard:(NSURL*)board
                      number:(int)number
{
    NSString* key = [[Ch2Thread URLOfDatWithBoard:board
                                           number:number] absoluteString];

    SFThread* th = [pool_ objectForKey:key];

    if (!th) {
        th = [[SFThread alloc] initWithNumber:number
                                        board:board];
        [pool_ setObject:th forKey:key];
        [th release];
    }

    return th;
}

// A web URL with the host, port and path of an internal sevenfour:// URL.
static NSURL* webURLOfInternalURL(NSURL* url, NSString* scheme)
{
    NSURLComponents* c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    [c setScheme:scheme];
    return [c URL];
}

- (SFThread*)threadWithURL:(NSURL*)url
{
    if ([[url scheme] isEqualToString:@"sevenfour"]) {
        // An internal URL has no scheme of its own. The thread it shows was
        // opened from a web URL first, so look for that one (an http board,
        // such as a local test server, included) before assuming https.
        NSArray* schemes = [NSArray arrayWithObjects:@"https", @"http", nil];
        int i;
        for (i = 0; i < [schemes count]; i++) {
            int number = 0;
            NSURL* board = [Ch2Thread boardOfThreadURL:webURLOfInternalURL(url, [schemes objectAtIndex:i])
                                                number:&number];
            if (!board) {
                return nil;
            }
            NSString* key = [[Ch2Thread URLOfDatWithBoard:board number:number] absoluteString];
            SFThread* th = [pool_ objectForKey:key];
            if (th) {
                return th;
            }
        }
        url = webURLOfInternalURL(url, @"https");
    }

    int number = 0;
    NSURL* board = [Ch2Thread boardOfThreadURL:url number:&number];
    if (!board) {
        return nil;
    }
    return [self threadWithBoard:board number:number];
}

- (void)garbageCollect
{
    int deleted = 0;

    NSArray* ary = [pool_ allKeys];

    int i;
    for (i = 0; i < [ary count]; i++) {
        id key = [ary objectAtIndex:i];
        id obj = [pool_ objectForKey:key];

        // Object's owner is this pool?
        if (obj && [obj retainCount] == 1) {
            [pool_ removeObjectForKey:key];
            deleted++;
        } else {
        }
    }

    DEBUG_LOG(@"SFThreadFactory: saved = %d, deleted = %d", [pool_ count], deleted);
}

- (void)saveAllMetadata
{
    NSArray* ary = [pool_ allKeys];

    int i;
    for (i = 0; i < [ary count]; i++) {
        id key = [ary objectAtIndex:i];
        SFThread* th = (SFThread*) [pool_ objectForKey:key];

        [th saveMetadata];
    }
}

- (id)init
{
    self = [super init];

    pool_ = [[NSMutableDictionary alloc] init];

    return self;
}


@end
