/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>


@interface FontButton : NSButton {
	NSFont* font_;
	NSString* familyKey_;
	NSString* pointSizeKey_;
}

- (void) setFamilyKey: (NSString*) key;
- (void) setPointSizeKey: (NSString*) key;

@end
