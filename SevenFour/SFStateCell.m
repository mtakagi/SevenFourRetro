/* This file is not copyrighted and may be used freely. */

#import "SFStateCell.h"
#import "SFThread.h"
#import "NSImage+SFSymbols.h"


@implementation SFThread (SFThreadState)
- (int)state
{
    if ([self isNew])
        return 1;
    else if ([self delta] > 0)
        return 2;
    else
        return 0;
}
@end


@implementation SFStateCell

enum { SF_STATE_ICON_SIZE = 12 };

// state 1 (new) is a red dot, state 2 (updated) is a blue dot.
static NSImage* SFStateIcon(int state)
{
    static NSImage* icons[3] = { nil, nil, nil };

    if (state < 1 || state > 2)
        return nil;

    if (!icons[state]) {
        NSColor* color = (state == 1) ? [NSColor systemRedColor] : [NSColor systemBlueColor];
        icons[state] = [[NSImage sf_imageWithSymbolName:@"circle.fill"
                                              pointSize:9
                                                  color:color
                                                   size:NSMakeSize(SF_STATE_ICON_SIZE, SF_STATE_ICON_SIZE)] retain];
    }
    return icons[state];
}

- (void)drawInteriorWithFrame:(NSRect)frame
                       inView:(NSView*)view
{
    NSImage* icon = SFStateIcon([self intValue]);
    if (!icon)
        return;

    // Center
    NSRect rect;
    rect.size = NSMakeSize(SF_STATE_ICON_SIZE, SF_STATE_ICON_SIZE);
    rect.origin.x = frame.origin.x + (frame.size.width - rect.size.width) / 2;
    rect.origin.y = frame.origin.y + (frame.size.height - rect.size.height) / 2;

    [icon drawInRect:rect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0
        respectFlipped:YES
                 hints:nil];
}

@end
