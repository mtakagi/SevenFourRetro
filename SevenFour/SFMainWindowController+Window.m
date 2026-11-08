/* This file is not copyrighted and may be used freely. */

#import "SFMainWindowController+Window.h"

#import "SFThreePaneView.h"
#import "RatingCell.h"
#import "SFStateCell.h"
#import "TabbedWebView.h"
#import "WhiteFormatter.h"

// A column of the thread list, bound to the threads' key (its identifier).
static NSTableColumn* threadListColumn(NSString* identifier, NSString* title,
                                       CGFloat width, CGFloat minWidth, CGFloat maxWidth,
                                       NSTextAlignment alignment, NSLineBreakMode lineBreak)
{
    NSTableColumn* column = [[[NSTableColumn alloc] initWithIdentifier: identifier] autorelease];
    [[column headerCell] setStringValue: title];
    [column setWidth: width];
    [column setMinWidth: minWidth];
    [column setMaxWidth: maxWidth];
    [column setResizingMask: NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask];
    // Only the rating is set by the user; an editable column makes Tab in
    // the list start editing it (#46).
    [column setEditable: NO];
    [column setSortDescriptorPrototype:
        [[[NSSortDescriptor alloc] initWithKey: identifier
                                     ascending: NO
                                      selector: @selector(compare:)] autorelease]];
    NSCell* cell = [column dataCell];
    [cell setAlignment: alignment];
    [cell setLineBreakMode: lineBreak];
    return column;
}

static NSTextField* label(NSString* string, NSRect frame)
{
    NSTextField* field = [NSTextField labelWithString: string];
    [field setFrame: frame];
    return field;
}

static NSSearchField* toolbarSearchField(id target, SEL action)
{
    NSSearchField* field = [[[NSSearchField alloc] initWithFrame: NSMakeRect(0, 0, 150, 19)] autorelease];
    [field setControlSize: NSControlSizeSmall];
    [field setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
    [field setAutoresizingMask: NSViewWidthSizable];
    [field setTarget: target];
    [field setAction: action];
    return field;
}

// The view of a toolbar item: view in a box of a fixed size, as in the nib.
// The toolbar sizes its items' views with Auto Layout; a search field put
// in the toolbar directly is also drawn without its bezel.
static NSView* toolbarItemView(NSView* view, NSSize size)
{
    NSView* box = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, size.width, size.height)] autorelease];
    [box addSubview: view];
    [[[box widthAnchor] constraintEqualToConstant: size.width] setActive: YES];
    [[[box heightAnchor] constraintEqualToConstant: size.height] setActive: YES];
    return box;
}

@implementation SFMainWindowController (Window)

// The document's board (selection.threadList) is the content of the thread
// list; the progress indicator follows the document's selection.isWorking.
- (void) makeControllers
{
    documentController_ = [[NSObjectController alloc] init];
    [documentController_ bind: NSContentObjectBinding
                     toObject: self
                  withKeyPath: @"document"
                      options: nil];

    threadsController = [[SearchableArrayController alloc] init];
    [threadsController setEditable: NO];
    [threadsController setClearsFilterPredicateOnInsertion: NO];
    [threadsController bind: NSContentArrayBinding
                   toObject: documentController_
                withKeyPath: @"selection.threadList"
                    options: nil];
}

