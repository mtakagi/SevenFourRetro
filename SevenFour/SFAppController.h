/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

extern NSString* SF_SUPPORT_DIRECTORY;

#define SEVENFOUR_USER_AGENT @"Monazilla/1.00 SevenFour/1.3"

#define DEBUG_LOG(format, ...)
// #define DEBUG_LOG(format, ...) NSLog((format), __VA_ARGS__)

@interface SFAppController : NSObject <NSApplicationDelegate> {
    id updaterController_;   // SPUStandardUpdaterController (Sparkle, #61)
}

- (IBAction) reloadSkin: (id) sender;
+ (NSURL*) URLFromCachePath: (NSString*) path;

@end
