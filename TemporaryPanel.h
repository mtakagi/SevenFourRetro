/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

typedef enum {
    TemporaryPanelCloseNone,
    TemporaryPanelCloseWhenExited,
} TemporaryPanelCloseEvent;


@interface TemporaryPanel : NSPanel {
    NSTrackingRectTag tag_;
    TemporaryPanelCloseEvent closeEvent_;
    BOOL canBecomeKeyWindow_;
}

- (void) setCloseEvent: (TemporaryPanelCloseEvent) event;
- (void) setCanBecomeKeyWindow: (BOOL) flag;
@end