// The thread list: a table of the board's threads in a scroll view. Its
// columns are bound to the threads controller (the table binds its content,
// selection and sort descriptors to it in turn).
- (NSView*) makeThreadList
{
    NSView* container = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 640, 220)] autorelease];

    NSScrollView* scroll = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 1, 640, 220)] autorelease];
    [scroll setHasVerticalScroller: YES];
    [scroll setHasHorizontalScroller: YES];
    [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

    threadListView = [[[NSTableView alloc] initWithFrame: [[scroll contentView] bounds]] autorelease];
    [threadListView setIntercellSpacing: NSMakeSize(3, 2)];
    [threadListView setAllowsMultipleSelection: NO];
    [threadListView setAllowsEmptySelection: YES];
    [threadListView setAllowsColumnReordering: YES];
    [threadListView setAllowsColumnResizing: YES];
    [threadListView setUsesAlternatingRowBackgroundColors: YES];
    [threadListView setColumnAutoresizingStyle: NSTableViewLastColumnOnlyAutoresizingStyle];
    [threadListView setFocusRingType: NSFocusRingTypeNone];
    // Full-width rows, as with the nib: the automatic style would make them
    // inset when the list is the leftmost pane (the board list hidden).
    [threadListView setStyle: NSTableViewStyleFullWidth];

    NSTableColumn* column;
    NSDictionary* options = nil;
    NSArray* columns = [NSArray arrayWithObjects:
        threadListColumn(@"state", @"", 32, 10, 1000, NSTextAlignmentLeft, NSLineBreakByTruncatingTail),
        threadListColumn(@"index", @"No.", 40, 40, 1000, NSTextAlignmentRight, NSLineBreakByClipping),
        threadListColumn(@"subject", @"タイトル", 253, 8, 1000, NSTextAlignmentLeft, NSLineBreakByClipping),
        threadListColumn(@"count", @"レス数", 50, 10, 1000, NSTextAlignmentRight, NSLineBreakByClipping),
        threadListColumn(@"local", @"既得", 50, 26, 1000, NSTextAlignmentRight, NSLineBreakByClipping),
        threadListColumn(@"delta", @"差分", 50, 10, 1000, NSTextAlignmentRight, NSLineBreakByClipping),
        threadListColumn(@"rate", @"レート", 100, 4, 100, NSTextAlignmentLeft, NSLineBreakByClipping),
        threadListColumn(@"number", @"DAT", 50, 10, 1000, NSTextAlignmentLeft, NSLineBreakByTruncatingTail),
        threadListColumn(@"creationDate", @"作成日", 50, 10, 1000, NSTextAlignmentLeft, NSLineBreakByTruncatingTail),
        threadListColumn(@"pace", @"ペース", 50, 37, 1000, NSTextAlignmentRight, NSLineBreakByTruncatingTail),
        nil];
    for (column in columns) {
        NSString* identifier = [column identifier];
        if ([identifier isEqualToString: @"state"]) {
            [column setResizingMask: NSTableColumnNoResizing];
            [column setDataCell: [[[SFStateCell alloc] init] autorelease]];
            options = nil;
        } else if ([identifier isEqualToString: @"rate"]) {
            // Set by clicking or dragging in the cell.
            [column setEditable: YES];
            [column setDataCell: [[[RatingCell alloc] init] autorelease]];
            options = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithBool: YES], NSConditionallySetsEnabledBindingOption,
                [NSNumber numberWithBool: NO], NSConditionallySetsEditableBindingOption,
                nil];
        } else {
            options = nil;
        }
        [threadListView addTableColumn: column];
        [column bind: NSValueBinding
            toObject: threadsController
         withKeyPath: [@"arrangedObjects." stringByAppendingString: identifier]
             options: options];
    }

    WhiteFormatter* white;
    white = [[[WhiteFormatter alloc] init] autorelease];
    [white setMinValue: -1];
    [[[threadListView tableColumnWithIdentifier: @"delta"] dataCell] setFormatter: white];
    white = [[[WhiteFormatter alloc] init] autorelease];
    [white setMinValue: 0];
    [[[threadListView tableColumnWithIdentifier: @"local"] dataCell] setFormatter: white];

    NSNumberFormatter* pace = [[[NSNumberFormatter alloc] init] autorelease];
    [pace setFormatterBehavior: NSNumberFormatterBehavior10_4];
    [pace setPositiveFormat: @"#,##0.000"];
    [pace setNegativeFormat: @"-#,##0.000"];
    [[[threadListView tableColumnWithIdentifier: @"pace"] dataCell] setFormatter: pace];

    // The first two items never had actions; they are shown disabled, as
    // with the nib.
    NSMenu* menu = [[[NSMenu alloc] initWithTitle: @"Menu"] autorelease];
    [menu addItemWithTitle: @"情報を見る" action: NULL keyEquivalent: @""];
    [menu addItemWithTitle: @"ログファイルを表示" action: NULL keyEquivalent: @""];
    [menu addItem: [NSMenuItem separatorItem]];
    [[menu addItemWithTitle: @"ログを削除" action: @selector(removeThread:) keyEquivalent: @""]
        setTarget: self];
    [threadListView setMenu: menu];

    [threadListView setTarget: self];
    [scroll setDocumentView: threadListView];
    [container addSubview: scroll];
    return container;
}

