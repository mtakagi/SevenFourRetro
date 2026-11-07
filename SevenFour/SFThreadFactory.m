/* This file is not copyrighted and may be used freely. */

#import "SFThreadFactory.h"

#import "SFAppController.h"
#import "SFThread.h"
#import "Ch2Thread.h"

SFThreadFactory* instance_ = nil;

@implementation SFThreadFactory

+ (SFThreadFactory*) sharedFactory
{
    if (! instance_) {
        instance_ = [[self alloc] init];
    }
    
    return instance_;
}

- (SFThread*) threadWithBoard: (NSURL*) board
                       number: (int) number
{
    NSString* key = [[Ch2Thread URLOfDatWithBoard: board 
                                           number: number] absoluteString];
	
    SFThread* th = [pool_ objectForKey: key];
    
    if (! th) {
        th = [[SFThread alloc] initWithNumber: number
										board: board];
        [pool_ setObject: th forKey: key];
        [th release];
    }
    
    return th;
}

- (SFThread*) threadWithURL: (NSURL*) url
{
	NSArray* ary = [[url path] pathComponents];
	NSURL* board;
	
	if ([ary count] >= 5 &&
		[[ary objectAtIndex: 1] isEqualTo: @"test"] &&
		[[ary objectAtIndex: 2] isEqualTo: @"read.cgi"]) {
		/*
		 0:
		 1: test
		 2: read.cgi
		 3: BOARD
		 4: NUMBER
		 */
		board = [NSURL URLWithString: 
			[NSString stringWithFormat: @"%@://%@/%@", SFSchemeOfURL(url), [url host], [ary objectAtIndex: 3]]];
		
		return [self threadWithBoard: board
							  number: [[ary objectAtIndex: 4] intValue]];		
	} else if ([ary count] == 4 &&
			   [[ary objectAtIndex: 2] isEqualTo: @"dat"]) {
		/*
		 0:
		 1: BOARD
		 2: dat
		 3: NUMBER.dat
		 */
		board = [NSURL URLWithString: 
			[NSString stringWithFormat: @"%@://%@/%@", SFSchemeOfURL(url), [url host], [ary objectAtIndex: 1]]];
		NSString* last = [ary objectAtIndex: 3];
		return [self threadWithBoard: board
							  number: [[last substringToIndex: [last length] - 4] intValue]];		
	} else {
		return nil;
	}
}

- (void) garbageCollect
{
	int deleted = 0;
    
    NSArray* ary = [pool_ allKeys];
    
    int i;
    for (i = 0; i < [ary count]; i++) {
        id key = [ary objectAtIndex: i];
        id obj = [pool_ objectForKey: key];
        
        // Object's owner is this pool?
        if (obj && [obj retainCount] == 1) {
            [pool_ removeObjectForKey: key];
            deleted++;
        } else {
        }
    }
	
    DEBUG_LOG(@"SFThreadFactory: saved = %d, deleted = %d", [pool_ count], deleted);
}

- (void) saveAllMetadata
{
    NSArray* ary = [pool_ allKeys];
    
    int i;
    for (i = 0; i < [ary count]; i++) {
        id key = [ary objectAtIndex: i];
        SFThread* th = (SFThread*) [pool_ objectForKey: key];

        [th saveMetadata];
    }
}

- (id) init
{
    self = [super init];
    
    pool_ = [[NSMutableDictionary alloc] init];
    
    return self;
}


@end
