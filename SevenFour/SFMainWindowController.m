#import "SFMainWindowController.h"

#import "SFAppController.h"
#import "SFImageWindowController.h"
#import "SFPopUpWindowController.h"
#import "SFPostWindowController.h"

#import "SFDocument.h"
#import "SFMDBoard.h"
#import "SFSidePaneController.h"
#import "SFThread.h"
#import "SFThreadFactory.h"
#import "SFThreadView.h"

#import "TabbedWebView.h"
#import "HTThreePaneSplitView.h"
#import "WhiteFormatter.h"
#import "RatingCell.h"
#import "SFStateCell.h"

#import "SFThreadHTMLFormatter.h"
#import "Ch2Helper.h"

#import <OgreKit/OgreKit.h>


#define _(s) NSLocalizedString((s), @"")

static SFMainWindowController* activeController_;

@implementation SFMainWindowController
+ (SFMainWindowController*) activeController
{
	return activeController_;
}

- (BOOL) useSpotlightSearch
{
    return useSpotlightSearch_;
}

- (void) reloadThreadList: (NSNotification*) n
{
    [threadListView reloadData];
}

- (void) popupImage: (NSURL*) url
{
    if ([SFImageWindowController isOpened: url]) {
        return;
    }
    
    SFImageWindowController* wc;
    wc = [[SFImageWindowController alloc] initWithWindowNibName: @"ImageWindow"];
    
    NSPoint origin = [NSEvent mouseLocation];
    origin.x -= 20;
    origin.y += 20;
    [[wc window] setFrameTopLeftPoint: origin];

    [wc loadURL: url];

    [[self document] addWindowController: wc];    
    [wc showWindow: nil];
    [wc release];    
}

- (void) popupMessage: (SFThread*) thread
			  numbers: (NSArray*) ary
{
    SFPopUpWindowController* wc;
    wc = [[SFPopUpWindowController alloc] initWithWindowNibName: @"PopUpWindow"];
    
    NSRect frame = [[wc window] frame];
    frame.origin = [NSEvent mouseLocation];
#if 0
    frame.origin.y += 20;
#else
    frame.origin.x -= 10;
    frame.origin.y -= 10;
#endif
    frame.size.width = [tabbedWebView frame].size.width;
	[[wc window] setFrame: frame display: NO];
	
    [[wc webView] setFrameLoadDelegate: wc];
    [[wc webView] setUIDelegate: self];
	[[wc webView] setPolicyDelegate: self];
		
	// Load
    SFThreadHTMLFormatter* formatter = [[SFThreadHTMLFormatter alloc] init];
	NSString* html = [formatter formatThread: thread numbers: ary];
	[[[wc webView] mainFrame] loadHTMLString: html
									 baseURL: nil];

    [[self document] addWindowController: wc];
    [wc release];
	    
    [[wc window] makeKeyAndOrderFront: nil];
#if 0
    WebView* wv = [tabbedWebView selectedWebView];
    [[self window] makeFirstResponder: wv];
    [[self window] makeKeyWindow];
    
    latestPopUpWindow_ = [wc window];
#endif
}

- (void) popupMessage: (SFThread*) thread
				   ID: (NSString*) idString
{
	NSMutableArray* ary = [NSMutableArray array];
	
	int i;
	for (i = 0; i < [thread count]; i++) {
		NSDictionary* message = [thread messageAtIndex: i];
		if ([[message objectForKey: @"id"] isEqualTo: idString]) {
			[ary addObject: [NSNumber numberWithInt: i]];
		}
	}
	
	[self popupMessage: thread numbers: ary];
}


- (void) popupMessage: (SFThread*) thread
				range: (NSString*) range
{
	NSMutableString* s = [NSMutableString stringWithString: range];
	[s replaceOccurrencesOfRegularExpressionString: @"^>+."
										withString: @"" 
										   options: 0
											 range: NSMakeRange(0, [s length])];	

	NSArray* ary = [Ch2Helper parseRangeString: s
									lastNumber: [thread count]];
	[self popupMessage: thread numbers: ary];
}


