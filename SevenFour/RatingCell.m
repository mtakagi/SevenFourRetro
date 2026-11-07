/* This file is not copyrighted and may be used freely. */

#import "RatingCell.h"

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
#if 1
		NSString* path;
		path = [[NSBundle mainBundle] pathForResource: @"star" ofType: @"png"];

		STAR = [[NSImage alloc] initWithContentsOfFile: path];
#else
        STAR = nil;
#endif
   }

	NSPoint point = frame.origin;
	point.y += (frame.size.height - 12) / 2;
	
	if([view isFlipped]) {
		point.y += [STAR size].height;
	}
    
	int i;
	point.x += 5;
    for (i = 0; i < [[self objectValue] intValue]; i++) {
        [STAR dissolveToPoint: point fraction: 1.0];
		point.x += 16;
    }
}

- (void) performClick: (id) sender {
	;
}

@end
