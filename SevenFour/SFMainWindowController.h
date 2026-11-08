#import <Cocoa/Cocoa.h>

#import "SearchableArrayController.h"

@class TabbedWebView;
@class SFThreePaneView;
@class SFImageWindowController;
@class SFPopUpWindowController;
@class SFSidePaneController;
@class SFThread;
@class SFThreadFactory;

// The main window: the board list (SFSidePaneController), the thread list
// and the thread tabs in a three-pane split view, with the toolbar and the
// find panel. Made in code (#29); see SFMainWindowController+Window.m.
@interface SFMainWindowController : NSWindowController <NSWindowDelegate, NSToolbarDelegate, NSToolbarItemValidation, NSTableViewDataSource> {
    NSObjectController* documentController_;   // content: the document
    SearchableArrayController* threadsController;
    NSTableView* threadListView;

    // The views of the toolbar items and what they hold.
    NSView* toolbarThreadSearch;
    NSSearchField* threadSearchField;
    NSView* toolbarBoardSearch;
    NSSearchField* boardSearchField;
    NSView* toolbarProgress;
    NSProgressIndicator* progressIndicator_;

    SFThreePaneView* splitView;
    TabbedWebView* tabbedWebView;

	NSPanel* findPanel;
	NSTextField* findField;
    
    NSToolbar* toolbar_;
    NSDictionary* toolbarItems_;
    SFImageWindowController* imageWindowController_;
    SFSidePaneController* sidePaneController_;
	
	NSURL* activeURL_;
    NSMutableArray* tableColumns_;
    
    BOOL useSpotlightSearch_;    
}

- (IBAction) newTab: (id) sender;

- (IBAction) updateBoard: (id) sender;
- (IBAction) toggleBoardTree: (id) sender;

- (IBAction) updateThread: (id) sender;
- (IBAction) removeThread: (id) sender;

- (IBAction) searchThread: (id) sender;
- (IBAction) selectSearchSpotlight: (id) sender;
- (IBAction) selectSearchThreadList: (id) sender;

// Find
- (IBAction) performCustomFindPanelAction: (id) sender;
- (IBAction) searchForward: (id) sender;
- (IBAction) searchBackward: (id) sender;

// 
- (BOOL) openURL: (NSURL*) url;

- (BOOL) useSpotlightSearch;
@end
