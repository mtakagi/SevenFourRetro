/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class SFPageView;

// A pop-up window of messages, shown while the mouse is over a reply or an
// ID. It closes when the mouse leaves it (TemporaryPanel) and fits its
// height to the messages. Made in code; it was PopUpWindow.nib (#28).
@interface SFPopUpWindowController : NSWindowController {
    SFPageView* pageView_;
}

// A pop-up window at frame (screen coordinates; the height is adjusted to
// the page once it has loaded).
- (id) initWithFrame: (NSRect) frame;

- (SFPageView*) pageView;

@end
