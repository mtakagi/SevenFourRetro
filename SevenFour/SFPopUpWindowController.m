/* This file is not copyrighted and may be used freely. */

#import "SFPopUpWindowController.h"
#import "SFPageView.h"
#import "TemporaryPanel.h"

// The width of the window's border.
static const CGFloat BORDER = 1.0;

@implementation SFPopUpWindowController

- (id)initWithFrame:(NSRect)frame
{
    TemporaryPanel* panel = [[[TemporaryPanel alloc] initWithContentRect:frame
                                                               styleMask:NSWindowStyleMaskBorderless
                                                                 backing:NSBackingStoreBuffered
                                                                   defer:YES] autorelease];
    self = [super initWithWindow:panel];
    if (!self) {
        return nil;
    }
    [panel setCloseEvent:TemporaryPanelCloseWhenExited];

    [panel setHasShadow:YES];

    // A thin border, so the window stands out from the page under it.
    NSRect bounds = NSMakeRect(0, 0, frame.size.width, frame.size.height);
    NSView* content = [[[NSView alloc] initWithFrame:bounds] autorelease];
    [content setWantsLayer:YES];
    [[content layer] setBorderWidth:BORDER];
    [[content layer] setBorderColor:[[NSColor grayColor] CGColor]];
    [panel setContentView:content];

    pageView_ = [[SFPageView alloc] initWithFrame:NSInsetRect(bounds, BORDER, BORDER)
                             reportsContentHeight:YES];
    [pageView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [content addSubview:pageView_];
    [panel setInitialFirstResponder:pageView_];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentHeightDidChange:)
                                                 name:SFPageViewContentHeightDidChangeNotification
                                               object:pageView_];
    return self;
}

- (SFPageView*)pageView
{
    return pageView_;
}

// Fits the window to the page's height, within the screen. The bottom
// stays under the mouse, where the window was opened.
- (void)resizeToHeight:(CGFloat)height
{
    NSRect screen = [[[self window] screen] visibleFrame];
    if (NSIsEmptyRect(screen)) {
        screen = [[NSScreen mainScreen] visibleFrame];
    }
    NSRect rect = [[self window] frame];
    rect.size.height = height + BORDER * 2;

    if (NSMaxX(rect) > NSMaxX(screen)) {
        rect.origin.x = NSMaxX(screen) - rect.size.width;
    }
    if (NSMaxY(rect) > NSMaxY(screen)) {
        rect.origin.y = NSMaxY(screen) - rect.size.height;
    }
    TemporaryPanel* panel = (TemporaryPanel*) [self window];
    if (rect.size.height > screen.size.height) {
        rect.size.height = screen.size.height;
        rect.origin.y = screen.origin.y;

        // To scroll the page
        [panel setCanBecomeKeyWindow:YES];
        [panel makeKeyAndOrderFront:nil];
    }
    [panel setFrame:rect display:YES];
}

- (void)contentHeightDidChange:(NSNotification*)n
{
    CGFloat height = [[[n userInfo] objectForKey:SFPageViewContentHeightKey] doubleValue];
    if (height > 0) {
        [self resizeToHeight:height];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [pageView_ setPageDelegate:nil];
    [pageView_ release];
    [super dealloc];
}

@end