- (void) handleSevenfourScheme: (NSURL*) url
{
	NSString* last = [[url path] lastPathComponent];
	
	if ([last isEqualTo: @"popup"]) {
		[self popupMessage: [(SFThreadView*) [tabbedWebView selectedWebView] thread]
						ID: [url fragment]];
	} else if ([last isEqualTo: @"number"]) {
		SFThread* th = [(SFThreadView*) [tabbedWebView selectedWebView] thread];
		int number = [[url fragment] intValue];

		SFPostWindowController* wc;
		wc = [[SFPostWindowController alloc] init];
		[[self document] addWindowController: wc];    
		
		[wc setThread: th];
		[[wc body] appendFormat: @">>%d\n", number];
		
		[wc showWindow: nil];    
		[wc release];
	}
}

- (void) updateDataSource: (WebDataSource*) source
{
	if (source) {
		[urlField setStringValue: [[[source request] URL] absoluteString]];
	} else {
		[urlField setStringValue: @""];
	}
	
	[self synchronizeWindowTitleWithDocumentName];
	
	// FIXME
	[tabbedWebView setNeedsDisplay: YES];
}

- (NSDictionary*) boardTree
{
    return [SFDocument sharedBoardTree];
}

- (void) mouseOverOnURL: (NSURL*) url
				  label: (NSString*) label
{
	if ([[url scheme] isEqualTo: @"http"]) {
		
		NSRange range;
		range = [[url absoluteString] rangeOfRegularExpressionString: @"\\.(jpe?g|png|gif)$"
															 options: OgreIgnoreCaseOption];
		if (range.length != 0) {
			[self popupImage: url];
		}
		return;
	}
	
	if (([[url scheme] isEqualTo: @"sevenfour"] && (! [[url host] isEqualTo: @"internal"])) || 
		[[url scheme] isEqualTo: @"applewebdata"]) {
		SFThreadView* view = (SFThreadView*) [tabbedWebView selectedWebView];
		[self popupMessage: [view thread]
					 range: [url fragment]];
	} else if ([[url scheme] isEqualTo: @"mailto"]) {
		OGRegularExpression* pattern;
		OGRegularExpressionMatch* match;
		
		pattern = [OGRegularExpression regularExpressionWithString: @"^>*(\\d+)$"];		
		match = [pattern matchInString: label];
		
		if (match) {
			SFThreadView* view = (SFThreadView*) [tabbedWebView selectedWebView];
			[self popupMessage: [view thread] range: [match substringAtIndex: 1]];
		}
	}
}

- (void) searchSpotlight: (NSString*) word
{
    [threadsController search: nil];
    
    NSString* query = [NSString stringWithFormat: @"kMDItemTextContent = '%@' && kMDItemContentType = com.xrea.s74.quux.2ch-dat", word];

    NSLog(@"query = %@", query);
    
    SFMDBoard* board = [[SFMDBoard alloc] init];
    [board setQuery: query];
    [board update];
    
    [[self document] setBoard: board];    
}

#pragma mark Action
- (IBAction) searchThread: (id) sender
{
    if (useSpotlightSearch_) {
        [self searchSpotlight: [threadSearchField stringValue]];
    } else {
        [threadsController search: sender];
    }
}

- (IBAction) selectSearchSpotlight: (id) sender
{
    useSpotlightSearch_ = YES;

    NSMenu* menu = [sender menu];
    int i;
    for (i = 0; i < [menu numberOfItems]; i++) {
        NSMenuItem* item = [menu itemAtIndex: i];
        [item setState: NSOffState];
    }
    [sender setState: NSOnState];
    
    [[threadSearchField cell] setSendsWholeSearchString: YES];
}

- (IBAction) selectSearchThreadList: (id) sender
{
    useSpotlightSearch_ = NO;
    
    NSMenu* menu = [sender menu];
    int i;
    for (i = 0; i < [menu numberOfItems]; i++) {
        NSMenuItem* item = [menu itemAtIndex: i];
        [item setState: NSOffState];
    }
    [sender setState: NSOnState];
    
    [[threadSearchField cell] setSendsWholeSearchString: NO];
}


