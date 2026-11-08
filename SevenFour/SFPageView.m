/* This file is not copyrighted and may be used freely. */

#import "SFPageView.h"

#import "SFThreadSchemeHandler.h"

NSString* const SFPageViewContentHeightDidChangeNotification = @"SFPageViewContentHeightDidChangeNotification";
NSString* const SFPageViewContentHeightKey = @"height";

// The names the user scripts post to.
static NSString* const HOVER_MESSAGE = @"sevenfourHover";
static NSString* const HEIGHT_MESSAGE = @"sevenfourHeight";

// Reports the link under the mouse: {href, label, option}, or null off links.
static NSString* const HOVER_SCRIPT =
    @"(function () {\n"
    @"  var last = null;\n"
    @"  document.addEventListener('mouseover', function (e) {\n"
    @"    var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;\n"
    @"    var href = a ? a.href : null;\n"
    @"    if (href === last) return;\n"
    @"    last = href;\n"
    @"    window.webkit.messageHandlers.sevenfourHover.postMessage(\n"
    @"      a ? { href: href, label: a.textContent, option: e.altKey } : null);\n"
    @"  }, true);\n"
    @"})();\n";

// Reports the height of the page's content (the body and its margins), now
// and whenever it changes.
static NSString* const HEIGHT_SCRIPT =
    @"(function () {\n"
    @"  var body = document.body;\n"
    @"  if (! body) return;\n"
    @"  function report() {\n"
    @"    var s = window.getComputedStyle(body);\n"
    @"    var h = body.getBoundingClientRect().height\n"
    @"      + parseFloat(s.marginTop) + parseFloat(s.marginBottom);\n"
    @"    window.webkit.messageHandlers.sevenfourHeight.postMessage(Math.ceil(h));\n"
    @"  }\n"
    @"  if (window.ResizeObserver) new ResizeObserver(report).observe(body);\n"
    @"  report();\n"
    @"})();\n";

// Holds the view without retaining it: the user content controller retains
// its message handlers, and the view retains the controller.
@interface SFPageViewMessageHandler : NSObject <WKScriptMessageHandler> {
@public
    SFPageView* view_;
}
@end

@interface SFPageView (Messages)
- (void) hoverMessage: (id) body;
- (void) heightMessage: (id) body;
@end

@implementation SFPageViewMessageHandler
- (void) userContentController: (WKUserContentController*) controller
       didReceiveScriptMessage: (WKScriptMessage*) message
{
    if ([[message name] isEqualToString: HOVER_MESSAGE]) {
        [view_ hoverMessage: [message body]];
    } else if ([[message name] isEqualToString: HEIGHT_MESSAGE]) {
        [view_ heightMessage: [message body]];
    }
}
@end

@implementation SFPageView

#pragma mark Delegate

- (void) setPageDelegate: (id) delegate
{
    pageDelegate_ = delegate;
}

- (id) pageDelegate
{
    return pageDelegate_;
}

#pragma mark Find

- (void) findString: (NSString*) string forward: (BOOL) forward
{
    if ([string length] == 0) {
        return;
    }
    WKFindConfiguration* config = [[[WKFindConfiguration alloc] init] autorelease];
    [config setBackwards: ! forward];
    [config setCaseSensitive: NO];
    [config setWraps: NO];
    [self findString: string withConfiguration: config completionHandler: ^(WKFindResult* result) {}];
}

#pragma mark Script messages

- (void) hoverMessage: (id) body
{
    NSURL* url = nil;
    NSString* label = nil;
    BOOL option = NO;
    if ([body isKindOfClass: [NSDictionary class]]) {
        NSString* href = [body objectForKey: @"href"];
        if ([href isKindOfClass: [NSString class]]) {
            url = [NSURL URLWithString: href];
        }
        label = [body objectForKey: @"label"];
        if (! [label isKindOfClass: [NSString class]]) {
            label = nil;
        }
        option = [[body objectForKey: @"option"] boolValue];
    }
    [pageDelegate_ pageView: self mouseOverURL: url label: label option: option];
}

