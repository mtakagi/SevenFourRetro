#import <Cocoa/Cocoa.h>

@class SFThread;

@interface SFPostWindowController : NSWindowController {
    IBOutlet NSComboBox* nameBox;
    IBOutlet NSComboBox* mailBox;
    IBOutlet NSTextView* bodyView;
    IBOutlet NSProgressIndicator* indicator;
    
    SFThread* thread_;
}

- (void) setThread: (SFThread*) th;
- (SFThread*) thread;
- (NSMutableString*) body;

- (IBAction) post: (id) sender;

@end
