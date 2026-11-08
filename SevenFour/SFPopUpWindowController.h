#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class SFThread;

@interface SFPopUpWindowController : NSWindowController <WebFrameLoadDelegate> {
    // A WebKit 1 WebView until the pop-up moves to WKWebView (#28).
    IBOutlet WebView* threadView;
    BOOL loaded_;
}

- (WebView*) webView;

@end
