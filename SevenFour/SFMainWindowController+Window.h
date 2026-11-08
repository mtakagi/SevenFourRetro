/* This file is not copyrighted and may be used freely. */

#import "SFMainWindowController.h"

// Makes what MainWindow.nib held (#29), with the same layout, settings and
// bindings. Sets the controller's views and controllers (splitView,
// threadListView, threadsController...).
@interface SFMainWindowController (Window)
// The main window: the three-pane split view with the thread list on top
// and the thread tabs below. The board list (the side view) is added by
// -setUpWindow.
- (NSWindow*) makeWindow;
@end