/* delete selected thread from toolbar */
- (IBAction) deleteThreadCache: (id) sender
{
	SFThread* th = [(SFThreadView*)[tabbedWebView selectedWebView] thread];
	[th removeCache];
	
	[threadListView reloadData];
}

- (IBAction) closeTab: (id) sender
{
	if ([tabbedWebView numberOfWebViews] > 1) {
		SFThreadView* tv = (SFThreadView*) [tabbedWebView selectedWebView];
		[tabbedWebView removeWebView: tv];
	}
}

- (IBAction) toggleOffline: (id) sender
{
	BOOL flag = [[self document] isOffline];
	[[self document] setOffline: ! flag];
	
	[sender setState: flag ? NSOnState : NSOffState];
	
	[self synchronizeWindowTitleWithDocumentName];
}

- (IBAction) performCustomFindPanelAction: (id) sender
{
    [findPanel makeKeyAndOrderFront: sender];
}

- (IBAction) searchForward: (id) sender
{
    [[tabbedWebView selectedWebView] searchFor: [findField stringValue]
									 direction: YES
								 caseSensitive: NO
										  wrap: NO];
}

- (IBAction) searchBackward: (id) sender
{
    [[tabbedWebView selectedWebView] searchFor: [findField stringValue]
									 direction: YES
								 caseSensitive: NO
										  wrap: NO];
}

- (IBAction) openURLOfBoard: (id) sender
{
	[[NSWorkspace sharedWorkspace] openURL: [[self document] URLOfBoard]];
}

- (IBAction) copyURLOfBoard: (id) sender
{
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes: [NSArray arrayWithObject: NSStringPboardType]
               owner: self];
    [pb setString: [[[self document] URLOfBoard] absoluteString]
          forType: NSStringPboardType];
}

- (IBAction) openURLOfThread: (id) sender
{
	NSURL* url = [[(SFThreadView*)[tabbedWebView selectedWebView] thread] URLOfHTML];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

- (IBAction) copyURLOfThread: (id) sender
{
	NSURL* url = [[(SFThreadView*)[tabbedWebView selectedWebView] thread] URLOfHTML];

    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes: [NSArray arrayWithObject: NSStringPboardType]
               owner: self];
    [pb setString: [url absoluteString]
          forType: NSStringPboardType];
}

- (IBAction) updateBoardTree: (id) sender
{
	[[self document] updateBoardTreePList];
}

- (IBAction) newTab: (id) sender
{
    SFThreadView* view = [[SFThreadView alloc] initWithFrame: [tabbedWebView frame]];
    [view setPolicyDelegate: self];
    [view setUIDelegate: self];
	[view setFrameLoadDelegate: self];

	[[[[view mainFrame] frameView] documentView] setNextResponder: tabbedWebView];
	
    [tabbedWebView addWebView: view];
    [view release];    
}

- (IBAction) updateBoard: (id) sender
{
    [[self document] updateBoard];
}

- (IBAction) toggleBoardTree: (id) sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults integerForKey: @"UseDrawer"]) {
        
        // When Opened
        if ([drawer state] == NSDrawerOpenState) {
            [drawer close];
            return;
        }
        
        // When Closed
        int edge = [defaults integerForKey: @"DrawerEdge"];
        
        if (edge == 1) {
            [drawer openOnEdge: NSMinXEdge]; // Left 
        } else if (edge == 2) {
            [drawer openOnEdge: NSMaxXEdge]; // Right
        } else {
            [drawer open];
        }
	} else {
        [splitView toggleSideView: sender];
    }
}

- (IBAction) toggleMainPane: (id) sender
{
    [splitView toggleBottomView: nil];
}

- (BOOL) openThread: (NSURL*) url
{
	DEBUG_LOG(@"SFMainWC %p - openThread:", self);
	
    SFThreadFactory* factory = [SFThreadFactory sharedFactory];
    SFThread* th = [factory threadWithURL: url];
    if (! th)
        return NO;
    
	SFThreadView* view;
    
    if (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0) {
        WebView* fg = [tabbedWebView selectedWebView];
        
        [self newTab: nil];
        view = (SFThreadView*) [tabbedWebView selectedWebView];
        
        [tabbedWebView selectWebView: fg];
    } else {
#if 0
		NSArray* ary;
        
		// Search in Tabs
		ary = [tabbedWebView webViews];
        
        int i;
		for (i = 0; i < [ary count]; i++) {
			SFThreadView* tv = (SFThreadView*) [tabbedWebView webViewAtIndex: i];
			if ([tv thread] && [th isEqualToThread: [tv thread]]) {
				NSLog(@"Same Thread");
				[tabbedWebView selectWebView: tv];
				[tv updateThread];
				return;
			}
		}
#endif
        
		view = (SFThreadView*) [tabbedWebView selectedWebView];
    }
    [view loadThreadWithURL: url];
    return YES;
}

