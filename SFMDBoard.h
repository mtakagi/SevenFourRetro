/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import "SFBoard.h"

@interface SFMDBoard : SFBoard {
	NSMutableArray* threads_;
    NSString* query_;
}

- (void) setQuery: (NSString*) query;

@end
