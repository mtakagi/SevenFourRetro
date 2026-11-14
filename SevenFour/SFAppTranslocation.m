/* This file is not copyrighted and may be used freely. */

#import "SFAppTranslocation.h"

BOOL SFIsTranslocatedPath(NSString* path)
{
    // macOS has no public API for it; the place is recognized by its path,
    // as other apps do.
    return [[path pathComponents] containsObject:@"AppTranslocation"];
}
