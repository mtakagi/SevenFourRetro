#import <Cocoa/Cocoa.h>

@class SFThread;

@interface SFPostWindowController : NSWindowController {
    IBOutlet NSComboBox* nameBox;
    IBOutlet NSComboBox* mailBox;
    IBOutlet NSTextView* bodyView;
    IBOutlet NSProgressIndicator* indicator;
    
    SFThread* thread_;
    // The button that sent the post, disabled while it is being sent.
    NSButton* postButton_;
    BOOL sending_;
    BOOL closed_;
    // Name, mail and body of the post being sent, to tell whether they were
    // edited while it was sent.
    NSString* sentPost_;
}

- (void) setThread: (SFThread*) th;
- (SFThread*) thread;
- (NSMutableString*) body;

- (IBAction) post: (id) sender;

@end
