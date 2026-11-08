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
#import "SFSymbolToolbarItem.h"

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
    [[self window] makeFirstResponder: [tabbedWebView selectedContent]];
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
		[self popupMessage: [[self selectedThreadView] thread]
						ID: [url fragment]];
	} else if ([last isEqualTo: @"number"]) {
		SFThread* th = [[self selectedThreadView] thread];
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

// The thread shown in the selected tab.
- (SFThreadView*) selectedThreadView
{
	return (SFThreadView*) [tabbedWebView selectedContent];
}

// Shows the URL of the selected tab's page (nil: none) and updates the title.
- (void) updatePageURL: (NSURL*) url
{
	if (url) {
		[urlField setStringValue: [url absoluteString]];
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
	if (SFIsWebURL(url)) {
		
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
		SFThreadView* view = [self selectedThreadView];
		[self popupMessage: [view thread]
					 range: [url fragment]];
	} else if ([[url scheme] isEqualTo: @"mailto"]) {
		OGRegularExpression* pattern;
		OGRegularExpressionMatch* match;
		
		pattern = [OGRegularExpression regularExpressionWithString: @"^>*(\\d+)$"];		
		match = [pattern matchInString: label];
		
		if (match) {
			SFThreadView* view = [self selectedThreadView];
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
        [item setState: NSControlStateValueOff];
    }
    [sender setState: NSControlStateValueOn];
    
    [[threadSearchField cell] setSendsWholeSearchString: YES];
}

- (IBAction) selectSearchThreadList: (id) sender
{
    useSpotlightSearch_ = NO;
    
    NSMenu* menu = [sender menu];
    int i;
    for (i = 0; i < [menu numberOfItems]; i++) {
        NSMenuItem* item = [menu itemAtIndex: i];
        [item setState: NSControlStateValueOff];
    }
    [sender setState: NSControlStateValueOn];
    
    [[threadSearchField cell] setSendsWholeSearchString: NO];
}


/* delete selected thread from toolbar */
- (IBAction) deleteThreadCache: (id) sender
{
	SFThread* th = [[self selectedThreadView] thread];
	[th removeCache];
	
	[threadListView reloadData];
}

- (IBAction) closeTab: (id) sender
{
	if ([tabbedWebView numberOfContents] > 1) {
		SFThreadView* tv = [self selectedThreadView];
		[tabbedWebView removeContent: tv];
	}
}

- (IBAction) toggleOffline: (id) sender
{
	BOOL flag = [[self document] isOffline];
	[[self document] setOffline: ! flag];
	
	[sender setState: flag ? NSControlStateValueOn : NSControlStateValueOff];
	
	[self synchronizeWindowTitleWithDocumentName];
}

- (IBAction) performCustomFindPanelAction: (id) sender
{
    [findPanel makeKeyAndOrderFront: sender];
}

- (IBAction) searchForward: (id) sender
{
    [[self selectedThreadView] findString: [findField stringValue] forward: YES];
}

- (IBAction) searchBackward: (id) sender
{
    // It searched forward too until #27.
    [[self selectedThreadView] findString: [findField stringValue] forward: NO];
}

- (IBAction) openURLOfBoard: (id) sender
{
	[[NSWorkspace sharedWorkspace] openURL: [[self document] URLOfBoard]];
}

- (IBAction) copyURLOfBoard: (id) sender
{
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes: [NSArray arrayWithObject: NSPasteboardTypeString]
               owner: self];
    [pb setString: [[[self document] URLOfBoard] absoluteString]
          forType: NSPasteboardTypeString];
}

- (IBAction) openURLOfThread: (id) sender
{
	NSURL* url = [[[self selectedThreadView] thread] URLOfHTML];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

- (IBAction) copyURLOfThread: (id) sender
{
	NSURL* url = [[[self selectedThreadView] thread] URLOfHTML];

    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes: [NSArray arrayWithObject: NSPasteboardTypeString]
               owner: self];
    [pb setString: [url absoluteString]
          forType: NSPasteboardTypeString];
}

- (IBAction) updateBoardTree: (id) sender
{
	[SFDocument updateBoardTree];
}

- (void) boardTreeDidChange: (NSNotification*) n
{
	[sidePaneController_ update];
}

- (IBAction) newTab: (id) sender
{
    SFThreadView* view = [[SFThreadView alloc] initWithFrame: [tabbedWebView frame]];
    [view setPolicyDelegate: self];
    [view setUIDelegate: self];
	[view setFrameLoadDelegate: self];
	// The page's views keep their own responder chain (the document view's
	// next responder is its scroll view), so scrolling and keys work from
	// the first page on. Overriding it sent them to the tab view, and a
	// tab's first page could not scroll (#44).

    [tabbedWebView addContent: view];
    [view release];    
}

- (IBAction) updateBoard: (id) sender
{
    [[self document] updateBoard];
    [self validateToolbarSoon: nil];
}

- (IBAction) toggleBoardTree: (id) sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults integerForKey: @"UseDrawer"]) {
        
        // When Opened
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"   // NSDrawer: #29
        if ([drawer state] == NSDrawerOpenState) {
            [drawer close];
            return;
        }
#pragma clang diagnostic pop
        
        // When Closed
        NSInteger edge = [defaults integerForKey: @"DrawerEdge"];
        
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
    
    if (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagCommand) != 0) {
        NSView<SFTabContent>* fg = [tabbedWebView selectedContent];
        
        [self newTab: nil];
        view = [self selectedThreadView];
        
        [tabbedWebView selectContent: fg];
    } else {
#if 0
		NSArray* ary;
        
		// Search in Tabs
		ary = [tabbedWebView contents];
        
        int i;
		for (i = 0; i < [ary count]; i++) {
			SFThreadView* tv = (SFThreadView*) [tabbedWebView contentAtIndex: i];
			if ([tv thread] && [th isEqualToThread: [tv thread]]) {
				NSLog(@"Same Thread");
				[tabbedWebView selectContent: tv];
				[tv updateThread];
				return;
			}
		}
#endif
        
		view = [self selectedThreadView];
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
    SFThreadView* tv = [self selectedThreadView];
    [tv updateThread];
    [self validateToolbarSoon: nil];
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
	SFThread* th = [[self selectedThreadView] thread];
	
	if (! th) {
		return;
	}
	
	SFPostWindowController* wc;
	wc = [[SFPostWindowController alloc] init];
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	// The old nib loading retains the nib's top-level objects for their
	// owner; the replacement doesn't, so it waits for the nib rework (#29).
	[NSBundle loadNibNamed: @"SidePane" owner: sidePaneController_];
#pragma clang diagnostic pop
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
    [threadListView registerForDraggedTypes: [NSArray arrayWithObjects: NSPasteboardTypeURL,  nil]];
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
    // Stop the spinning update icons when the work they show is done.
    [center addObserver: self
               selector: @selector(validateToolbarSoon:)
                   name: SFThreadDidFinishUpdatingNotification
                 object: nil];
    [center addObserver: self
               selector: @selector(validateToolbarSoon:)
                   name: SFBoardDidFinishUpdatingNotification
                 object: nil];
    // A newly downloaded board list replaces the items of the side pane.
    [center addObserver: self
               selector: @selector(boardTreeDidChange:)
                   name: SFBoardTreeDidChangeNotification
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
    
	if ([tabbedWebView numberOfContents] > 1) {
		SFThreadView* tv = [self selectedThreadView];
		[tabbedWebView removeContent: tv];
		
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
	NSArray* ary = [tabbedWebView contents];
	int i;
	for (i = 0; i < [ary count]; i++) {
		SFThreadView* tv = (SFThreadView*) [ary objectAtIndex: i];
		[[tv thread] saveMetadata];
	}

	// Stop observing so a closed window's controller isn't messaged later.
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
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

	SFThread* thread = [[self selectedThreadView] thread];
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
    NSDictionary* dict = [toolbarItems_ objectForKey: identifier];

    NSToolbarItem* item;
    if ([[dict objectForKey: @"animates"] boolValue]) {
        // Spins its symbol while busy; see -isToolbarItemBusy:.
        item = [[SFSymbolToolbarItem alloc] initWithItemIdentifier: identifier
                                                        symbolName: [dict objectForKey: @"symbol"]
                                                             label: [dict objectForKey: @"label"]];
    } else {
        item = [[NSToolbarItem alloc] initWithItemIdentifier: identifier];
    }
    [item autorelease];
    [item setTarget: self];
    
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // The views come from the nib with fixed frames and no constraints, so
    // the toolbar can't size them itself; replacing min/max size with
    // constraints goes with the MainWindow rework (#29).
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
#pragma clang diagnostic pop
    NSString* symbol = [dict objectForKey: @"symbol"];
    if (symbol && ! [item isKindOfClass: [SFSymbolToolbarItem class]]) {
        [item setImage: [NSImage imageWithSystemSymbolName: symbol
                                  accessibilityDescription: [dict objectForKey: @"label"]]];
    }

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
        NSToolbarSpaceItemIdentifier,
        NSToolbarShowColorsItemIdentifier, 
        NSToolbarShowFontsItemIdentifier, 
        NSToolbarPrintItemIdentifier, 
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
        nil];
}

// Whether the work an update item starts is still running.
- (BOOL) isToolbarItemBusy: (NSToolbarItem*) item
{
    if ([item action] == @selector(updateBoard:)) {
        return [[self document] isWorking];
    } else if ([item action] == @selector(updateThread:)) {
        SFThreadView* tv = [self selectedThreadView];
        return [tv isUpdatingThread];
    }
    return NO;
}

// Notifications can arrive before other observers have updated their state
// (e.g. SFThreadView clearing its updating flag), so validate on the next
// pass of the run loop.
- (void) validateToolbarSoon: (id) sender
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self
                                             selector: @selector(validateToolbar)
                                               object: nil];
    [self performSelector: @selector(validateToolbar) withObject: nil afterDelay: 0];
}