- (void) heightMessage: (id) body
{
    if (! [body isKindOfClass: [NSNumber class]]) {
        return;
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName: SFPageViewContentHeightDidChangeNotification
                      object: self
                    userInfo: [NSDictionary dictionaryWithObject: body
                                                          forKey: SFPageViewContentHeightKey]];
}

#pragma mark WKNavigationDelegate

- (BOOL) shouldLoadURL: (NSURL*) url action: (WKNavigationAction*) action
{
    if (! pageDelegate_) {
        return YES;
    }
    BOOL background = ([action modifierFlags] & NSEventModifierFlagCommand) != 0;
    return [pageDelegate_ pageView: self shouldLoadURL: url inBackground: background];
}

- (void) webView: (WKWebView*) webView
decidePolicyForNavigationAction: (WKNavigationAction*) action
 decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler
{
    BOOL load = [self shouldLoadURL: [[action request] URL] action: action];
    decisionHandler(load ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

#pragma mark WKUIDelegate

- (void) webView: (WKWebView*) webView
runJavaScriptAlertPanelWithMessage: (NSString*) message
initiatedByFrame: (WKFrameInfo*) frame
completionHandler: (void (^)(void)) completionHandler
{
    NSLog(@"JavaScript - alert: %@", message);
    completionHandler();
}

// A link that opens a new window (target=_blank) is decided like any other.
- (WKWebView*) webView: (WKWebView*) webView
createWebViewWithConfiguration: (WKWebViewConfiguration*) configuration
   forNavigationAction: (WKNavigationAction*) action
        windowFeatures: (WKWindowFeatures*) features
{
    if ([self shouldLoadURL: [[action request] URL] action: action]) {
        [self loadRequest: [action request]];
    }
    return nil;
}

#pragma mark Override

- (id) initWithFrame: (NSRect) frame
{
    return [self initWithFrame: frame reportsContentHeight: NO];
}

- (id) initWithFrame: (NSRect) frame reportsContentHeight: (BOOL) reports
{
    WKWebViewConfiguration* config = [[[WKWebViewConfiguration alloc] init] autorelease];
    [config setURLSchemeHandler: [SFThreadSchemeHandler sharedHandler] forURLScheme: @"sevenfour"];

    SFPageViewMessageHandler* handler = [[[SFPageViewMessageHandler alloc] init] autorelease];
    WKUserContentController* content = [config userContentController];
    [content addScriptMessageHandler: handler name: HOVER_MESSAGE];
    [content addUserScript: [[[WKUserScript alloc] initWithSource: HOVER_SCRIPT
                                                     injectionTime: WKUserScriptInjectionTimeAtDocumentEnd
                                                  forMainFrameOnly: YES] autorelease]];
    if (reports) {
        [content addScriptMessageHandler: handler name: HEIGHT_MESSAGE];
        [content addUserScript: [[[WKUserScript alloc] initWithSource: HEIGHT_SCRIPT
                                                         injectionTime: WKUserScriptInjectionTimeAtDocumentEnd
                                                      forMainFrameOnly: YES] autorelease]];
    }

    self = [super initWithFrame: frame configuration: config];
    if (! self) {
        return nil;
    }
    handler->view_ = self;
    messageHandler_ = [handler retain];

    [self setNavigationDelegate: self];
    [self setUIDelegate: self];
    return self;
}

- (void) dealloc
{
    ((SFPageViewMessageHandler*) messageHandler_)->view_ = nil;
    [[[self configuration] userContentController] removeAllScriptMessageHandlers];
    [messageHandler_ release];
    [self setNavigationDelegate: nil];
    [self setUIDelegate: nil];
    [super dealloc];
}

- (BOOL) acceptsFirstResponder
{
    return YES;
}

@end
