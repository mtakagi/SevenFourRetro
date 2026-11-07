/* This file is not copyrighted and may be used freely. */

#import "SFSidePaneController.h"

@implementation SFSidePaneController
- (void) setAdditionalSearchField: (NSSearchField*) field
{
    [field setTarget: self];
    [field setAction: @selector(search:)];
}

- (id) init
{
    self = [super init];
	if (! self) {
		return nil;
	}
	
    delegate_ = nil;
	
    return self;
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
            int row = [outlineView rowForItem: root];
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

#pragma mark Override

- (void) awakeFromNib
{
    [outlineView setDataSource: self];
    [outlineView setDelegate: self];
	
	[searchField setFocusRingType: NSFocusRingTypeNone];
	
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	// Font
	NSFont* font = [NSFont fontWithName: [defaults stringForKey: @"BoardTreeFontFamily"]
								   size: [defaults floatForKey: @"BoardTreeFontSize"]];
	[outlineView setRowHeight: [font defaultLineHeightForFont] + 2];
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

- (int) outlineView: (NSOutlineView*) view
    numberOfChildrenOfItem: (id) parent
{
    if (! parent) {
        parent = [delegate_ boardTree];
    }
    
    return [(NSArray*)[parent objectForKey: @"children"] count];
}

- (id) outlineView: (NSOutlineView*) view
             child: (int) index ofItem: (id) parent
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
