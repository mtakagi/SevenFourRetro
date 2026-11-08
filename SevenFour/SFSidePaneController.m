/* This file is not copyrighted and may be used freely. */

#import "SFSidePaneController.h"

@interface SFSidePaneController (Private)
- (void) setUpView;
@end

@implementation SFSidePaneController
- (void) setAdditionalSearchField: (NSSearchField*) field
{
    [field setTarget: self];
    [field setAction: @selector(search:)];
}

// The view SidePane.nib held (#29), made in code with the same layout: the
// search field along the top and the outline filling the rest.
- (void) makeView
{
    baseView = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 200, 300)];

    searchField = [[[NSSearchField alloc] initWithFrame: NSMakeRect(2, 279, 196, 19)] autorelease];
    [searchField setControlSize: NSControlSizeSmall];
    [searchField setFont: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]];
    [searchField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
    [searchField setTarget: self];
    [searchField setAction: @selector(search:)];
    [baseView addSubview: searchField];

    NSScrollView* scroll = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0, 0, 200, 277)] autorelease];
    [scroll setHasVerticalScroller: YES];
    [scroll setHasHorizontalScroller: YES];
    [scroll setAutohidesScrollers: YES];
    [scroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

    outlineView = [[[NSOutlineView alloc] initWithFrame: [[scroll contentView] bounds]] autorelease];
    NSTableColumn* column = [[[NSTableColumn alloc] initWithIdentifier: @"title"] autorelease];
    [column setWidth: 168];
    [column setMinWidth: 16];
    [column setMaxWidth: 1000];
    [column setResizingMask: NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask];
    [column setEditable: NO];
    [outlineView addTableColumn: column];
    [outlineView setOutlineTableColumn: column];
    [outlineView setHeaderView: nil];
    [outlineView setIntercellSpacing: NSMakeSize(3, 2)];
    [outlineView setIndentationPerLevel: 13];
    [outlineView setAutoresizesOutlineColumn: YES];
    [outlineView setAllowsMultipleSelection: YES];
    [outlineView setColumnAutoresizingStyle: NSTableViewLastColumnOnlyAutoresizingStyle];
    [outlineView setFocusRingType: NSFocusRingTypeNone];
    [outlineView setTarget: self];
    [outlineView setAction: @selector(clicked:)];
    [scroll setDocumentView: outlineView];
    [baseView addSubview: scroll];
}

- (id) init
{
    self = [super init];
	if (! self) {
		return nil;
	}
	
    delegate_ = nil;
    [self makeView];
    [self setUpView];
	
    return self;
}

- (void) dealloc
{
    [outlineView setDataSource: nil];
    [outlineView setDelegate: nil];
    [baseView release];
    [keyword_ release];
    [delegate_ release];
    [super dealloc];
}


- (void) setDelegate: (id) delegate
{
    [delegate_ release];
    delegate_ = [delegate retain];
}

- (NSOutlineView*) outlineView
{
    return outlineView;
}

- (NSView*) view
{
    return baseView;
}

- (void) update
{
    [outlineView reloadData];
}

- (BOOL) selectMatchedItem: (NSString*) keyword
                     items: (NSArray*) items
{
    int i;
    BOOL found = NO;

    for (i = 0; i < [items count]; i++) {
        NSDictionary* root = [items objectAtIndex: i];
        
        NSRange range;
        range = [[root objectForKey: @"title"] rangeOfString: keyword
                                                     options: NSCaseInsensitiveSearch];
        if (range.location != NSNotFound) {
            NSInteger row = [outlineView rowForItem: root];
            [outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                     byExtendingSelection: true];
            found |= YES;
        } else {
            found |= NO;
        }
        
        [outlineView expandItem: root];
        if (! [self selectMatchedItem: keyword
                                items: [root objectForKey: @"children"]]) {
            [outlineView collapseItem: root];
        }
    }
    return found;
}

- (void) selectMatchedItem: (NSString*) keyword
{
    [self selectMatchedItem: keyword
                      items: [[delegate_ boardTree] objectForKey: @"children"]];
}

- (IBAction) search: (id) sender
{
    NSString* keyword = [sender stringValue];
    if ([keyword_ isEqualToString: keyword]) {
        [self selectMatchedItem: keyword];        
    } else {
        [keyword_ release];
        keyword_ = [keyword retain];
        
        [outlineView selectRowIndexes: [NSIndexSet indexSet]
                 byExtendingSelection: false];
        
        [self selectMatchedItem: keyword];
    }

    [outlineView scrollRowToVisible: [[outlineView selectedRowIndexes] firstIndex]];
}

- (IBAction) clicked: (id) sender
{
    id item;    
    item = [outlineView itemAtRow: [outlineView selectedRow]];
    
    if ([item objectForKey: @"url"] != nil) {
#if 1
        [delegate_ openURL: [NSURL URLWithString: [item objectForKey: @"url"]]];
#else
        [delegate_ openBoard: [NSURL URLWithString: [item objectForKey: @"url"]]
					   title: [item objectForKey: @"title"]];
#endif
    }
}

- (IBAction) deleteItem: (id) sender
{
    id item;    
    item = [outlineView itemAtRow: [outlineView selectedRow]];    
}

- (void) setUpView
{
    [outlineView setDataSource: self];
    [outlineView setDelegate: self];
	
	[searchField setFocusRingType: NSFocusRingTypeNone];
	
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	// Font
	NSFont* font = [NSFont fontWithName: [defaults stringForKey: @"BoardTreeFontFamily"]
								   size: [defaults floatForKey: @"BoardTreeFontSize"]];
	[outlineView setRowHeight: [[[[NSLayoutManager alloc] init] autorelease] defaultLineHeightForFont: font] + 2];
	[[[outlineView tableColumnWithIdentifier: @"title"] dataCell] setFont: font];

	if ([defaults boolForKey: @"ShowSearchFieldInSidePane"]) {
		[searchField setHidden: NO];
    } else {
		[searchField setHidden: YES];
		
        NSView* view = [[outlineView superview] superview];
		[view setFrame: [baseView frame]];
	}
}

// NSOutlineView dataSource
- (BOOL) outlineView: (NSOutlineView*) view 
    isItemExpandable: (id) parent
{
    id children;
    
    if (! parent) {
        parent = [delegate_ boardTree];
    }
    
    children = [parent objectForKey: @"children"];
    return children != nil;
}

- (NSInteger) outlineView: (NSOutlineView*) view
    numberOfChildrenOfItem: (id) parent
{
    if (! parent) {
        parent = [delegate_ boardTree];
    }
    
    return [(NSArray*)[parent objectForKey: @"children"] count];
}

- (id) outlineView: (NSOutlineView*) view
             child: (NSInteger) index ofItem: (id) parent
{
    if (! parent) {
        parent = [delegate_ boardTree];
    }
    return [[parent objectForKey: @"children"] objectAtIndex: index];
}

- (id) outlineView: (NSOutlineView*) view
    objectValueForTableColumn: (NSTableColumn*) column
            byItem: (id) item
{
    return [item valueForKey: [column identifier]];
}

@end
