/* This file is not copyrighted and may be used freely. */

#import "SFThreadView.h"

#import "SFAppController.h"
#import "SFDocument.h"
#import "SFThread.h"
#import "SFThreadFactory.h"
#import "SFThreadHTMLFormatter.h"
#import "SFThreadSchemeHandler.h"
#import <OgreKit/OgreKit.h>

// The name the hover script posts to.
static NSString* const HOVER_MESSAGE = @"sevenfourHover";

// Reports the link under the mouse: WKWebView has no API for it, so a
// script posts {href, label, option} (or null off links) on mouseover.
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

// Holds the view without retaining it: the user content controller retains
// its message handlers, and the view retains the controller.
@interface SFThreadViewHoverHandler : NSObject <WKScriptMessageHandler> {
@public
    SFThreadView* view_;
}
@end

@interface SFThreadView (Hover)
- (void) hoverMessage: (id) body;
@end

@implementation SFThreadViewHoverHandler
- (void) userContentController: (WKUserContentController*) controller
       didReceiveScriptMessage: (WKScriptMessage*) message
{
    [view_ hoverMessage: [message body]];
}
@end

@implementation SFThreadView

#pragma mark SFTabContent

- (NSString*) tabTitle
{
    return [self title];
}

- (BOOL) isTabLoading
{
    return [self isLoading] || isFragmentLoading_;
}

- (void) tabContentDidChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName: SFTabContentDidChangeNotification
                                                        object: self];
}

// "title" and "loading" of WKWebView, told to the tab bar.
- (void) observeValueForKeyPath: (NSString*) path
                       ofObject: (id) object
                         change: (NSDictionary*) change
                        context: (void*) context
{
    [self tabContentDidChange];
}

- (void) setFragmentLoading: (BOOL) flag
{
    isFragmentLoading_ = flag;
    [self tabContentDidChange];
}

#pragma mark Page

- (void) setThreadDelegate: (id) delegate
{
    threadDelegate_ = delegate;
}

- (void) setPageCount: (int) count
{
    pageCount_ = count;
}

- (NSURL*) pageURL
{
    return [self URL];
}

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
    [threadDelegate_ threadView: self mouseOverURL: url label: label option: option];
}

#pragma mark Thread

- (void) setThread: (SFThread*) t
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self name: SFThreadDidFinishUpdatingNotification object: nil];

	[thread_ release];
	thread_ = nil;

	if (! t)
		return;

	thread_ = [t retain];
	[center addObserver: self
			   selector: @selector(threadFinishParsing:)
				   name: SFThreadDidFinishUpdatingNotification
				 object: thread_];
}

- (SFThread*) thread
{
	if (! thread_ && [self URL]) {
		[self setThread: [[SFThreadFactory sharedFactory] threadWithURL: [self URL]]];
	}
	return thread_;
}

- (void) updateThread
{
    [self setFragmentLoading: YES];

	[thread_ update];
}

- (BOOL) isUpdatingThread
{
	return isFragmentLoading_;
}

- (void) loadThreadWithURL: (NSURL*) url
{
    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
	[self setThread: [factory threadWithURL: url]];

	visibleCount_ = 0;
	isPageLoaded_ = NO;

	// The same URL served by SFThreadSchemeHandler, keeping the port (#37).
	NSURLComponents* c = [NSURLComponents componentsWithURL: url resolvingAgainstBaseURL: YES];
	[c setScheme: @"sevenfour"];
	[c setQuery: nil];
	[c setFragment: nil];
	[self loadRequest: [NSURLRequest requestWithURL: [c URL]]];
}

- (NSString*) escapeJSString: (NSString*) s
{
    NSMutableString* ms = [NSMutableString stringWithString: s];

    [ms replaceOccurrencesOfString: @"\\"
                        withString: @"\\\\"
                           options: 0
                             range: NSMakeRange(0, [ms length])];
    [ms replaceOccurrencesOfString: @"'"
                        withString: @"\\'"
                           options: 0
                             range: NSMakeRange(0, [ms length])];
    [ms replaceOccurrencesOfRegularExpressionString: @"[\n\r]"
                                         withString: @" "
                                            options: 0
                                              range: NSMakeRange(0, [ms length])];
    return ms;
}

// The thread was updated: add its new messages to the page.
- (void) threadFinishParsing: (NSNotification*) n
{
	if (! isPageLoaded_) {
		// The page is loading; its new messages are added when it has
		// loaded (-webView:didFinishNavigation:).
		[self setFragmentLoading: NO];
		return;
	}
	[self appendMessagesOfThread: [n object]];
}