- (BOOL) openURL: (NSURL*) url
{
	SFThread* t = [[SFThreadFactory sharedFactory] threadWithURL: url];
    if (t) {
        [self openThread: url];
    } else {
        [[self document] openBoard: url title: nil];

        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey: @"UseTwoPane"]) {
            [splitView showBottomView: NO];
        }
    }    
	return YES;
}


- (IBAction) openThreadFromList: (id) sender
{
    if (sender != threadListView) {
        return;
    }
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey: @"OpenThreadOnSubjectColumn"]) {
        // Subject Column?
        NSArray* columns = [threadListView tableColumns];
        NSString* identifier = [[columns objectAtIndex: [threadListView clickedColumn]] identifier];
        
        if (! [identifier isEqualToString: @"subject"]) {
            return;
        }
    }
    
    // Get Thread
	if ([threadListView clickedRow] >= 0) {
		NSArray* ary;
		ary = [threadsController arrangedObjects];
		SFThread* th = [ary objectAtIndex: [threadListView clickedRow]];
		
        NSString* s = [NSString stringWithFormat: @"%@/NEW", [th URLOfHTML]];
		[self openThread: [NSURL URLWithString: s]];
	}
}


- (IBAction) openThreadFromListBySingleClick: (id) sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults boolForKey: @"OpenThreadBySingleClick"]) {
        [self openThreadFromList: sender];
    }
}

- (IBAction) updateThread: (id) sender
{
    SFThreadView* tv = (SFThreadView*) [tabbedWebView selectedWebView];
    [tv updateThread];
}

/* delete selected thread from context menu */
- (IBAction) removeThread: (id) sender
{
    NSArray* ary = [threadsController selectedObjects];
	
    int i;
    for (i = 0; i < [ary count]; i++) {
        SFThread* th = [ary objectAtIndex: i];
        [th removeCache];
    }
    
    [threadListView reloadData];
}

- (IBAction) postToThread: (id) sender
{
	SFThread* th = [(SFThreadView*)[tabbedWebView selectedWebView] thread];
	
	if (! th) {
		return;
	}
	
	SFPostWindowController* wc;
	wc = [[SFPostWindowController alloc] initWithWindowNibName: @"PostWindow"];
	[[self document] addWindowController: wc];    
	
	[wc setThread: th];
	
	[wc showWindow: sender];    
	[wc release];
}


#pragma mark Override
- (id) init
{
    self = [super initWithWindowNibName: @"MainWindow"];
    if (! self) {
        return nil;
    }
    [self setWindowFrameAutosaveName: @"MainWindow"];

    // Toolbar
    NSString* path = [[NSBundle mainBundle] pathForResource: @"Toolbar"
                                                     ofType: @"plist"];
    toolbarItems_ = [[NSDictionary alloc] initWithContentsOfFile: path];    
	
	activeURL_ = nil;
    latestPopUpWindow_ = nil;
	
    NSLog(@"SFMainWC %p - init", self);
    
    return self;
}

