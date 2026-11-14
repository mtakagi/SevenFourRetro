/* This file is not copyrighted and may be used freely. */

#import "TemporaryPanel.h"


@implementation TemporaryPanel

- (void)updateTrackingRect
{
    NSView* contentView = [self contentView];
    NSRect frame = [contentView frame];

    if (tag_) {
        [contentView removeTrackingRect:tag_];
    }
    tag_ = [contentView addTrackingRect:frame
                                  owner:self
                               userData:nil
                           assumeInside:YES];
}

- (id)initWithContentRect:(NSRect)contentRect
                styleMask:(NSWindowStyleMask)mask
                  backing:(NSBackingStoreType)type
                    defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:flag];

    closeEvent_ = TemporaryPanelCloseNone;
    [self setCanBecomeKeyWindow:NO];

    [self setReleasedWhenClosed:NO];
    [self setBecomesKeyOnlyIfNeeded:YES];

    [self setAcceptsMouseMovedEvents:YES];

    NSNotificationCenter* center;
    center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(applicationDidDeactive:)
                   name:NSApplicationDidResignActiveNotification
                 object:[NSApplication sharedApplication]];
    [center addObserver:self
               selector:@selector(windowDidResize:)
                   name:NSWindowDidResizeNotification
                 object:self];
#if 0
    tag_ = 0;
    [self updateTrackingRect];
#endif

    return self;
}

- (void)dealloc
{
    NSLog(@"TemporaryPanel %p - dealloc", self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setCloseEvent:(TemporaryPanelCloseEvent)event;
{
    closeEvent_ = event;
}


- (void)mouseExited:(NSEvent*)event
{
    [super mouseExited:event];

    if (closeEvent_ != TemporaryPanelCloseWhenExited)
        return;

    if (NSPointInRect([NSEvent mouseLocation], [self frame])) {
        return;
    }

    [self close];
}

- (void)setCanBecomeKeyWindow:(BOOL)flag
{
    canBecomeKeyWindow_ = flag;
}

- (BOOL)canBecomeKeyWindow
{
    return canBecomeKeyWindow_;
}

- (void)applicationDidDeactive:(NSNotification*)n
{
    if (closeEvent_ != TemporaryPanelCloseNone) {
        [self close];
    }
}

- (void)windowDidResize:(NSNotification*)n
{
    [self updateTrackingRect];
}

@end