// Adds the messages of th after the ones the page shows.
- (void) appendMessagesOfThread: (SFThread*) th
{
	SFThreadHTMLFormatter* formatter = [[SFThreadHTMLFormatter alloc] init];
	NSMutableString* html = [NSMutableString string];
	int i;
	for (i = visibleCount_; i < [th count]; i++) {
		NSDictionary* message = [th messageAtIndex: i];
		[html appendString: [formatter formatMessage: message
		                                      number: i + 1]];
	}
	[formatter release];
	visibleCount_ = [th count];

	if ([html length] == 0) {
		[self setFragmentLoading: NO];
		return;
	}
	NSString* script = [NSString stringWithFormat:
		@"document.getElementById('new').innerHTML += '%@';",
		[self escapeJSString: html]];
	[self evaluateJavaScript: script completionHandler: ^(id result, NSError* error) {
		if (error) {
			NSLog(@"SFThreadView: adding new messages failed: %@", error);
		}
		[self setFragmentLoading: NO];
	}];
}

#pragma mark WKNavigationDelegate

- (void) webView: (WKWebView*) webView
decidePolicyForNavigationAction: (WKNavigationAction*) action
 decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler
{
	NSURL* url = [[action request] URL];
	BOOL background = ([action modifierFlags] & NSEventModifierFlagCommand) != 0;
	BOOL load = YES;
	if (threadDelegate_) {
		load = [threadDelegate_ threadView: self shouldLoadURL: url inBackground: background];
	}
	decisionHandler(load ? WKNavigationActionPolicyAllow : WKNavigationActionPolicyCancel);
}

- (void) webView: (WKWebView*) webView didStartProvisionalNavigation: (WKNavigation*) navigation
{
	isPageLoaded_ = NO;
	pageCount_ = -1;
	[threadDelegate_ threadViewDidStartLoading: self];
}

- (void) webView: (WKWebView*) webView didCommitNavigation: (WKNavigation*) navigation
{
	// Back and forward show another thread: follow the page.
	SFThread* th = [[SFThreadFactory sharedFactory] threadWithURL: [self URL]];
	if (th && th != thread_) {
		[self setThread: th];
	}
}

- (void) webView: (WKWebView*) webView didFinishNavigation: (WKNavigation*) navigation
{
	SFThread* th = [self thread];
	// The page shows the messages the thread had when the page was made
	// (pageCount_), or all of them if that is not known (a page restored
	// from the history).
	visibleCount_ = (pageCount_ >= 0 && pageCount_ <= [th count]) ? pageCount_ : [th count];
	isPageLoaded_ = YES;
	if (([th count] - [th newCount]) > 0) {
		[self evaluateJavaScript: @"sevenfour.scrollToNew();" completionHandler: nil];
	}
	// Messages the thread got while the page was loading.
	if (visibleCount_ < [th count]) {
		[self appendMessagesOfThread: th];
	}
	[threadDelegate_ threadViewDidFinishLoading: self];
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
	NSURL* url = [[action request] URL];
	BOOL background = ([action modifierFlags] & NSEventModifierFlagCommand) != 0;
	if ([threadDelegate_ threadView: self shouldLoadURL: url inBackground: background]) {
		[self loadRequest: [action request]];
	}
	return nil;
}

#pragma mark Override

- (id) initWithFrame: (NSRect) frame
{
	WKWebViewConfiguration* config = [[[WKWebViewConfiguration alloc] init] autorelease];
	[config setURLSchemeHandler: [SFThreadSchemeHandler sharedHandler] forURLScheme: @"sevenfour"];

	SFThreadViewHoverHandler* hover = [[[SFThreadViewHoverHandler alloc] init] autorelease];
	WKUserContentController* content = [config userContentController];
	[content addScriptMessageHandler: hover name: HOVER_MESSAGE];
	WKUserScript* script = [[[WKUserScript alloc] initWithSource: HOVER_SCRIPT
	                                               injectionTime: WKUserScriptInjectionTimeAtDocumentEnd
	                                            forMainFrameOnly: YES] autorelease];
	[content addUserScript: script];

    self = [super initWithFrame: frame configuration: config];
	if (! self) {
		return nil;
	}
	hover->view_ = self;
	hoverHandler_ = [hover retain];

    visibleCount_ = 0;
    pageCount_ = -1;
    isPageLoaded_ = NO;
    isFragmentLoading_ = NO;
	[self setNavigationDelegate: self];
	[self setUIDelegate: self];
	[self addObserver: self forKeyPath: @"title" options: 0 context: NULL];
	[self addObserver: self forKeyPath: @"loading" options: 0 context: NULL];

    return self;
}

- (void) dealloc
{
	[self removeObserver: self forKeyPath: @"title"];
	[self removeObserver: self forKeyPath: @"loading"];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	((SFThreadViewHoverHandler*) hoverHandler_)->view_ = nil;
	[[[self configuration] userContentController] removeScriptMessageHandlerForName: HOVER_MESSAGE];
	[hoverHandler_ release];
	[self setNavigationDelegate: nil];
	[self setUIDelegate: nil];
	[thread_ release];
    [super dealloc];
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

@end
