/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class SFThread;

@interface SFThreadFactory : NSObject {
    NSMutableDictionary* pool_;
}

+ (SFThreadFactory*)sharedFactory;

- (SFThread*)threadWithBoard:(NSURL*)board
                      number:(int)number;
- (SFThread*)threadWithURL:(NSURL*)url;
- (void)garbageCollect;
- (void)saveAllMetadata;

@end
