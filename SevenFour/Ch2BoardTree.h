/* This file is not copyrighted and may be used freely. */
#import <Cocoa/Cocoa.h>

@interface Ch2BoardTree : NSObject {
    NSMutableDictionary* root_;
    NSURL* url_;
}

- (id) initWithURL: (NSURL*) url;
- (void) update;

- (NSDictionary*) tree;

@end