// Find in the thread: a field and the 前へ / 次へ buttons. Return in the
// field searches forward.
- (void) makeFindPanel
{
    findPanel = [[NSPanel alloc]
        initWithContentRect: NSMakeRect(251, 570, 360, 99)
                  styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                    backing: NSBackingStoreBuffered
                      defer: YES];
    [findPanel setTitle: @"検索"];
    [findPanel setReleasedWhenClosed: NO];
    [findPanel setHidesOnDeactivate: NO];
    [findPanel setContentMinSize: NSMakeSize(360, 89)];
    NSView* content = [findPanel contentView];

    NSTextField* text = label(@"検索:", NSMakeRect(17, 62, 35, 17));
    [text setAutoresizingMask: NSViewMaxXMargin | NSViewMinYMargin];
    [content addSubview: text];

    findField = [[[NSTextField alloc] initWithFrame: NSMakeRect(57, 60, 283, 22)] autorelease];
    [findField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
    [findField setTarget: self];
    [findField setAction: @selector(searchForward:)];
    [content addSubview: findField];

    NSButton* backward = [NSButton buttonWithTitle: @"前へ" target: self action: @selector(searchBackward:)];
    [backward setFrame: NSMakeRect(190, 12, 78, 32)];
    [backward setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
    [content addSubview: backward];

    NSButton* forward = [NSButton buttonWithTitle: @"次へ" target: self action: @selector(searchForward:)];
    [forward setFrame: NSMakeRect(268, 12, 78, 32)];
    [forward setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
    [content addSubview: forward];

    [findField setNextKeyView: backward];
    [backward setNextKeyView: forward];
    [forward setNextKeyView: findField];
    [findPanel setInitialFirstResponder: findField];
}

// The views of the toolbar's search and progress items.
- (void) makeToolbarViews
{
    // The controller keeps the item views (retained) while the toolbar
    // isn't showing them; each holds its field or indicator.
    threadSearchField = toolbarSearchField(self, @selector(searchThread:));
    toolbarThreadSearch = [toolbarItemView(threadSearchField, NSMakeSize(150, 22)) retain];
    // The board search field's target is set by the side pane.
    boardSearchField = toolbarSearchField(nil, NULL);
    toolbarBoardSearch = [toolbarItemView(boardSearchField, NSMakeSize(150, 22)) retain];

    NSProgressIndicator* indicator = [[[NSProgressIndicator alloc] initWithFrame: NSMakeRect(2, 2, 16, 16)] autorelease];
    [indicator setStyle: NSProgressIndicatorStyleSpinning];
    [indicator setControlSize: NSControlSizeSmall];
    [indicator setDisplayedWhenStopped: NO];
    [indicator bind: NSAnimateBinding
           toObject: documentController_
        withKeyPath: @"selection.isWorking"
            options: nil];
    progressIndicator_ = indicator;
    toolbarProgress = [toolbarItemView(indicator, NSMakeSize(20, 20)) retain];
}

- (NSWindow*) makeWindow
{
    [self makeControllers];
    [self makeFindPanel];
    [self makeToolbarViews];

    NSWindow* window = [[[NSWindow alloc]
        initWithContentRect: NSMakeRect(30, 124, 800, 500)
                  styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                             | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                             | NSWindowStyleMaskUnifiedTitleAndToolbar
                    backing: NSBackingStoreBuffered
                      defer: YES] autorelease];
    [window setReleasedWhenClosed: NO];
    [window setContentMinSize: NSMakeSize(320, 230)];
    // Tab goes through the panes in their order on screen, whichever tab
    // is selected (#46).
    [window setAutorecalculatesKeyViewLoop: YES];
    NSView* content = [window contentView];

    splitView = [[[SFThreePaneView alloc] initWithFrame: [content bounds]] autorelease];
    [splitView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [content addSubview: splitView];

    tabbedWebView = [[[TabbedWebView alloc] initWithFrame: NSMakeRect(0, 0, 320, 240)] autorelease];
    [tabbedWebView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

    [splitView setTopView: [self makeThreadList]];
    [splitView setBottomView: tabbedWebView];
    return window;
}

@end
