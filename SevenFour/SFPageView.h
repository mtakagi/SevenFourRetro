/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class SFPageView;

// What SFPageView asks of its owner (SFMainWindowController).
@interface NSObject (SFPageViewDelegate)
// A link was followed or a page is about to load. YES loads url in the
// view; NO means the owner handled it (opened a thread, a post window, the
// browser...). inBackground is YES when Command was held.
- (BOOL) pageView: (SFPageView*) view
    shouldLoadURL: (NSURL*) url
     inBackground: (BOOL) inBackground;
// The mouse moved onto a link (url) or off links (nil). option is YES when
// Option was held.
- (void) pageView: (SFPageView*) view
     mouseOverURL: (NSURL*) url
            label: (NSString*) label
           option: (BOOL) option;
@end

// Posted by an SFPageView made with reportsContentHeight when the height of
// its page changes. userInfo: SFPageViewContentHeightKey (NSNumber, points).
extern NSString* const SFPageViewContentHeightDidChangeNotification;
extern NSString* const SFPageViewContentHeightKey;

// A page of messages in a WKWebView (#28): the thread in a tab
// (SFThreadView) and the message pop-up window (SFPopUpWindowController).
// sevenfour:// URLs (threads and the skin) come from SFThreadSchemeHandler.
// Links and the link under the mouse are told to the delegate; WKWebView has
// no API for the latter, so a user script reports it. See
// docs/wkwebview-migration.md.
@interface SFPageView : WKWebView <WKNavigationDelegate, WKUIDelegate> {
    id pageDelegate_;     // not retained (the owner outlives the view)
    id messageHandler_;   // receives the user scripts' messages
}

- (id) initWithFrame: (NSRect) frame;
// reportsContentHeight: post SFPageViewContentHeightDidChangeNotification.
- (id) initWithFrame: (NSRect) frame reportsContentHeight: (BOOL) reports;

- (void) setPageDelegate: (id) delegate;
- (id) pageDelegate;

// Finds string in the page and selects it, searching forward or backward
// from the selection, without wrapping around (case-insensitive).
- (void) findString: (NSString*) string forward: (BOOL) forward;

@end
