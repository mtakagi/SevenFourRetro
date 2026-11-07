#import <Cocoa/Cocoa.h>


@interface SFImageWindowController : NSWindowController {
    IBOutlet NSButton* imageView;
    IBOutlet NSProgressIndicator* indicator;
    IBOutlet NSBox* loadingBox;
	IBOutlet NSTextField* messageField;
	
    
    NSURL* url_;
    NSMutableData* receivedData_;
}

+ (BOOL) isOpened: (NSURL*) url;

- (void) loadURL: (NSURL*) url;
- (IBAction) openURL: (id) sender;

@end
