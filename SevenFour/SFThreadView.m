/* This file is not copyrighted and may be used freely. */

#import "SFThreadView.h"

#import "SFAppController.h"
#import "SFDocument.h"
#import "SFThread.h"
#import "SFThreadFactory.h"
#import "SFThreadHTMLFormatter.h"
#import <OgreKit/OgreKit.h>

@implementation SFThreadView
- (float) estimatedProgress
{
    if (isFragmentLoading_) {
        return 0.5f;
    } else {
        return [super estimatedProgress];
    }
}

#pragma mark SFTabContent

- (NSString*) tabTitle
{
    return [self mainFrameTitle];
}

- (BOOL) isTabLoading
{
    float progress = [self estimatedProgress];
    return progress != 0.0f && progress != 1.0f;
}

// WebKit's progress notifications (the title is set by the time a load
// finishes, #45) and the thread updates, told to the tab bar.
- (void) tabContentDidChange: (NSNotification*) n
{
    [[NSNotificationCenter defaultCenter] postNotificationName: SFTabContentDidChangeNotification
                                                        object: self];
}

- (void) setFragmentLoading: (BOOL) flag
{
    [self willChangeValueForKey: @"estimatedProgress"];
    isFragmentLoading_ = flag;
    [self didChangeValueForKey: @"estimatedProgress"];
    [self tabContentDidChange: nil];
}

#pragma mark Page

- (NSURL*) pageURL
{
    return [[[[self mainFrame] dataSource] request] URL];
}

- (BOOL) findString: (NSString*) string forward: (BOOL) forward
{
    return [self searchFor: string direction: forward caseSensitive: NO wrap: NO];
}

// The frame view fills the view (the tab bar sizes it, #27).
- (void) setFrameSize: (NSSize) size
{
    [super setFrameSize: size];
    [[[self mainFrame] frameView] setFrameSize: size];
}

- (void) setThread: (SFThread*) t
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	// Only the thread's notification: the progress ones stay.
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
	if (! thread_) {
		NSMutableURLRequest* req = [[[self mainFrame] dataSource] request];
		SFThread* t = [[SFThreadFactory sharedFactory] threadWithURL: [req URL]];
		
        [self setThread: t];
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
	return isFragmentLoading_ ? YES : NO;
}

- (void) loadThreadWithURL: (NSURL*) url
{    
    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
	[self setThread: [factory threadWithURL: url]];
	
	visibleCount_ = 0;
    
	// The same URL served by SFURLProtocol, keeping the port (#37).
	NSURLComponents* c = [NSURLComponents componentsWithURL: url resolvingAgainstBaseURL: YES];
	[c setScheme: @"sevenfour"];
	[c setQuery: nil];
	[c setFragment: nil];
	NSURLRequest* req = [NSURLRequest requestWithURL: [c URL]];
	
	[[self mainFrame] loadRequest: req];
}

- (NSString*) escapeJSString: (NSString*) s
{
    NSMutableString* ms = [NSMutableString stringWithString: s];

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

- (void) threadFinishParsing: (NSNotification*) n
{   
	DEBUG_LOG(@"SFThreadView %p - threadFinishParsing:", self);

	SFThread* th = [n object];
	DEBUG_LOG(@"  [th count] = %d", [th count]);
	
	if (visibleCount_ == 0) {
		// First
	} else {
        SFThreadHTMLFormatter* formatter = [[SFThreadHTMLFormatter alloc] init];
		NSMutableString* html = [NSMutableString string];
		int i;
		
		for (i = visibleCount_; i < [th count]; i++) {
			NSDictionary* message = [th messageAtIndex: i];
			[html appendString: [formatter formatMessage: message
                                                  number: i + 1]];
		}
        [formatter release];
		
		// DEBUG_LOG(@"  html = %@", html);
		
		NSString* script = [NSString stringWithFormat: 
			@"document.getElementById('new').innerHTML += '%@';",
			[self escapeJSString: html]];
		[self stringByEvaluatingJavaScriptFromString: script];	
	}
	
	visibleCount_ = [th count];

    [self setFragmentLoading: NO];
}

- (BOOL) goBack
{
	[thread_ release];
	thread_ = nil;
	
    BOOL result = [super goBack];
    visibleCount_ = [[self thread] count];
	
	return result;
}

- (BOOL) goForward
{
	[thread_ release];
	thread_ = nil;
	
    BOOL result = [super goForward];
    visibleCount_ = [[self thread] count];
    
	return result;
}

#pragma mark Override
- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame
                      frameName: @"_top"
                      groupName: nil];
    visibleCount_ = 0;
    isFragmentLoading_ = NO;

    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    NSArray* names = [NSArray arrayWithObjects:
        WebViewProgressStartedNotification,
        WebViewProgressEstimateChangedNotification,
        WebViewProgressFinishedNotification, nil];
    NSEnumerator* e = [names objectEnumerator];
    NSString* name;
    while ((name = [e nextObject]) != nil) {
        [center addObserver: self
                   selector: @selector(tabContentDidChange:)
                       name: name
                     object: self];
    }

    return self;
}

- (void) dealloc
{
	// FIXME
	// [[self thread] release];
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

@end
