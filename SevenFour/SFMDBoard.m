/* This file is not copyrighted and may be used freely. */

#import "SFMDBoard.h"

#import "SFThreadFactory.h"
#import "SFThread.h"
#import "SFAppController.h"


@implementation SFMDBoard

- (void)setQuery:(NSString*)query
{
    [query_ release];
    query_ = [query retain];

    [threads_ removeAllObjects];
}

- (NSArray*)threads
{
    return threads_;
}

- (NSString*)title
{
    return @"Spotlight";
}

#pragma mark Override
- (void)update
{
    NSPipe* pipe = [NSPipe pipe];

    NSTask* task = [[[NSTask alloc] init] autorelease];
    [task setStandardOutput:pipe];
    [task setLaunchPath:@"/usr/bin/mdfind"];

    [task setArguments:[NSArray arrayWithObject:query_]];
    [task launch];
    [task waitUntilExit];

    NSData* data = [[pipe fileHandleForReading] availableData];
    NSString* str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSArray* lines = [str componentsSeparatedByString:@"\n"];

    [self willChangeValueForKey:@"threads"];
    [threads_ removeAllObjects];

    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
    int i;
    for (i = 0; i < [lines count]; i++) {
        NSString* path = [lines objectAtIndex:i];

        NSURL* url = [SFAppController URLFromCachePath:path];
        if (url) {
            NSLog(@"url = %@", url);

            SFThread* th = [factory threadWithURL:url];
            [th loadMetadata];

            [threads_ addObject:th];
        }
    }

    [self didChangeValueForKey:@"threads"];
}

- (id)init
{
    self = [super init];

    query_ = nil;
    threads_ = [[NSMutableArray alloc] init];

    return self;
}

- (void)dealloc
{
    [query_ release];
    [threads_ release];

    [super dealloc];
}

@end
