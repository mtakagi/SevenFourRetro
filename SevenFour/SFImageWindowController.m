#import "SFImageWindowController.h"


#import "TemporaryPanel.h"


static NSMutableSet* opendURLs_ = nil;

@implementation SFImageWindowController

+ (BOOL) isOpened: (NSURL*) url
{
    if (! opendURLs_) {
        opendURLs_ = [[NSMutableSet alloc] init];
    }
    
    if ([opendURLs_ containsObject: [url absoluteString]]) {
        return YES;
    } else {
        [opendURLs_ addObject: [url absoluteString]];
        return NO;
    }
}

- (void) showImage: (NSData*) data
{
	float maxW, maxH;
    NSRect rect;
    
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	maxW = [defaults floatForKey: @"ImageWindowMaxWidth"];
	maxH = [defaults floatForKey: @"ImageWindowMaxHeight"];
	
    // Create Image
    NSImage* image = [[NSImage alloc] initWithData: data];
    
    NSRect whole = NSMakeRect(0, 0, [image size].width, [image size].height);
    NSImageRep* rep = [image bestRepresentationForRect: whole context: nil hints: nil];
    rect.size.width = [rep pixelsWide];
    rect.size.height = [rep pixelsHigh];	
    
    // Resize Image
    rect.origin = NSZeroPoint;    
	
    if (rect.size.width > maxW) {
        float ratio = maxW / rect.size.width;
        rect.size.width   = maxW;
        rect.size.height *= ratio;
    }
    if (rect.size.height > maxH) {
        float ratio = maxH / rect.size.height;
        rect.size.width  *= ratio;
        rect.size.height  = maxH;
    }
	
    // Images always scale to their size (setScalesWhenResized: is gone).
    [image setSize: rect.size];
	
    [imageView setFrame: rect];
	
    // Set Image
    [imageView setImage: image];
    [image release];
    
    // Switch
    [loadingBox setHidden: YES];
    [imageView setHidden: NO];
    [[self window] setAlphaValue: 1.0];
    
    // Resize Window
    rect.origin = [[self window] frame].origin;
	
	NSSize screenSize = [[[self window] screen] frame].size;
	screenSize.height -= [[NSApp mainMenu] menuBarHeight];
	if (rect.origin.x + rect.size.width > screenSize.width) {
		rect.origin.x = screenSize.width - rect.size.width;
	}
	if (rect.origin.y + rect.size.height > screenSize.height) {
		rect.origin.y = screenSize.height - rect.size.height;
	}
	
    [[self window] setFrame: [[self window] frameRectForContentRect: rect]
                    display: YES
                    animate: YES];	
}

- (void) loadURL: (NSURL*) url
{
	// [[self window] makeKeyAndOrderFront: nil];
	
	[messageField setStringValue: @"Loading..."];
    [indicator setDoubleValue: 0.0];

    NSURLRequest* req = [NSURLRequest requestWithURL: url];
    
    // The delegate methods run on the main thread. The session keeps this
    // controller alive until it is invalidated (done, failed or closed).
    [self cancelLoading];
    session_ = [[NSURLSession sessionWithConfiguration: [NSURLSessionConfiguration defaultSessionConfiguration]
                                              delegate: self
                                         delegateQueue: [NSOperationQueue mainQueue]] retain];
    receivedData_ = [[NSMutableData alloc] init];
    failedStatus_ = NO;
    [[session_ dataTaskWithRequest: req] resume];

    [url_ release];
    url_ = [url retain];
    
    // A late reply must not show up in (or keep alive) a closed window.
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: NSWindowWillCloseNotification
                                                  object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(windowWillClose:)
                                                 name: NSWindowWillCloseNotification
                                               object: [self window]];
        
    return;
}

- (void) cancelLoading
{
    [session_ invalidateAndCancel];
    [session_ release];
    session_ = nil;
    [receivedData_ release];
    receivedData_ = nil;
}

- (void) finishLoading
{
    [session_ finishTasksAndInvalidate];
    [session_ release];
    session_ = nil;
    [receivedData_ release];
    receivedData_ = nil;
}

- (void) windowWillClose: (NSNotification*) n
{
    [self cancelLoading];
}

- (IBAction) openURL: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: url_];
}

#pragma mark NSURLSessionDataDelegate

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
 didReceiveResponse: (NSURLResponse*) resp
  completionHandler: (void (^)(NSURLSessionResponseDisposition)) completionHandler
{
    if (session != session_) {
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;
    
    if ([http statusCode] == 200) {
        long long length = [http expectedContentLength];
        if (length > 0) {
            [indicator setMaxValue: length];
        }
        completionHandler(NSURLSessionResponseAllow);
    } else {
		[messageField setStringValue: 
			[NSHTTPURLResponse localizedStringForStatusCode: [http statusCode]]];
        failedStatus_ = YES;
        completionHandler(NSURLSessionResponseCancel);
    }
}

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
     didReceiveData: (NSData*) data
{
    if (session != session_) {
        return;
    }
    [receivedData_ appendData: data];
    [indicator setDoubleValue: [receivedData_ length]];
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didCompleteWithError: (NSError*) error
{
    // Closed, or replaced by another load.
    if (session != session_) {
        return;
    }
    
    // Keep self alive: the session releases its delegate once invalidated.
    [[self retain] autorelease];
    
	[indicator setIndeterminate: YES];
    [indicator stopAnimation: nil];
    
    if (failedStatus_) {
        // The status text is already shown.
    } else if (error) {
        [messageField setStringValue: [error localizedDescription]];
    } else {
        [self showImage: receivedData_];
    }
    
    [self finishLoading];
}

- (void) awakeFromNib
{
    TemporaryPanel* window = (TemporaryPanel*) [self window];
    [window setCloseEvent: TemporaryPanelCloseWhenExited];
    [window setAcceptsMouseMovedEvents: YES];

    [window setAlphaValue: 0.8];
    
    [imageView setHidden: YES];    
    [loadingBox setHidden: NO];
    
    NSRect rect = [loadingBox frame];
    rect.origin = NSZeroPoint;
    [loadingBox setFrame: rect];
    
    [window setFrame: [window frameRectForContentRect: rect]
			 display: NO
			 animate: NO];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self cancelLoading];
    
    if (url_) {
        if (! opendURLs_) {
            opendURLs_ = [[NSMutableSet alloc] init];
        }
        [opendURLs_ removeObject: [url_ absoluteString]];
        [url_ release];
    }
    
    [super dealloc];
}

@end
