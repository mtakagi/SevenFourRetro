/* This file is not copyrighted and may be used freely. */

#import <Foundation/Foundation.h>

// Shift_JIS bytes of s; characters Shift_JIS can't hold become &#N; like a
// bbs.cgi page would write them.
NSData* SFTestShiftJIS(NSString* s);

// s escaped for an HTML attribute value (&, <, >, " and ' as &#x27;).
NSString* SFTestHTMLEscape(NSString* s);

// An application/x-www-form-urlencoded string decoded with Shift_JIS.
NSDictionary* SFTestDecodeForm(NSString* s);

// Contents of Tests/Fixtures/<name> (UTF-8 text), and as Shift_JIS.
NSString* SFTestFixture(NSString* name);
NSData* SFTestFixtureShiftJIS(NSString* name);

// A new empty directory under the temporary directory.
NSString* SFTestTemporaryDirectory(void);

// Runs the current run loop until condition() is true or timeout passes.
BOOL SFTestWaitFor(NSTimeInterval timeout, BOOL (^condition)(void));

// Removes the cookies the test server set for 127.0.0.1.
void SFTestClearLocalCookies(void);
