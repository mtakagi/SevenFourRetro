/* This file is not copyrighted and may be used freely. */

#import "SFBoard.h"

NSString* SFBoardDidFinishUpdatingNotification = @"SFBoardDidFinishUpdatingNotification";

@implementation SFBoard

- (NSString*) title
{
	return title_;
}

- (void) setTitle: (NSString*) title
{
	title_ = [title retain];
}

- (NSArray*) threads;
{
	return nil;
}

- (NSURL*) URL
{
	return nil;
}

- (void) update
{
	;
}

- (id) init
{
	self = [super init];
	
	title_ = nil;
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

@end
