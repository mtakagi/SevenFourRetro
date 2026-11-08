/* This file is not copyrighted and may be used freely. */

#import "SFThreePaneView.h"

// The smallest sizes of the panes (points).
static const CGFloat SIDE_MIN_WIDTH = 40;
static const CGFloat MAIN_MIN_WIDTH = 100;
static const CGFloat PANE_MIN_SIZE = 24;   // the top and bottom views (the tab bar is 24 high)

// The sizes of a first window: the side view gets a fifth of the width, the
// top view two fifths of the main area.
static const CGFloat SIDE_DEFAULT_RATIO = 0.2;
static const CGFloat TOP_DEFAULT_RATIO = 0.4;

// The thin dividers can be dragged this far on either side of the line.
static const CGFloat DIVIDER_GRIP = 3;

// Where the view this replaced (HTThreePaneSplitView) saved the sizes: a
// dictionary under "HTThreePaneSplitView_<autosave name>", with the side
// view's width ("sideViewtWidth") and the top view's height or width
// ("topViewStretch"), in points.
static NSString* const OLD_AUTOSAVE_PREFIX = @"HTThreePaneSplitView_";

@implementation SFThreePaneView

#pragma mark Views

- (void) setSideView: (NSView*) view
{
    [sideView_ removeFromSuperview];
    sideView_ = view;
    [outer_ insertArrangedSubview: view atIndex: 0];
    // The side view keeps its width when the window is resized.
    [outer_ setHoldingPriority: NSLayoutPriorityDefaultLow + 10 forSubviewAtIndex: 0];
    [outer_ setHoldingPriority: NSLayoutPriorityDefaultLow forSubviewAtIndex: 1];
}

- (void) setTopView: (NSView*) view
{
    [topView_ removeFromSuperview];
    topView_ = view;
    [inner_ insertArrangedSubview: view atIndex: 0];
}

- (void) setBottomView: (NSView*) view
{
    [bottomView_ removeFromSuperview];
    bottomView_ = view;
    [inner_ addArrangedSubview: view];
    // The top view (the thread list) keeps its size when the window is
    // resized; the bottom view (the thread) takes the rest.
    [inner_ setHoldingPriority: NSLayoutPriorityDefaultLow + 10 forSubviewAtIndex: 0];
    [inner_ setHoldingPriority: NSLayoutPriorityDefaultLow forSubviewAtIndex: 1];
}

- (void) setVertical: (BOOL) flag
{
    if ([inner_ isVertical] == flag) {
        return;
    }
    [inner_ setVertical: flag];
    [inner_ adjustSubviews];
}

#pragma mark Sizes

// The size of the main area along the inner split.
- (CGFloat) mainLength
{
    NSSize size = [inner_ bounds].size;
    return [inner_ isVertical] ? size.width : size.height;
}

- (CGFloat) topLength
{
    NSSize size = [topView_ frame].size;
    return [inner_ isVertical] ? size.width : size.height;
}

- (void) setSideWidth: (CGFloat) width
{
    [outer_ setPosition: round(width) ofDividerAtIndex: 0];
}

- (void) setTopLength: (CGFloat) length
{
    [inner_ setPosition: round(length) ofDividerAtIndex: 0];
}

// The sizes for a window without saved ones: those the old view saved, if
// they fit, or the default ones.
- (void) setUpSizesFromOldName: (NSString*) name
                    restoredSide: (BOOL) restoredSide
                    restoredMain: (BOOL) restoredMain
{
    NSDictionary* old = [[NSUserDefaults standardUserDefaults]
                            dictionaryForKey: [OLD_AUTOSAVE_PREFIX stringByAppendingString: name]];
    [self layoutSubtreeIfNeeded];

    if (! restoredSide) {
        CGFloat width = [[old objectForKey: @"sideViewtWidth"] doubleValue];
        CGFloat total = [outer_ bounds].size.width;
        if (width < SIDE_MIN_WIDTH || width > total - MAIN_MIN_WIDTH) {
            width = MAX(SIDE_MIN_WIDTH, total * SIDE_DEFAULT_RATIO);
        }
        [self setSideWidth: width];
    }
    if (! restoredMain) {
        // The old view saved the whole height while showing the top view
        // alone; that isn't a size to start with.
        CGFloat length = [[old objectForKey: @"topViewStretch"] doubleValue];
        CGFloat total = [self mainLength];
        if (length < PANE_MIN_SIZE || length > total - PANE_MIN_SIZE) {
            length = total * TOP_DEFAULT_RATIO;
        }
        [self setTopLength: length];
    }
}

