/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

extern NSString* SFBoardDidFinishUpdatingNotification;

@interface SFBoard : NSObject {
	NSString* title_;
}

- (NSString*) title;
- (void) setTitle: (NSString*) title;

- (NSURL*) URL;

- (NSArray*) threads;

- (void) update;

@end
