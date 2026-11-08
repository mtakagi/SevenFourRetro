/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class SFThread;

@interface SFThreadHTMLFormatter : NSObject {
	NSString* range_;
	SFThread* thread_;
}

+ (void) reloadTemplates;

// The file of a skin file name ("sevenfour.css", or the path of a
// sevenfour://skin/ URL): the user's skin (Application Support) first, then
// the app's. nil when there is none.
+ (NSString*) pathOfSkinFile: (NSString*) name;

- (void) setRange: (NSString*) range;

- (NSString*) formatThread: (SFThread*) th;
- (NSString*) formatThread: (SFThread*) th numbers: (NSArray*) numbers;
- (NSString*) formatMessage: (NSDictionary*) dict number: (int) number;

@end
