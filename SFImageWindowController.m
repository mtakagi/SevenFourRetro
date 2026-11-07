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
    
    NSImageRep* rep = [image bestRepresentationForDevice: nil];
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
	
    [image setScalesWhenResized: YES];
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
	screenSize.height -= [NSMenuView menuBarHeight];
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
    
    NSURLConnection* connection;
    connection = [[NSURLConnection alloc] initWithRequest: req delegate: self];
    if (connection) {
        receivedData_ = [[NSMutableData alloc] init];
    }

    url_ = [url retain];
        
    return;
}

- (IBAction) openURL: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: url_];
}

// NSURLConnection
- (void) connection: (NSURLConnection*) connection
 didReceiveResponse: (NSURLResponse*) resp
{
    NSHTTPURLResponse* http = (NSHTTPURLResponse*) resp;
    
    if ([http statusCode] == 200) {
        NSDictionary* headers = [http allHeaderFields];
        [indicator setMaxValue:
            [[headers objectForKey: @"Content-Length"] intValue]];
    } else {
		[messageField setStringValue: 
			[NSHTTPURLResponse localizedStringForStatusCode: [http statusCode]]];
        [connection cancel];
    }
}

- (void) connection: (NSURLConnection*) connection
     didReceiveData: (NSData*) data
{
    [receivedData_ appendData: data];
    [indicator setDoubleValue: [receivedData_ length]];
}

- (void) connection: (NSURLConnection*) connection
   didFailWithError: (NSError*) error
{
    [connection release];
    [receivedData_ dealloc];
    receivedData_ = nil;
}

- (void) connectionDidFinishLoading: (NSURLConnection*) connection
{
    [connection release];
	
	[indicator setIndeterminate: YES];
    [indicator stopAnimation: nil];

	[self showImage: receivedData_];
	
    [receivedData_ release];
    receivedData_ = nil;
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
    if (url_) {
        if (! opendURLs_) {
            opendURLs_ = [[NSMutableSet alloc] init];
        }
        [opendURLs_ removeObject: [url_ absoluteString]];
        [url_ release];
    }
    
    [receivedData_ release];
    
    [super dealloc];
}

@end