- (void) setAutosaveName: (NSString*) name
{
    NSString* sideName = [name stringByAppendingString: @" Side"];
    NSString* mainName = [name stringByAppendingString: @" Main"];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    BOOL savedSide = [defaults objectForKey: [@"NSSplitView Subview Frames " stringByAppendingString: sideName]] != nil;
    BOOL savedMain = [defaults objectForKey: [@"NSSplitView Subview Frames " stringByAppendingString: mainName]] != nil;

    if (! savedSide || ! savedMain) {
        [self setUpSizesFromOldName: name restoredSide: savedSide restoredMain: savedMain];
    }
    [outer_ setAutosaveName: sideName];
    [inner_ setAutosaveName: mainName];

    // A new window shows the side view even if the last one hid it.
    [self showSideView: YES];
}

#pragma mark Showing and hiding

// After a pane is shown or hidden: the split views leave the divider they
// no longer show drawn until they are displayed again.
- (void) panesDidChange
{
    for (NSSplitView* view in [NSArray arrayWithObjects: outer_, inner_, nil]) {
        [view setNeedsLayout: YES];
        [view layoutSubtreeIfNeeded];
        [view setNeedsDisplay: YES];
    }
}

- (BOOL) isSideViewVisible
{
    return sideView_ != nil && ! [sideView_ isHidden];
}

- (void) showSideView: (BOOL) flag
{
    if (! sideView_ || [self isSideViewVisible] == flag) {
        return;
    }
    if (! flag) {
        sidePosition_ = [sideView_ frame].size.width;
    }
    [sideView_ setHidden: ! flag];
    [outer_ adjustSubviews];
    if (flag && sidePosition_ > 0) {
        [self setSideWidth: sidePosition_];
    }
    [self panesDidChange];
}

- (IBAction) toggleSideView: (id) sender
{
    [self showSideView: ! [self isSideViewVisible]];
}

- (BOOL) isBottomViewVisible
{
    return bottomView_ != nil && ! [bottomView_ isHidden];
}

- (void) showBottomView: (BOOL) flag
{
    if (! bottomView_ || [self isBottomViewVisible] == flag) {
        return;
    }
    if (! flag) {
        bottomPosition_ = [self topLength];
    }
    [bottomView_ setHidden: ! flag];
    [inner_ adjustSubviews];
    if (flag) {
        CGFloat length = bottomPosition_;
        if (length <= 0 || length > [self mainLength] - PANE_MIN_SIZE) {
            length = [self mainLength] * TOP_DEFAULT_RATIO;
        }
        [self setTopLength: length];
    }
    [self panesDidChange];
}

- (IBAction) toggleBottomView: (id) sender
{
    [self showBottomView: ! [self isBottomViewVisible]];
}

#pragma mark NSSplitViewDelegate

- (CGFloat) splitView: (NSSplitView*) view
constrainMinCoordinate: (CGFloat) proposed
          ofSubviewAt: (NSInteger) index
{
    return proposed + (view == outer_ ? SIDE_MIN_WIDTH : PANE_MIN_SIZE);
}

- (CGFloat) splitView: (NSSplitView*) view
constrainMaxCoordinate: (CGFloat) proposed
          ofSubviewAt: (NSInteger) index
{
    return proposed - (view == outer_ ? MAIN_MIN_WIDTH : PANE_MIN_SIZE);
}

// The panes are hidden with the toolbar's buttons, not by dragging.
- (BOOL) splitView: (NSSplitView*) view canCollapseSubview: (NSView*) subview
{
    return NO;
}

- (BOOL) splitView: (NSSplitView*) view shouldHideDividerAtIndex: (NSInteger) index
{
    NSArray* panes = [view arrangedSubviews];
    return [[panes objectAtIndex: index] isHidden] || [[panes objectAtIndex: index + 1] isHidden];
}

- (NSRect) splitView: (NSSplitView*) view
       effectiveRect: (NSRect) drawnRect
        forDrawnRect: (NSRect) drawn
    ofDividerAtIndex: (NSInteger) index
{
    if ([view isVertical]) {
        return NSInsetRect(drawn, -DIVIDER_GRIP, 0);
    }
    return NSInsetRect(drawn, 0, -DIVIDER_GRIP);
}

#pragma mark Override

- (NSSplitView*) makeSplitView: (BOOL) vertical
{
    NSSplitView* view = [[[NSSplitView alloc] initWithFrame: [self bounds]] autorelease];
    [view setVertical: vertical];
    [view setDividerStyle: NSSplitViewDividerStyleThin];
    [view setDelegate: self];
    [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    return view;
}

- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];
    if (! self) {
        return nil;
    }
    outer_ = [self makeSplitView: YES];
    [self addSubview: outer_];
    inner_ = [self makeSplitView: NO];
    [outer_ addArrangedSubview: inner_];
    return self;
}

- (void) dealloc
{
    [outer_ setDelegate: nil];
    [inner_ setDelegate: nil];
    [super dealloc];
}

@end
