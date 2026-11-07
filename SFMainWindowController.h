#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>

#import "SearchableArrayController.h"

@class TabbedWebView;
@class HTThreePaneSplitView;
@class SFImageWindowController;
@class SFPopUpWindowController;
@class SFSidePaneController;
@class SFThread;
@class SFThreadFactory;

@interface SFMainWindowController : NSWindowController {
    IBOutlet NSDrawer* drawer;
	
    IBOutlet SearchableArrayController* threadsController;
    IBOutlet NSTableView* threadListView;
    IBOutlet NSView* threadListViewContainer;
	
    IBOutlet NSView* toolbarThreadSearch;
    IBOutlet NSSearchField* threadSearchField;

    IBOutlet NSView* toolbarBoardSearch;
    IBOutlet NSSearchField* boardSearchField;

    IBOutlet NSView* toolbarProgress;
    
    IBOutlet HTThreePaneSplitView* splitView;
    IBOutlet TabbedWebView* tabbedWebView;
	
	IBOutlet NSWindow* findPanel;
	IBOutlet NSTextField* findField;
	
	IBOutlet NSTextField* urlField;
    
    NSToolbar* toolbar_;
    NSDictionary* toolbarItems_;
    SFImageWindowController* imageWindowController_;
    SFSidePaneController* sidePaneController_;
    NSWindow* latestPopUpWindow_;
	
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
