#import "SFPopUpWindowController.h"
#import "TemporaryPanel.h"
#import "SFThread.h"
#import "SFThreadView.h"

@interface NSScreen(DockHeight)
+ (float) dockHeight;
@end

@implementation NSScreen(DockHeight)
+ (float) dockHeight
{
    NSString* path = [@"~/Library/Preferences/com.apple.dock.plist" stringByExpandingTildeInPath];
    NSDictionary* plist = [NSDictionary dictionaryWithContentsOfFile: path];
    if (! [[plist objectForKey: @"autohide"] intValue]) {
        return [[plist objectForKey: @"tilesize"] floatValue] + 11.0;
    } else {
        return 0.0;
    }
}
@end

@implementation SFPopUpWindowController

- (WebView*) webView
{
	return threadView;
}

- (void) resizeFrame
{
    NSView* docView = [[[threadView mainFrame] frameView] documentView];    

	NSSize screenSize = [[[self window] screen] frame].size;
	screenSize.height -= [[NSApp mainMenu] menuBarHeight];
    
	screenSize.height -= [NSScreen dockHeight];
	
    NSRect rect = [[self window] frame];
    rect.size = [docView bounds].size;
	if (rect.origin.x + rect.size.width > screenSize.width) {
		rect.origin.x = screenSize.width - rect.size.width;
	}
	if (rect.origin.y + rect.size.height > screenSize.height) {
		rect.origin.y = screenSize.height - rect.size.height;
	}
	
    TemporaryPanel* panel = (TemporaryPanel*) [self window];
	if (rect.size.height > screenSize.height) {
		rect.size.height = screenSize.height;
		rect.origin.y = [NSScreen dockHeight];
        
        // for scrollbar
        [panel setCanBecomeKeyWindow: YES];
        [panel makeKeyAndOrderFront: nil];
    }
    [panel setFrame: rect display: NO];
}

- (void) frameDidChange: (NSNotification*) n
{
    [self resizeFrame];
}

- (void) webView: (WebView*) wv didFinishLoadForFrame: (WebFrame*) frame
{
    [self resizeFrame];        
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    NSView* docView = [[[threadView mainFrame] frameView] documentView];
    [center addObserver: self
               selector: @selector(frameDidChange:)
                   name: NSViewFrameDidChangeNotification
                 object: docView];
}

- (void) awakeFromNib
{
    loaded_ = NO;
    
    TemporaryPanel* window = (TemporaryPanel*) [self window];
    [window setCloseEvent: TemporaryPanelCloseWhenExited];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
}

@end
