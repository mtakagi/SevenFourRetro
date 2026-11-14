/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

// The board list in the left pane of the main window: an outline of the
// board tree, with a search field above it (shown when the
// ShowSearchFieldInSidePane setting is on). Made in code (#29).
@interface SFSidePaneController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate> {
    NSView* baseView;
    NSOutlineView* outlineView;
    NSSearchField* searchField;

    NSString* keyword_;
    unsigned skipped_;
    id delegate_;
}

- (void)setAdditionalSearchField:(NSSearchField*)field;

- (void)setDelegate:(id)delegate;
- (NSView*)view;
- (NSOutlineView*)outlineView;
- (void)update;

- (IBAction)search:(id)sender;
- (IBAction)clicked:(id)sender;

@end

@interface NSObject (SFSidePaneControllerDelegate)
- (BOOL)openURL:(NSURL*)url;

- (NSDictionary*)boardTree;
- (BOOL)openBoard:(NSURL*)url
            title:(NSString*)title;
@end
