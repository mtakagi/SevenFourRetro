/* This file is not copyrighted and may be used freely. */

#import <WebKit/WebKit.h>
#import "SFTabContent.h"

@class SFThread;
@class SFThreadView;

// What SFThreadView asks of its owner (SFMainWindowController).
@interface NSObject (SFThreadViewDelegate)
// A link was followed or a page is about to load. YES loads url in the
// view; NO means the owner handled it (opened a thread, a post window, the
// browser...). inBackground is YES when Command was held.
- (BOOL) threadView: (SFThreadView*) view
      shouldLoadURL: (NSURL*) url
       inBackground: (BOOL) inBackground;
// The mouse moved onto a link (url) or off links (nil). option is YES when
// Option was held.
- (void) threadView: (SFThreadView*) view
       mouseOverURL: (NSURL*) url
              label: (NSString*) label
             option: (BOOL) option;
// A page started or finished loading.
- (void) threadViewDidStartLoading: (SFThreadView*) view;
- (void) threadViewDidFinishLoading: (SFThreadView*) view;
@end

// A thread shown in a tab, in a WKWebView (#28). Pages come from
// SFThreadSchemeHandler (sevenfour://). See docs/wkwebview-migration.md.
@interface SFThreadView : WKWebView <SFTabContent, WKNavigationDelegate, WKUIDelegate> {
    int visibleCount_;
	SFThread* thread_;
    BOOL isFragmentLoading_;
    id threadDelegate_;   // not retained (the owner retains the view)
    id hoverHandler_;     // receives the skin's hover messages
}

- (id) initWithFrame: (NSRect) frame;

- (void) setThreadDelegate: (id) delegate;

- (SFThread*) thread;
- (void) loadThreadWithURL: (NSURL*) url;
- (void) updateThread;
// YES from -updateThread until the thread finishes updating.
- (BOOL) isUpdatingThread;

// The URL of the page shown (an internal sevenfour:// URL), or nil.
- (NSURL*) pageURL;

// Finds string in the page and selects it, searching forward or backward
// from the selection, without wrapping around (case-insensitive).
- (void) findString: (NSString*) string forward: (BOOL) forward;

@end
