/* This file is not copyrighted and may be used freely. */

#import "SearchableArrayController.h"

@implementation SearchableArrayController
- (NSArray*) arrangeObjects: (NSArray*) objects
{
    if (! keyword_ || [keyword_ length] == 0) {
        return [super arrangeObjects:objects];
    }
    
    NSMutableArray* filtered = [NSMutableArray arrayWithCapacity: [objects count]];
    NSEnumerator* enumerator = [objects objectEnumerator];
    
    id item;
    while (item = [enumerator nextObject]) {
        if ([[item valueForKeyPath: @"subject"] rangeOfString: keyword_
                                                   options: NSCaseInsensitiveSearch].location != NSNotFound) {            
            [filtered addObject:item];
        }
    }
    
    return [super arrangeObjects: filtered];
}


- (IBAction) search: (id) sender
{
    [keyword_ release];
    keyword_ = [[sender stringValue] retain];

    [self rearrangeObjects];    
}

@end
