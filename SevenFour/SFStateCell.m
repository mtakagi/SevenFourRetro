/* This file is not copyrighted and may be used freely. */

#import "SFStateCell.h"
#import "SFThread.h"


@implementation SFThread(SFThreadState)
- (int) state
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

// state.png, (12 x 12) x 5 = (12 x 60)
NSImage* ICONS;

- (void) drawInteriorWithFrame: (NSRect) frame 
						inView: (NSView*) view
{
    if (! ICONS) {
#if 1
		NSString* path;
		path = [[NSBundle mainBundle] pathForResource: @"state" ofType: @"png"];
		
		ICONS = [[NSImage alloc] initWithContentsOfFile: path];
#else
        ICONS = nil;
#endif
	}
	
	// Center
	NSPoint point = frame.origin;
	point.x += (frame.size.width  - 12) / 2;
	point.y += (frame.size.height - 12) / 2;
	
	if([view isFlipped]) {
		point.y += 12;
	}
    
	NSRect rect;
	rect.origin.x = 0;
	rect.size.width  = 12;
	rect.size.height = 12;
	
	// (0, 0) == (left, bottom)
	rect.origin.y = 12 * [self intValue];
	
	[ICONS dissolveToPoint: point fromRect: rect fraction: 1.0];
}

@end
