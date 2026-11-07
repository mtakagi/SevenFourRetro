/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@class WebView;

@interface TabbedWebView : NSView {
	NSObject* delegate_;
	int selected_;
	int tabWidth_;
    
    NSMutableArray* webViews_;
    NSMutableArray* buttons_;
    NSMutableArray* indicators_;
}

- (WebView*) selectedWebView;
- (WebView*) webViewAtIndex: (unsigned) index;
- (int) indexOfWebView: (WebView*) wv;
- (int) numberOfWebViews;
- (NSArray*) webViews;

- (void) addWebView: (WebView*) wv;
- (void) removeWebView: (WebView*) wv;
- (void) selectWebView: (WebView*) wv;
- (void) selectWebViewAtIndex: (int) n;

- (void) setDelegate: (NSObject*) delegate;
- (NSObject*) delegate;
@end

@interface NSObject(TabbedWebViewDelegate)
- (void) tabbedWebView: (TabbedWebView*) twv
	  didSelectWebView: (WebView*) wv;
@end

