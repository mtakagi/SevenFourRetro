/* This file is not copyrighted and may be used freely. */

#import "RatingCell.h"
#import "NSImage+SFSymbols.h"

@implementation RatingCell

static NSImage* STAR = NULL;

- (BOOL) trackMouse: (NSEvent*) event 
			 inRect: (NSRect) frame
			 ofView: (NSView*) view
	   untilMouseUp: (BOOL) untilMouseUp
{
	start_ = frame.origin;

	[super trackMouse: event 
			   inRect: frame
			   ofView: view
		 untilMouseUp: untilMouseUp];
	
	return YES;
}

- (BOOL) startTrackingAt: (NSPoint) start 
				  inView: (NSView*) view
{
	return YES;
}

- (BOOL) continueTracking: (NSPoint) last
					   at: (NSPoint) current
				   inView: (NSView*) view
{
	int value = (current.x - start_.x) / 16;
	if (value > 5) {
		value = 5;
	}
	[self setIntValue: value];
	
	return YES;
}

- (void) stopTracking: (NSPoint) last
				   at: (NSPoint) stop
			   inView: (NSView*) view 
			mouseIsUp: (BOOL) flag
{
	[super stopTracking: last
					 at: stop
				 inView: view 
			  mouseIsUp: flag];
}

- (void) drawInteriorWithFrame: (NSRect) frame 
						inView: (NSView*) view
{
    if (! STAR) {
		STAR = [[NSImage sf_imageWithSymbolName: @"star.fill"
									  pointSize: 10
										  color: [NSColor labelColor]
										   size: NSMakeSize(12, 12)] retain];
    }

	NSRect rect;
	rect.size = NSMakeSize(12, 12);
	rect.origin.x = frame.origin.x + 5;
	rect.origin.y = frame.origin.y + (frame.size.height - rect.size.height) / 2;

	int i;
    for (i = 0; i < [[self objectValue] intValue]; i++) {
		[STAR drawInRect: rect
				fromRect: NSZeroRect
			   operation: NSCompositingOperationSourceOver
				fraction: 1.0
		  respectFlipped: YES
				   hints: nil];
		rect.origin.x += 16;
    }
}

- (void) performClick: (id) sender {
	;
}

@end
