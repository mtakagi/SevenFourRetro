/* This file is not copyrighted and may be used freely. */

#import "SFBoard.h"

@class Ch2Board;

@interface SFNormalBoard : SFBoard {
	NSURL* url_;
	Ch2Board* board_;
	NSMutableArray* threads_;
}


- (id) initWithURL: (NSURL*) url
			 title: (NSString*) title;

@end
