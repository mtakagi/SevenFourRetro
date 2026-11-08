#import <Cocoa/Cocoa.h>

@class SFThread;

// The window to write a post to a thread. The window is made in code
// (it was PostWindow.nib before #30).
@interface SFPostWindowController : NSWindowController <NSWindowDelegate, NSComboBoxDataSource> {
    // Views of the window, which retains them.
    NSComboBox* nameBox;
    NSComboBox* mailBox;
    NSTextView* bodyView;
    NSProgressIndicator* indicator;
    
    SFThread* thread_;
    // The post button, disabled while a post is being sent.
    NSButton* postButton_;
    BOOL sending_;
    BOOL closed_;
    // Name, mail and body of the post being sent, to tell whether they were
    // edited while it was sent.
    NSString* sentPost_;
}

- (id) init;

- (void) setThread: (SFThread*) th;
- (SFThread*) thread;
- (NSMutableString*) body;

- (IBAction) post: (id) sender;

@end