- (void) validateToolbar
{
    [toolbar_ validateVisibleItems];
}

-(BOOL) validateToolbarItem: (NSToolbarItem*) item
{
    if ([item action] == @selector(postToThread:) ||
		[item action] == @selector(updateThread:)){
		SFThreadView* tv = [self selectedThreadView];
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
    } else if (SFIsWebURL(url)) {
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
   modifierFlags: (NSUInteger) flags
{
    NSURL* url = [info objectForKey: WebElementLinkURLKey];
	if (! [activeURL_ isEqualTo: url]) {
        [activeURL_ release];
        activeURL_ = [url retain];
	} else {
		return;
    }
    
	if (flags & NSEventModifierFlagOption) {
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
	if (wv == (WebView*) [tabbedWebView selectedContent]) {
		[self updatePageURL: [[[frame provisionalDataSource] request] URL]];
	}
}

- (void) webView: (WebView*) wv didFinishLoadForFrame: (WebFrame*) frame
{
#if 1
	SFThread* th = [(SFThreadView*) wv thread];
	
	if ((WebView*) [tabbedWebView selectedContent] == wv) {
		[self updatePageURL: [[[frame dataSource] request] URL]];
		[[self window] makeFirstResponder: wv];
	}

	if (([th count] - [th newCount]) > 0) {
		[wv stringByEvaluatingJavaScriptFromString: @"sevenfour.scrollToNew();"];
	}
#endif
}

// TabbedWebView delegate
- (void) tabbedWebView: (TabbedWebView*) twv didSelectContent: (NSView<SFTabContent>*) content
{
	[self updatePageURL: [(SFThreadView*) content pageURL]];
	[self validateToolbarSoon: nil];
}

#if 0
- (BOOL) tableView: (NSTableView*) view
         writeRows: (NSArray*) rows
      toPasteboard: (NSPasteboard*) pboard
{
    NSArray* ary = [threadsController arrangedObjects];
    SFThread* th = [ary objectAtIndex: [[rows objectAtIndex: 0] intValue]];
 
    [pboard declareTypes: [NSArray arrayWithObject: NSPasteboardTypeURL]
                   owner: self];
    [[th URLOfHTML] writeToPasteboard: pboard];
    
    return YES;
}
#endif

@end
