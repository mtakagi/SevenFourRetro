/* This file is not copyrighted and may be used freely. */

#import <Foundation/Foundation.h>

// Decodes the Shift_JIS (Windows code page 932, as 2ch/5ch use it) of
// subject.txt, bbsmenu.html, DAT and bbs.cgi pages.
//
// Unlike -[NSString initWithData:encoding:], a few bad bytes don't lose
// the whole text:
// - a byte that can't start a character, a lead byte whose next byte
//   can't follow it, and a code with no character all become U+FFFD,
//   and decoding goes on after them;
// - a character cut off at the end (a lone lead byte) is dropped, so a
//   reply cut in the middle of a character keeps what came before.
// Returns nil only for nil data.
NSString* Ch2StringFromShiftJIS(NSData* data);
