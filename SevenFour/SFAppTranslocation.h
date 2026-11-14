/* This file is not copyrighted and may be used freely. */

#import <Foundation/Foundation.h>

// YES when the app at path runs translocated (#68): opened where it was
// downloaded, before it was moved, macOS runs a quarantined app from a
// read-only place of its own, ".../AppTranslocation/<UUID>/d/SevenFour.app".
// That place goes away when the app is moved or replaced, which crashes the
// running app, and Sparkle can't update it there.
BOOL SFIsTranslocatedPath(NSString* path);
