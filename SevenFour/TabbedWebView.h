/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import "SFTabContent.h"

// The thread tabs: a tab bar over the views shown in the tabs (#27).
// It manages any NSView<SFTabContent> and knows nothing of WebKit. The name
// is kept because MainWindow.nib refers to the class (#29).
@interface TabbedWebView : NSView {
	NSObject* delegate_;
	int selected_;
	int tabWidth_;

    NSMutableArray* contents_;
    NSMutableArray* buttons_;
    NSMutableArray* indicators_;
}

- (NSView<SFTabContent>*) selectedContent;
- (NSView<SFTabContent>*) contentAtIndex: (unsigned) index;
- (int) indexOfContent: (NSView<SFTabContent>*) content;
- (int) numberOfContents;
- (NSArray*) contents;

// Adds a tab at the end and selects it.
- (void) addContent: (NSView<SFTabContent>*) content;
- (void) removeContent: (NSView<SFTabContent>*) content;
- (void) selectContent: (NSView<SFTabContent>*) content;
- (void) selectContentAtIndex: (int) n;

- (void) setDelegate: (NSObject*) delegate;
- (NSObject*) delegate;
@end

@interface NSObject(TabbedWebViewDelegate)
- (void) tabbedWebView: (TabbedWebView*) twv
	  didSelectContent: (NSView<SFTabContent>*) content;
@end
