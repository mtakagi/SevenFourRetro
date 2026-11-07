#import <Cocoa/Cocoa.h>
#import <WebKit/WebView.h>

@class SFThread;
@class SFThreadView;

@interface SFPopUpWindowController : NSWindowController {
    IBOutlet SFThreadView* threadView;
    BOOL loaded_;
}

- (WebView*) webView;

@end
