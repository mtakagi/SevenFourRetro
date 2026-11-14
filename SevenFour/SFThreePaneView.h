/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

// The panes of the main window (#57): the side view (the board list) on the
// left, and the main area split into the top view (the thread list) and the
// bottom view (the thread tabs). Two nested NSSplitViews: the outer one puts
// the side view beside the main area, the inner one splits the main area
// top and bottom, or left and right (-setVertical:).
//
// Written for SevenFourRetro to replace HTThreePaneSplitView, whose terms of
// redistribution weren't stated. The sizes the user leaves are kept by
// NSSplitView's autosave; the sizes the old view saved are taken over once.
@interface SFThreePaneView : NSView <NSSplitViewDelegate> {
    NSSplitView* outer_; // side | main
    NSSplitView* inner_; // top / bottom
    NSView* sideView_;
    NSView* topView_;
    NSView* bottomView_;
    // Where the dividers were when the view beside them was hidden, to put
    // them back there (0: unknown).
    CGFloat sidePosition_;
    CGFloat bottomPosition_;
}

- (void)setSideView:(NSView*)view;
- (void)setTopView:(NSView*)view;
- (void)setBottomView:(NSView*)view;

// YES: the top and bottom views side by side (the SplitVertical setting).
- (void)setVertical:(BOOL)flag;

// Saves the sizes of the panes under name and restores them. Call it after
// the views are set.
- (void)setAutosaveName:(NSString*)name;

- (BOOL)isSideViewVisible;
- (void)showSideView:(BOOL)flag;
- (IBAction)toggleSideView:(id)sender;

// Hiding the bottom view gives the main area to the top view (the 2-pane
// view of a board: the thread list only).
- (BOOL)isBottomViewVisible;
- (void)showBottomView:(BOOL)flag;
- (IBAction)toggleBottomView:(id)sender;

@end