- (void) windowDidLoad
{
	DEBUG_LOG(@"SFMainWC %p - windowDidLoad", self);
    
    int i;
	
    // Window
    [[self window] setDelegate: self];
    
    // Toolbar
    toolbar_ = [[NSToolbar alloc] initWithIdentifier: @"MainWindow"];
    [toolbar_ setAllowsUserCustomization: true];
    [toolbar_ setAutosavesConfiguration: true];
    [toolbar_ setDelegate: self];
    [[self window] setToolbar: toolbar_];   
    
    // Board Tree
	sidePaneController_ = [[SFSidePaneController alloc] init];
	[NSBundle loadNibNamed: @"SidePane" owner: sidePaneController_];
	[sidePaneController_ setDelegate: self];
    [sidePaneController_ setAdditionalSearchField: boardSearchField];
	[sidePaneController_ update];
	
	// Split View
	[splitView setAutosaveName: @"SplitView"];
		
    // Thread List
    [threadListView setAutosaveName: @"ThreadList"];
    [threadListView setAutosaveTableColumns: YES];
    [threadListView setAction: @selector(openThreadFromListBySingleClick:)];
    [threadListView setDoubleAction: @selector(openThreadFromList:)];
    [threadListView registerForDraggedTypes: [NSArray arrayWithObjects: NSURLPboardType,  nil]];
    [threadListView setDataSource: self];
    
    tableColumns_ = [[NSMutableArray alloc] init];
    for (i = 0; i < 10; i++) {
        [tableColumns_ addObject: [NSNumber numberWithBool: YES]];
    }
    
    NSArray* columns = [threadListView tableColumns];
    NSTableColumn* column;
    WhiteFormatter* formatter;

    column = [columns objectAtIndex: [threadListView columnWithIdentifier: @"rate"]];	
	[column setDataCell: [[RatingCell alloc] init]];
	
    column = [columns objectAtIndex: [threadListView columnWithIdentifier: @"state"]];	
	[column setDataCell: [[SFStateCell alloc] init]];
	
    column = [columns objectAtIndex: [threadListView columnWithIdentifier: @"delta"]];
    formatter = [[WhiteFormatter alloc] init];
    [formatter setMinValue: -1];
    [[column dataCell] setFormatter: formatter];
    
    column = [columns objectAtIndex: [threadListView columnWithIdentifier: @"local"]];
    formatter = [[WhiteFormatter alloc] init];
    [formatter setMinValue: 0];
    [[column dataCell] setFormatter: formatter];
    
    [threadListView setFont: [NSFont systemFontOfSize: [NSFont systemFontSize]]];
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver: self
               selector: @selector(reloadThreadList:)
                   name: SFThreadDidFinishUpdatingNotification
                 object: nil];
    
    // Tabbed WebView
    [self newTab: nil];
	[tabbedWebView setDelegate: self];
    
    // User Defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* str;
    
    str = [defaults stringForKey: @"DrawerSize"];
    if (str) {
        [drawer setContentSize: NSSizeFromString(str)];
    }
	
	if ([defaults boolForKey: @"UseDrawer"]) {
		[drawer setContentView: [sidePaneController_ view]];  
		// Open Drawer
		[self toggleBoardTree: nil];
	} else {
		[splitView setSideView: [sidePaneController_ view]];
		[splitView useSideViewAlternativeStyle: YES];
        [splitView setSideViewNeedsBorder: YES];
	}

	[splitView setVertical: [defaults integerForKey: @"SplitVertical"]];

	// Font
	NSFont* font = [NSFont fontWithName: [defaults stringForKey: @"ThreadListFontFamily"]
								   size: [defaults floatForKey: @"ThreadListFontSize"]];
	[threadListView setRowHeight: [[[[NSLayoutManager alloc] init] autorelease] defaultLineHeightForFont: font] + 2];

	for (i = 0; i < [columns count]; i++) {
		column = [columns objectAtIndex: i];
		[[column dataCell] setFont: font];
	}    
}

// NSWindow delegate
- (BOOL) windowShouldClose: (id) sender
{
    // NSLog(@"sender = %@", sender);    
    
	if ([tabbedWebView numberOfWebViews] > 1) {
		SFThreadView* tv = (SFThreadView*) [tabbedWebView selectedWebView];
		[tabbedWebView removeWebView: tv];
		
		return NO;
	}
	
	return YES;
}

