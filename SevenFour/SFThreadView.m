/* This file is not copyrighted and may be used freely. */

#import "SFThreadView.h"

#import "SFThread.h"
#import "SFThreadFactory.h"
#import "SFThreadHTMLFormatter.h"
#import <OgreKit/OgreKit.h>

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

- (void) setPageCount: (int) count
{
    pageCount_ = count;
}

- (NSURL*) pageURL
{
    return [self URL];
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

- (void) webView: (WKWebView*) webView didStartProvisionalNavigation: (WKNavigation*) navigation
{
	isPageLoaded_ = NO;
	pageCount_ = -1;
	[[self pageDelegate] threadViewDidStartLoading: self];
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
	[[self pageDelegate] threadViewDidFinishLoading: self];
}

#pragma mark Override

- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];
	if (! self) {
		return nil;
	}
    visibleCount_ = 0;
    pageCount_ = -1;
    isPageLoaded_ = NO;
    isFragmentLoading_ = NO;
	[self addObserver: self forKeyPath: @"title" options: 0 context: NULL];
	[self addObserver: self forKeyPath: @"loading" options: 0 context: NULL];
    return self;
}

- (void) dealloc
{
	[self removeObserver: self forKeyPath: @"title"];
	[self removeObserver: self forKeyPath: @"loading"];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[thread_ release];
    [super dealloc];
}

@end
