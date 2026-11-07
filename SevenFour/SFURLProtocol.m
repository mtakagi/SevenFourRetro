/* This file is not copyrighted and may be used freely. */

#import "SFURLProtocol.h"

#import "SFAppController.h"
#import "SFThread.h"
#import "SFThreadFactory.h"
#import "SFDocument.h"

#import "SFThreadHTMLFormatter.h"
#import "Ch2Helper.h"

@implementation SFURLProtocol

+ (void) parseURL: (NSURL*) url
		   thread: (SFThread**) thread
			range: (NSString**) range
{
	*thread = nil;
	*range = nil;
	
	SFThreadFactory* factory = [SFThreadFactory sharedFactory];
	
	NSArray* ary = [[url path] pathComponents];
	DEBUG_LOG(@"ary = %@", ary);
	if ([ary count] >= 5 &&
		[[ary objectAtIndex: 1] isEqualTo: @"test"] &&
		[[ary objectAtIndex: 2] isEqualTo: @"read.cgi"]) {
		/*
		 0:
		 1: test
		 2: read.cgi
		 3: BOARD
		 4: NUMBER
		 5: RANGE
		 */
		NSURL* board = [NSURL URLWithString: 
			[NSString stringWithFormat: @"https://%@/%@", [url host], [ary objectAtIndex: 3]]];
		
		*thread = [factory threadWithBoard: board
									number: [[ary objectAtIndex: 4] intValue]];		
		
		if ([ary count] > 5) {
			*range = [[ary objectAtIndex: 5] retain];
		}
	} else if ([ary count] == 4 &&
			   [[ary objectAtIndex: 2] isEqualTo: @"dat"]) {
		/*
		 0:
		 1: BOARD
		 2: dat
		 3: NUMBER.dat
		 */
		NSURL* board = [NSURL URLWithString: 
			[NSString stringWithFormat: @"https://%@/%@", [url host], [ary objectAtIndex: 1]]];
		NSString* last = [ary objectAtIndex: 3];
		*thread = [factory threadWithBoard: board
									number: [[last substringToIndex: [last length] - 4] intValue]];
	}
}

- (void) startLoadingSkin: (NSURL*) url
{
	NSFileManager* manager = [NSFileManager defaultManager];
	NSString* path;
	
	// Home
	path = [NSString stringWithFormat: @"%@/Skin/%@", SF_SUPPORT_DIRECTORY, [url path]];
	if (! [manager isReadableFileAtPath: path]) {
		// Bundle
		path = [NSString stringWithFormat: @"%@/Skin/%@", [[NSBundle mainBundle] resourcePath], [url path]];
		if (! [manager isReadableFileAtPath: path]) {
			NSLog(@"%@ is not found.", url);
			return;
		}
	}
	
	// Response
	NSURLResponse* resp;
	resp = [[NSURLResponse alloc] initWithURL: url
									 MIMEType: nil
						expectedContentLength: 0
							 textEncodingName: @"UTF-8"];
	
	[[self client] URLProtocol: self
			didReceiveResponse: resp
			cacheStoragePolicy: NSURLCacheStorageAllowedInMemoryOnly];
	[resp release];

	[[self client] URLProtocol: self
				   didLoadData: [NSData dataWithContentsOfFile: path]];
	[[self client] URLProtocolDidFinishLoading: self];
}

- (void) startLoadingThread: (NSURL*) url
{
    SFThread* th;
    NSString* range;
    
	[SFURLProtocol parseURL: url
					 thread: &th range: &range];

    if (! formatter_) {
        formatter_ = [[SFThreadHTMLFormatter alloc] init];    
    }
    [formatter_ setRange: range];

	if (! th) {
		NSLog(@"SFURLProtocol: %@ is not a thread ( t = %@ ).", url, th);
		return;
	}
	
	// Add Observer
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver: self
			   selector: @selector(threadFinishParsing:)
				   name: SFThreadDidFinishUpdatingNotification
				 object: th];
	
	// Response
	NSURLResponse* resp;
	resp = [[NSURLResponse alloc] initWithURL: url
									 MIMEType: @"text/html"
						expectedContentLength: 0
							 textEncodingName: @"UTF-16"];
	[[self client] URLProtocol: self
			didReceiveResponse: resp
			cacheStoragePolicy: NSURLCacheStorageAllowedInMemoryOnly];
	[resp release];
	
	[th update];
}

- (void) threadFinishParsing: (NSNotification*) n
{    
    SFThread* th = [n object];

    NSString* html = [formatter_ formatThread: th];
    
    [html writeToFile: @"/tmp/a.html"
           atomically: YES];
    
    [[self client] URLProtocol: self
				   didLoadData: [html dataUsingEncoding: NSUnicodeStringEncoding]];
    [[self client] URLProtocolDidFinishLoading: self];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}


#pragma mark Override
- (void) dealloc
{
	// DEBUG_LOG(@"SFURLProtocol %p - dealloc", self);

    [formatter_ release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

+ (BOOL) canInitWithRequest: (NSURLRequest*) req
{
    // NSLog(@"canInitWithRequest: req = %@", req);
	return [[[req URL] scheme] isEqualTo: @"sevenfour"];
}

+ (NSURLRequest*) canonicalRequestForRequest: (NSURLRequest*) req
{
    // NSLog(@"canonicalRequestForRequest: req = %@", req);
    
	return req;
}

- (void) startLoading
{
	DEBUG_LOG(@"SFURLProtocol %p - startLoading", self);
	DEBUG_LOG(@"  [[self request] URL] = %@", [[self request] URL]);

	NSURL* url = [[self request] URL];
	
	if ([[url host] isEqualTo: @"skin"]) {
		[self startLoadingSkin: url];
	} else {
		[self startLoadingThread: url];
	}
}

- (void) stopLoading
{
	;
}

@end
