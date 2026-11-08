#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class SFThread;
@class SFThreadView;

@interface SFPopUpWindowController : NSWindowController <WebFrameLoadDelegate> {
    IBOutlet SFThreadView* threadView;
    BOOL loaded_;
}

- (WebView*) webView;

@end