- (void) windowWillClose: (NSNotification*) n
{
    // [[self window] saveFrameUsingName: @"MainWindow"];
    
    // User Defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSString* str;
    
    str = NSStringFromSize([drawer contentSize]);
    [defaults setObject: str
                 forKey: @"DrawerSize"];

	/*
	[defaults setObject: [splitView stringWithSavedPosition]
                 forKey: @"SplitPosition"];
	 */

    [defaults synchronize];
	
	// Metadata
	NSArray* ary = [tabbedWebView webViews];
	int i;
	for (i = 0; i < [ary count]; i++) {
		SFThreadView* tv = (SFThreadView*) [ary objectAtIndex: i];
		[[tv thread] saveMetadata];
	}
}

- (void) windowDidBecomeMain:(NSNotification*) n
{
	activeController_ = self;
}

#if 0
- (void) windowDidResize:(NSNotification*) n
{
    // [[self window] saveFrameUsingName: [self windowFrameAutosaveName]];
    NSSize size;
    size.width = ([[sidePaneController_ view] frame].size.width +
                  [tabbedWebView frame].size.width);
    size.height = FLT_MAX;
    [[self window] setMaxSize: size];
}
#endif

#if 0
- (NSString*) windowTitleForDocumentDisplayName: (NSString*) displayName
{
	NSString* s = [[self document] isOffline]? @"(Offline)" : @"";

	SFThread* thread = [(SFThreadView*)[tabbedWebView selectedWebView] thread];
	if (thread) {
		return [NSString stringWithFormat: @"%@ %@", [thread subject], s];
	} else {
		return [NSString stringWithFormat: @"SevenFour %@", s];
	}
}
#endif

// Toolbar
- (NSToolbarItem*) toolbar: (NSToolbar*) toolbar 
     itemForItemIdentifier: (NSString*) identifier 
 willBeInsertedIntoToolbar: (BOOL) flag
{
    NSToolbarItem* item;
    item = [[NSToolbarItem alloc] initWithItemIdentifier: identifier];
    [item autorelease];
    [item setTarget: self];
    
    NSDictionary* dict = [toolbarItems_ objectForKey: identifier];
    
    if ([identifier isEqualToString: @"search"]) {
        NSView* field = toolbarThreadSearch;
        [[threadSearchField cell] setPlaceholderString: _(@"Thread")];
        
        [item setView: field];
        
        NSRect frame = [field frame];
        [item setMinSize: frame.size];
        [item setMaxSize: frame.size];
    } else if ([identifier isEqualToString: @"boardSearch"]) {
        NSView* field = toolbarBoardSearch;
        [[boardSearchField cell] setPlaceholderString: _(@"Board")];
        
        [item setView: field];
        
        NSRect frame = [field frame];
        [item setMinSize: frame.size];
        [item setMaxSize: frame.size];
    } else if ([identifier isEqualToString: @"progress"]){
        NSView* field = toolbarProgress;
        
        [item setView: field];
        
        NSRect frame = [field frame];
        [item setMinSize: frame.size];
        [item setMaxSize: frame.size];
    } else {
        NSString* s = [NSString stringWithFormat: @"%@:", identifier];
        [item setAction: NSSelectorFromString(s)];
    }
    NSString* path;
    path = [[NSBundle mainBundle] pathForResource: identifier 
                                           ofType: @"png"];
    NSImage* image;
    image = [[NSImage alloc] initWithContentsOfFile: path];
    [item setImage: image];
    [image release];
    
    [item setLabel: [dict objectForKey: @"label"]];
    [item setPaletteLabel: [item label]];
    
    return item;
}   

// NSToolbar delegate
- (NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar*) toolbar
{
    return [NSArray arrayWithObjects:
        @"toggleBoardTree",
        @"toggleMainPane", 
        @"boardSearch",
        @"search", 
        @"progress", 
        @"updateBoard", 
        @"updateThread", 
        @"postToThread", 
        @"newTab", 
        @"closeTab", 
        @"deleteThreadCache", 
        NSToolbarFlexibleSpaceItemIdentifier,
        NSToolbarSeparatorItemIdentifier,
        NSToolbarSpaceItemIdentifier,
        NSToolbarShowColorsItemIdentifier, 
        NSToolbarShowFontsItemIdentifier, 
        NSToolbarPrintItemIdentifier, 
        NSToolbarCustomizeToolbarItemIdentifier,
        nil];
}

