/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class SFThread;

@interface SFThreadHTMLFormatter : NSObject {
	NSString* range_;
	SFThread* thread_;
}

+ (void) reloadTemplates;

- (void) setRange: (NSString*) range;

- (NSString*) formatThread: (SFThread*) th;
- (NSString*) formatThread: (SFThread*) th numbers: (NSArray*) numbers;
- (NSString*) formatMessage: (NSDictionary*) dict number: (int) number;

@end
