/* This file is not copyrighted and may be used freely. */

#import "TabbedWebView.h"
#import <WebKit/WebKit.h>

@interface NSImage(TileInRect)
- (BOOL) tileInRect: (NSRect) dstRect
		   fromRect: (NSRect) srcRect
		   fraction: (float) fraction;
@end

enum {
    TAB_HEIGHT = 24,
    TAB_WIDTH_MAX = 250,
    TAB_WIDTH_MIN = 50,
};
static NSImage* TAB_BACKGROUND = nil;
static NSImage* TAB_CLOSE_ACTIVE = nil;
static NSImage* TAB_CLOSE_INACTIVE = nil;

@implementation TabbedWebView
- (void) estimateChanged: (NSNotification*) n
{
    [self setNeedsDisplay: YES];
}

- (void) drawWithWebViewAtIndex: (int) i
{
    WebView* view = (WebView*) [[self webViews] objectAtIndex: i];
    
    NSRect rect;

    rect.size.width = tabWidth_;
    rect.size.height = TAB_HEIGHT;
    rect.origin.x = tabWidth_ * i;
    rect.origin.y = [self frame].size.height - rect.size.height;
    
    if (i == selected_) {
        [TAB_BACKGROUND tileInRect: NSMakeRect(tabWidth_ * i + 4,  [self frame].size.height - rect.size.height,
                                          tabWidth_ - 8, TAB_HEIGHT)
                     fromRect: NSMakeRect(4, 0, 4, TAB_HEIGHT)
                     fraction: 1.0];
        [TAB_BACKGROUND dissolveToPoint: NSMakePoint(tabWidth_ * i, [self frame].size.height - rect.size.height)
                          fromRect: NSMakeRect(0, 0, 4, TAB_HEIGHT)
                          fraction: 1.0];
        [TAB_BACKGROUND dissolveToPoint: NSMakePoint(tabWidth_ * (i+1) - 4, [self frame].size.height - rect.size.height)
                          fromRect: NSMakeRect(8, 0, 4, TAB_HEIGHT)
                          fraction: 1.0];
    } else {
        int w = tabWidth_;
        if (i+1 != selected_) {
            [TAB_BACKGROUND dissolveToPoint: NSMakePoint(tabWidth_ * (i+1) - 4, [self frame].size.height - rect.size.height)
                              fromRect: NSMakeRect(16, 0, 4, TAB_HEIGHT)
                              fraction: 1.0];
            w -= 4;
        }
        [TAB_BACKGROUND tileInRect: NSMakeRect(tabWidth_ * i,  [self frame].size.height - rect.size.height,
                                          w, 24)
                     fromRect: NSMakeRect(12, 0, 4, TAB_HEIGHT)
                     fraction: 1.0];
    }
    
    NSString* title = [view valueForKey: @"mainFrameTitle"];
    if (!title || [title length] == 0) {
        title = @"Untitled";
    }
				
    // Button
    NSButton* button = [buttons_ objectAtIndex: i];
    [button setTag: i];

    if (i == selected_) {
        [button setImage: TAB_CLOSE_ACTIVE];
    } else {
        [button setImage: TAB_CLOSE_INACTIVE];
    }

    if ([self numberOfWebViews] > 1) {
        [button setHidden: NO];

        rect.size.width = 16;
        rect.size.height = 16;
        rect.origin.x = tabWidth_ * i + 6;
        rect.origin.y = [self frame].size.height - TAB_HEIGHT + 4;
        [button setFrame: rect];
    } else {
        [button setHidden: YES];
    }
        
    // Indicator
    NSProgressIndicator* indicator = [indicators_ objectAtIndex: i];

    rect.size.width = 16;
    rect.size.height = 16;
    rect.origin.x = tabWidth_ * i + (tabWidth_ - 20);
    rect.origin.y = [self frame].size.height - TAB_HEIGHT + 5;
    
    [indicator setFrame: rect];
    if ([view estimatedProgress] == 0.0 || [view estimatedProgress] == 1.0) {
        [indicator stopAnimation: nil];
    } else {
        [indicator startAnimation: nil];
    }

    // Text
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    [style setLineBreakMode: NSLineBreakByTruncatingTail];
    [style setFirstLineHeadIndent: 0];
    [style setTailIndent: 0];
    
    NSMutableAttributedString* str;
    str = [[NSMutableAttributedString alloc] initWithString: title];
    [str addAttribute: NSFontAttributeName
                value: [NSFont systemFontOfSize: [NSFont smallSystemFontSize]]
                range: NSMakeRange(0, [str length])];
    [str addAttribute: NSParagraphStyleAttributeName
                value: style
                range: NSMakeRange(0, [str length])];
    
    rect.size.width = tabWidth_ - 48;
    rect.size.height = TAB_HEIGHT;
    if ([self numberOfWebViews] > 1) {
        rect.origin.x = (tabWidth_ * i) + 24;
    } else {
        rect.origin.x = (tabWidth_ * i) + 8;
    }
    rect.origin.y = [self frame].size.height - rect.size.height - 4;

    [str drawInRect: rect];
    [str release];
}

