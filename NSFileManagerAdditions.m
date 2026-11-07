/* This file is not copyrighted and may be used freely. */

#import "NSFileManagerAdditions.h"

@implementation NSFileManager(NSFileManagerCreateDirectoryRecursive)
- (BOOL) createDirectoryAtPath: (NSString*) path
                    attributes: (NSDictionary*) attrs
                     recursive: (BOOL) recursive
{
    if (recursive) {
        if ([self fileExistsAtPath: path]) {
            return false;
        } else {
            NSString* parent = [path stringByDeletingLastPathComponent];
            [self createDirectoryAtPath: parent
                             attributes: attrs
                              recursive: true];
            [self createDirectoryAtPath: path
                             attributes: attrs];
        }
    } else {
        return [self createDirectoryAtPath: path attributes: attrs];
    }
}
@end
