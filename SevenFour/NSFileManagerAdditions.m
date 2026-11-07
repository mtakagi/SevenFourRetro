/* This file is not copyrighted and may be used freely. */

#import "NSFileManagerAdditions.h"

@implementation NSFileManager(NSFileManagerCreateDirectoryRecursive)
- (BOOL) createDirectoryAtPath: (NSString*) path
                    attributes: (NSDictionary*) attrs
                     recursive: (BOOL) recursive
{
    if (recursive && [self fileExistsAtPath: path]) {
        return NO;
    }
    return [self createDirectoryAtPath: path
           withIntermediateDirectories: recursive
                            attributes: attrs
                                 error: NULL];
}
@end
