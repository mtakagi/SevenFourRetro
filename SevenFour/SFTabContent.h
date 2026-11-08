/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

// What the tab bar (TabbedWebView) needs from the view shown in a tab.
// The tab bar knows nothing of WebKit; SFThreadView (a WKWebView since
// #28) implements this (#27).
@protocol SFTabContent <NSObject>
// The tab's label; nil or empty shows "Untitled".
- (NSString*) tabTitle;
// YES while the page or the thread is loading (the tab shows a spinner).
- (BOOL) isTabLoading;
@end

// Posted by a tab content view (the object) when its title or loading
// state may have changed; the tab bar redraws.
extern NSString* SFTabContentDidChangeNotification;
