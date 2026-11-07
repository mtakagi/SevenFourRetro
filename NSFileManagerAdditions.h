/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@interface NSFileManager(NSFileManagerCreateDirectoryRecursive)
- (BOOL) createDirectoryAtPath: (NSString*) path
                    attributes: (NSDictionary*) attrs
                     recursive: (BOOL) recursive;
@end