- (NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar*) toolbar
{
    return [NSArray arrayWithObjects:
        @"toggleBoardTree",
        @"updateBoard", 
        NSToolbarSpaceItemIdentifier,
        @"updateThread", 
        @"postToThread", 
        NSToolbarFlexibleSpaceItemIdentifier,
        @"search", 
        NSToolbarCustomizeToolbarItemIdentifier,
        nil];
}

-(BOOL) validateToolbarItem: (NSToolbarItem*) item
{
    if ([item action] == @selector(postToThread:) ||
		[item action] == @selector(updateThread:)){
		SFThreadView* tv = (SFThreadView*) [tabbedWebView selectedWebView];
		return [tv thread] != nil;		
    } else {
		return true;
	}
}

// WebView policyDelegate
- (void) webView: (WebView*) wv decidePolicyForNavigationAction: (NSDictionary*) action
         request: (NSURLRequest*) req
           frame: (WebFrame*) frame
decisionListener: (id<WebPolicyDecisionListener>) listener
{
	NSURL* url = [req URL];
	
    if ([[url scheme] isEqualTo: @"sevenfour"]) {
		if ([[url host] isEqualTo: @"internal"]) {
			[listener ignore];
			[self handleSevenfourScheme: url];
		} else {
			[listener use];
		}
		return;
    } else if ([[url scheme] isEqualTo: @"applewebdata"] || [[url scheme] isEqualTo: @"about"]) {
		[listener use];
		return;
    } else if ([[url scheme] isEqualTo: @"http"]) {
		SFThread* th = [SFDocument threadWithURL: url];
		if (th) {
			[self openThread: url];
			return;
		}
	}
	[listener ignore];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

// WebView UIDelegate
- (void) webView: (WebView*) wv
 runJavaScriptAlertPanelWithMessage: (NSString*) message
{
	NSLog(@"JavaScript - alert: %@", message);
}


- (void) webView: (WebView*) wv mouseDidMoveOverElement: (NSDictionary*) info
   modifierFlags: (unsigned int) flags
{
    NSURL* url = [info objectForKey: WebElementLinkURLKey];
	if (! [activeURL_ isEqualTo: url]) {
        [activeURL_ release];
        activeURL_ = [url retain];
	} else {
		return;
    }
    
	if (flags & NSAlternateKeyMask) {
		return;
	}
    
    if (activeURL_) {
        [self mouseOverOnURL: url
                       label: [info objectForKey: WebElementLinkLabelKey]];
    } else {
        // NSLog(@"wv = %@", wv);
#if 0
        [latestPopUpWindow_ close];
        latestPopUpWindow_ = nil;
#endif
    }
}

// WebView FrameLoadDelegate
- (void) webView: (WebView*) wv didStartProvisionalLoadForFrame: (WebFrame*) frame
{
	if (wv == [tabbedWebView selectedWebView]) {
		[self updateDataSource: [frame provisionalDataSource]];
	}
}

- (void) webView: (WebView*) wv didFinishLoadForFrame: (WebFrame*) frame
{
#if 1
	SFThread* th = [(SFThreadView*) wv thread];
	
	if ([tabbedWebView selectedWebView] == wv) {
		[self updateDataSource: [frame dataSource]];
		[[self window] makeFirstResponder: wv];
	}

	if (([th count] - [th newCount]) > 0) {
		[wv stringByEvaluatingJavaScriptFromString: @"sevenfour.scrollToNew();"];
	}
#endif
}

// TabbedWebView delegate
- (void) tabbedWebView: (TabbedWebView*) twv didSelectWebView: (WebView*) wv
{
	[self updateDataSource: [[wv mainFrame] dataSource]];
}

#if 0
- (BOOL) tableView: (NSTableView*) view
         writeRows: (NSArray*) rows
      toPasteboard: (NSPasteboard*) pboard
{
    NSArray* ary = [threadsController arrangedObjects];
    SFThread* th = [ary objectAtIndex: [[rows objectAtIndex: 0] intValue]];
 
    [pboard declareTypes: [NSArray arrayWithObject: NSURLPboardType]
                   owner: self];
    [[th URLOfHTML] writeToPasteboard: pboard];
    
    return YES;
}
#endif

@end
