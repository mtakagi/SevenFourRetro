/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@interface SearchableArrayController : NSArrayController {
    NSString* keyword_;
}

- (IBAction) search: (id) sender;

@end

