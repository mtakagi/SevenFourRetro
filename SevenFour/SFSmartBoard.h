/* This file is not copyrighted and may be used freely. */

#import "SFBoard.h"

@interface SFSmartBoard : SFBoard {
	NSString* query_;
	NSMutableArray* threads_;
}

- (id) initWithQuery: (NSString*) query
			   title: (NSString*) title;
- (void) setQuery: (NSString*) query;
- (NSArray*) threads;

@end
