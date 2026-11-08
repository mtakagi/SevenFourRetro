/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@interface SFSidePaneController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    IBOutlet NSView* baseView;
    IBOutlet NSOutlineView* outlineView;
    IBOutlet NSScrollView* scrollView;
	IBOutlet NSSearchField* searchField;

    NSString* keyword_;
    unsigned skipped_;
    id delegate_;
}

- (void) setAdditionalSearchField: (NSSearchField*) field;

- (void) setDelegate: (id) delegate;
- (NSView*) view;
- (NSOutlineView*) outlineView;
- (void) update;

- (IBAction) search: (id) sender;
- (IBAction) clicked: (id) sender;

@end

@interface NSObject(SFSidePaneControllerDelegate)
- (BOOL) openURL: (NSURL*) url;

- (NSDictionary*) boardTree;
- (BOOL) openBoard: (NSURL*) url
			 title: (NSString*) title;
@end


