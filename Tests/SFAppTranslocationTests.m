/* This file is not copyrighted and may be used freely. */

#import <XCTest/XCTest.h>
#import "SFAppTranslocation.h"

// Telling a translocated app by its path (#68).
@interface SFAppTranslocationTests : XCTestCase
@end

@implementation SFAppTranslocationTests

- (void)testTranslocatedPath
{
    XCTAssertTrue(SFIsTranslocatedPath(
        @"/private/var/folders/ab/cdefgh1234567/T/AppTranslocation/0A1B2C3D-4E5F-6789-ABCD-EF0123456789/d/SevenFour.app"));
}

- (void)testOtherPaths
{
    XCTAssertFalse(SFIsTranslocatedPath(@"/Applications/SevenFour.app"));
    XCTAssertFalse(SFIsTranslocatedPath(@"/Users/someone/Downloads/SevenFour.app"));
    // Only a whole path component counts.
    XCTAssertFalse(SFIsTranslocatedPath(@"/Users/someone/AppTranslocationNotes/SevenFour.app"));
    XCTAssertFalse(SFIsTranslocatedPath(@""));
}

@end