- (NSArray*) webViews
{
	return webViews_;
}

- (int) numberOfWebViews
{
    NSArray* ary = [self webViews];
    return [ary count];
}

- (int) indexOfWebView: (WebView*) wv
{
    NSArray* ary = [self webViews];
    
    int i;
    for (i = 0; i < [ary count]; i++) {
        if ([ary objectAtIndex: i] == wv) {
            return i;
        }
    }
    
    return -1;
}

- (void) setFrame: (NSRect) frame
{
	WebView* wv = [self selectedWebView];
    
    NSSize size = frame.size;
    size.height -= TAB_HEIGHT;
    
    [wv setFrameSize: size];
    WebFrameView* frameView = [[wv mainFrame] frameView];
    [frameView setFrameSize: size];
    
#if 0
    NSView* docView = [frameView documentView];
    size.height = [docView frame].size.height;
    [docView setFrameSize: size];
#endif
    
    [super setFrame: frame];
}

- (void) addWebView: (WebView*) wv
{
	// Add New
    [webViews_ addObject: wv];
	[self addSubview: wv];
    
	[self selectWebViewAtIndex: [self numberOfWebViews] - 1];
	
	NSRect frame;
	frame.origin = NSMakePoint(0, 0);
	frame.size = [self frame].size;
	frame.size.height -= TAB_HEIGHT;
	[wv setFrame: frame];
	
    [wv setAutoresizingMask: NSViewNotSizable];
    
    // Indicator
    NSProgressIndicator* indicator;
    indicator = [[NSProgressIndicator alloc] init];
    [indicator setStyle: NSProgressIndicatorSpinningStyle];
    [indicator setDisplayedWhenStopped: NO];
    
	[self addSubview: indicator];    
    [indicators_ addObject: indicator];
    
    // Button
    NSButton* button;
    button = [[NSButton alloc] init];
    [button setTarget: self];
    [button setAction: @selector(closeTab:)];
    [button setButtonType: NSMomentaryChangeButton];
    [button setBordered: NO];
    [button setImagePosition: NSImageOnly];
    [button setAutoresizingMask: NSViewNotSizable];
    [button setImage: TAB_CLOSE_ACTIVE];
    
	[self addSubview: button];
    [buttons_ addObject: button];
    
#if 0
	[wv addObserver: self
		 forKeyPath: @"mainFrameTitle" 
			options: NSKeyValueObservingOptionNew
			context: nil];
#endif
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver: self
               selector: @selector(estimateChanged:)
                   name: WebViewProgressEstimateChangedNotification 
                 object: wv];
	
	[self setNeedsDisplay: YES];
}

- (void) removeWebView: (WebView*) view
{
	[view removeFromSuperview];
    [webViews_ removeObject: view];
    
    NSProgressIndicator* indicator = (NSProgressIndicator*) [indicators_ lastObject];
    [indicator stopAnimation: nil];
    [indicator removeFromSuperview];
    [indicators_ removeObject: indicator];
    
    NSButton* button = (NSButton*) [buttons_ lastObject];
    [button removeFromSuperview];
    [buttons_ removeObject: button];
    
	if (selected_ < [self numberOfWebViews]) {
		[self selectWebViewAtIndex: selected_];
	} else {
		[self selectWebViewAtIndex: [self numberOfWebViews] - 1];
	}
    
	[self setNeedsDisplay: YES];
}

- (void) selectWebViewAtIndex: (int) index
{
	selected_ = index;
	
	NSArray* ary = [self webViews];
	int i;
	for (i = 0; i < [ary count]; i++) {
		WebView* wv = [ary objectAtIndex: i];
		if (i == selected_) {
			[delegate_ tabbedWebView: self
					didSelectWebView: wv];

			[wv setHidden: NO];
			[[self window] makeFirstResponder: wv];
		} else {
			[wv setHidden: YES];
		}
	}
    
    [self setFrame: [self frame]];
	[self setNeedsDisplay: YES];
}

- (void) selectWebView: (WebView*) wv
{
	[self selectWebViewAtIndex: [self indexOfWebView: wv]];
}

- (WebView*) selectedWebView
{
	if ([[self webViews] count] == 0) {
		return nil;
	}
	
	return [[self webViews] objectAtIndex: selected_]; 
}

