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

- (void) setThread: (SFThread*) t
{
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center removeObserver: self];
	
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
    [self willChangeValueForKey: @"estimatedProgress"];
    isFragmentLoading_ = YES;
    [self didChangeValueForKey: @"estimatedProgress"];

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
    
	NSString* s = [NSString stringWithFormat: @"sevenfour://%@%@", [url host], [url path]];
	NSURLRequest* req = [NSURLRequest requestWithURL: [NSURL URLWithString: s]];
	
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

    [self willChangeValueForKey: @"estimatedProgress"];
    isFragmentLoading_ = NO;
    [self didChangeValueForKey: @"estimatedProgress"];
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
