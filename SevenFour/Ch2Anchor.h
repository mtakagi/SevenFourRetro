/* This file is not copyrighted and may be used freely. */

#import <Foundation/Foundation.h>

// Anchors to other messages in a message's body (HTML, as in the DAT):
// ">>12", ">>1-5", ">>1,3", written with half-width > (&gt; in the DAT) or
// full-width ＞ or ≫, and half-width or full-width digits ("＞＞７９０") (#70).
// Each becomes a link to "#<numbers>" with the numbers in half-width ASCII
// ("#790", "#1-5"), which the pop-up of messages reads; the text shown is
// left as written.
NSString* Ch2MarkupAnchors(NSString* body);