- (WebView*) webViewAtIndex: (unsigned) index
{
    return [[self webViews] objectAtIndex: index];
}

- (void) setDelegate: (NSObject*) delegate
{
	[delegate_ release];
	delegate_ = [delegate retain];
}

- (NSObject*) delegate
{
	return delegate_;
}

- (IBAction) closeTab: (id) sender
{
    int index = [sender tag];
    [self removeWebView: [self webViewAtIndex: index]];
}

#pragma mark Override
- (id) initWithFrame: (NSRect) frame
{
    self = [super initWithFrame: frame];
	
	if (! TAB_BACKGROUND) {
		NSString* path;
        
        path = [NSString stringWithFormat: @"%@/tab.png", [[NSBundle mainBundle] resourcePath]];
		TAB_BACKGROUND = [[NSImage alloc] initWithContentsOfFile: path];

        path = [NSString stringWithFormat: @"%@/tabClose.png", [[NSBundle mainBundle] resourcePath]];
		NSImage* image = [[NSImage alloc] initWithContentsOfFile: path];
        
        TAB_CLOSE_ACTIVE = [[NSImage alloc] initWithSize: NSMakeSize(16, 16)];
        [TAB_CLOSE_ACTIVE lockFocus];
        [image drawInRect: NSMakeRect(0, 0, 16, 16)
                 fromRect: NSMakeRect(0, 16, 16, 16)
                operation: NSCompositeSourceOver
                 fraction: 1.0];
        [TAB_CLOSE_ACTIVE unlockFocus];
        
        TAB_CLOSE_INACTIVE = [[NSImage alloc] initWithSize: NSMakeSize(16, 16)];
        [TAB_CLOSE_INACTIVE lockFocus];
        [image drawInRect: NSMakeRect(0, 0, 16, 16)
                 fromRect: NSMakeRect(0, 0, 16, 16)
                operation: NSCompositeSourceOver
                 fraction: 1.0];
        [TAB_CLOSE_INACTIVE unlockFocus];
    }
    
    webViews_ = [[NSMutableArray alloc] init];
    indicators_ = [[NSMutableArray alloc] init];
    buttons_ = [[NSMutableArray alloc] init];
	
	selected_ = 0;
	delegate_ = nil;
	tabWidth_ = 100;
	
    return self;
}

- (void) dealloc
{
    [webViews_ release];
    [indicators_ release];
    [buttons_ release];
	
    [super dealloc];
}

- (BOOL) acceptsFirstResponder
{
	return YES;
}

- (void) drawRect: (NSRect) allRect
{	
	NSArray* ary = [self webViews];
    
	tabWidth_ = TAB_WIDTH_MAX;
	while (tabWidth_ * [ary count] > [self frame].size.width) {
		tabWidth_--;
	}
	if (tabWidth_ < TAB_WIDTH_MIN) {
		tabWidth_ = TAB_WIDTH_MIN;
	}
		
	int i;
	for (i = 0; i < [ary count]; i++) {
        [self drawWithWebViewAtIndex: i];
	}
	[TAB_BACKGROUND tileInRect: NSMakeRect(tabWidth_ * i,  [self frame].size.height - TAB_HEIGHT,
									  [self frame].size.width - tabWidth_ * i, 24)
				 fromRect: NSMakeRect(12, 0, 4, TAB_HEIGHT)
				 fraction: 1.0];
}

- (void) mouseDown: (NSEvent*) event
{
	NSPoint mouse = [self convertPoint: [event locationInWindow]
							  fromView: nil];
	int n = mouse.x / tabWidth_;
	if (n < [[self webViews] count]) {
		[self selectWebViewAtIndex: n];
	}
}

- (void) observeValueForKeyPath: (NSString*) path 
                       ofObject: (id) object
                         change: (NSDictionary*) change
                        context: (void*) context
{
    if ([path isEqualToString: @"mainFrameTitle"]) {
        [self setNeedsDisplay: YES];
    }
}

@end


@implementation NSImage(TileInRect)
- (BOOL) tileInRect: (NSRect) dstRect
		   fromRect: (NSRect) srcRect
		   fraction: (float) fraction
{
	int x;
	for (x = 0; x < dstRect.size.width; x++) {
		NSRect rect = dstRect;
		rect.origin.x += x;
		
		if (rect.origin.x + srcRect.size.width > dstRect.origin.x + dstRect.size.width) {
			srcRect.size.width = (rect.origin.x + srcRect.size.width) - (dstRect.origin.x + dstRect.size.width);
		}
		
		[self dissolveToPoint: rect.origin
					 fromRect: srcRect 
					 fraction: fraction];
	}
	return YES;
}
@end
