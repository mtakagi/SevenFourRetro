/* This file is not copyrighted and may be used freely. */

#import "TabbedWebView.h"
#import "NSImage+SFSymbols.h"

@interface NSImage (TileInRect)
- (BOOL)tileInRect:(NSRect)dstRect
          fromRect:(NSRect)srcRect
          fraction:(float)fraction;
@end

// Sizes in points; CGFloat so they mix with view coordinates.
static const CGFloat TAB_HEIGHT = 24;
static const CGFloat TAB_WIDTH_MAX = 250;
static const CGFloat TAB_WIDTH_MIN = 50;
static NSImage* TAB_BACKGROUND = nil;
static NSImage* TAB_CLOSE_ACTIVE = nil;
static NSImage* TAB_CLOSE_INACTIVE = nil;

NSString* SFTabContentDidChangeNotification = @"SFTabContentDidChangeNotification";

@implementation TabbedWebView
// A tab's title or loading state changed: redraw the labels and spinners.
- (void)contentDidChange:(NSNotification*)n
{
    [self setNeedsDisplay:YES];
}

- (void)drawWithContentAtIndex:(int)i
{
    NSView<SFTabContent>* view = [[self contents] objectAtIndex:i];

    NSRect rect;

    rect.size.width = tabWidth_;
    rect.size.height = TAB_HEIGHT;
    rect.origin.x = tabWidth_ * i;
    rect.origin.y = [self frame].size.height - rect.size.height;

    if (i == selected_) {
        [TAB_BACKGROUND tileInRect:NSMakeRect(tabWidth_ * i + 4, [self frame].size.height - rect.size.height,
                                       tabWidth_ - 8, TAB_HEIGHT)
                          fromRect:NSMakeRect(4, 0, 4, TAB_HEIGHT)
                          fraction:1.0];
        [TAB_BACKGROUND drawAtPoint:NSMakePoint(tabWidth_ * i, [self frame].size.height - rect.size.height)
                           fromRect:NSMakeRect(0, 0, 4, TAB_HEIGHT)
                          operation:NSCompositingOperationSourceOver
                           fraction:1.0];
        [TAB_BACKGROUND drawAtPoint:NSMakePoint(tabWidth_ * (i + 1) - 4, [self frame].size.height - rect.size.height)
                           fromRect:NSMakeRect(8, 0, 4, TAB_HEIGHT)
                          operation:NSCompositingOperationSourceOver
                           fraction:1.0];
    } else {
        int w = tabWidth_;
        if (i + 1 != selected_) {
            [TAB_BACKGROUND drawAtPoint:NSMakePoint(tabWidth_ * (i + 1) - 4, [self frame].size.height - rect.size.height)
                               fromRect:NSMakeRect(16, 0, 4, TAB_HEIGHT)
                              operation:NSCompositingOperationSourceOver
                               fraction:1.0];
            w -= 4;
        }
        [TAB_BACKGROUND tileInRect:NSMakeRect(tabWidth_ * i, [self frame].size.height - rect.size.height,
                                       w, 24)
                          fromRect:NSMakeRect(12, 0, 4, TAB_HEIGHT)
                          fraction:1.0];
    }

    NSString* title = [view tabTitle];
    if (!title || [title length] == 0) {
        title = @"Untitled";
    }

    // Button
    NSButton* button = [buttons_ objectAtIndex:i];
    [button setTag:i];

    if (i == selected_) {
        [button setImage:TAB_CLOSE_ACTIVE];
    } else {
        [button setImage:TAB_CLOSE_INACTIVE];
    }

    if ([self numberOfContents] > 1) {
        [button setHidden:NO];

        rect.size.width = 16;
        rect.size.height = 16;
        rect.origin.x = tabWidth_ * i + 6;
        rect.origin.y = [self frame].size.height - TAB_HEIGHT + 4;
        [button setFrame:rect];
    } else {
        [button setHidden:YES];
    }

    // Indicator
    NSProgressIndicator* indicator = [indicators_ objectAtIndex:i];

    rect.size.width = 16;
    rect.size.height = 16;
    rect.origin.x = tabWidth_ * i + (tabWidth_ - 20);
    rect.origin.y = [self frame].size.height - TAB_HEIGHT + 5;

    [indicator setFrame:rect];
    if ([view isTabLoading]) {
        [indicator startAnimation:nil];
    } else {
        [indicator stopAnimation:nil];
    }

    // Text
    NSMutableParagraphStyle* style = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setLineBreakMode:NSLineBreakByTruncatingTail];
    [style setFirstLineHeadIndent:0];
    [style setTailIndent:0];

    NSMutableAttributedString* str;
    str = [[NSMutableAttributedString alloc] initWithString:title];
    [str addAttribute:NSFontAttributeName
                value:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
                range:NSMakeRange(0, [str length])];
    [str addAttribute:NSParagraphStyleAttributeName
                value:style
                range:NSMakeRange(0, [str length])];

    rect.size.width = tabWidth_ - 48;
    rect.size.height = TAB_HEIGHT;
    if ([self numberOfContents] > 1) {
        rect.origin.x = (tabWidth_ * i) + 24;
    } else {
        rect.origin.x = (tabWidth_ * i) + 8;
    }
    rect.origin.y = [self frame].size.height - rect.size.height - 4;

    [str drawInRect:rect];
    [str release];
}

- (NSArray*)contents
{
    return contents_;
}

- (int)numberOfContents
{
    return (int) [contents_ count];
}

- (int)indexOfContent:(NSView<SFTabContent>*)content
{
    NSUInteger i = [contents_ indexOfObjectIdenticalTo:content];
    return i == NSNotFound ? -1 : (int) i;
}

// The selected tab's view fills the area under the tab bar.
- (void)setFrame:(NSRect)frame
{
    NSSize size = frame.size;
    size.height -= TAB_HEIGHT;
    [[self selectedContent] setFrameSize:size];

    [super setFrame:frame];
}

- (void)addContent:(NSView<SFTabContent>*)content
{
    // Add New
    [contents_ addObject:content];
    [self addSubview:content];

    [self selectContentAtIndex:[self numberOfContents] - 1];

    NSRect frame;
    frame.origin = NSMakePoint(0, 0);
    frame.size = [self frame].size;
    frame.size.height -= TAB_HEIGHT;
    [content setFrame:frame];

    [content setAutoresizingMask:NSViewNotSizable];

    // Indicator
    NSProgressIndicator* indicator;
    indicator = [[NSProgressIndicator alloc] init];
    [indicator setStyle:NSProgressIndicatorStyleSpinning];
    [indicator setDisplayedWhenStopped:NO];

    [self addSubview:indicator];
    [indicators_ addObject:indicator];
    [indicator release];

    // Button
    NSButton* button;
    button = [[NSButton alloc] init];
    [button setTarget:self];
    [button setAction:@selector(closeTab:)];
    [button setButtonType:NSButtonTypeMomentaryChange];
    [button setBordered:NO];
    [button setImagePosition:NSImageOnly];
    [button setAutoresizingMask:NSViewNotSizable];
    [button setImage:TAB_CLOSE_ACTIVE];

    [self addSubview:button];
    [buttons_ addObject:button];
    [button release];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentDidChange:)
                                                 name:SFTabContentDidChangeNotification
                                               object:content];

    [self setNeedsDisplay:YES];
}

- (void)removeContent:(NSView<SFTabContent>*)content
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SFTabContentDidChangeNotification
                                                  object:content];
    [content removeFromSuperview];
    [contents_ removeObject:content];

    // The spinners and buttons are laid out by index when drawn, so the
    // last ones go.
    NSProgressIndicator* indicator = (NSProgressIndicator*) [indicators_ lastObject];
    [indicator stopAnimation:nil];
    [indicator removeFromSuperview];
    [indicators_ removeObject:indicator];

    NSButton* button = (NSButton*) [buttons_ lastObject];
    [button removeFromSuperview];
    [buttons_ removeObject:button];

    if (selected_ < [self numberOfContents]) {
        [self selectContentAtIndex:selected_];
    } else {
        [self selectContentAtIndex:[self numberOfContents] - 1];
    }

    [self setNeedsDisplay:YES];
}

- (void)selectContentAtIndex:(int)index
{
    selected_ = index;

    int i;
    for (i = 0; i < [self numberOfContents]; i++) {
        NSView<SFTabContent>* content = [contents_ objectAtIndex:i];
        if (i == selected_) {
            [delegate_ tabbedWebView:self
                    didSelectContent:content];

            [content setHidden:NO];
            [[self window] makeFirstResponder:content];
        } else {
            [content setHidden:YES];
        }
    }

    [self setFrame:[self frame]];
    [self setNeedsDisplay:YES];
}

- (void)selectContent:(NSView<SFTabContent>*)content
{
    [self selectContentAtIndex:[self indexOfContent:content]];
}

- (NSView<SFTabContent>*)selectedContent
{
    if ([contents_ count] == 0) {
        return nil;
    }

    return [contents_ objectAtIndex:selected_];
}

- (NSView<SFTabContent>*)contentAtIndex:(unsigned)index
{
    return [contents_ objectAtIndex:index];
}

- (void)setDelegate:(NSObject*)delegate
{
    [delegate_ release];
    delegate_ = [delegate retain];
}

- (NSObject*)delegate
{
    return delegate_;
}

- (IBAction)closeTab:(id)sender
{
    int index = (int) [sender tag];
    [self removeContent:[self contentAtIndex:index]];
}

#pragma mark Override
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    if (!TAB_BACKGROUND) {
        NSString* path;

        path = [NSString stringWithFormat:@"%@/tab.png", [[NSBundle mainBundle] resourcePath]];
        TAB_BACKGROUND = [[NSImage alloc] initWithContentsOfFile:path];

        TAB_CLOSE_ACTIVE = [[NSImage sf_imageWithSymbolName:@"xmark.circle.fill"
                                                  pointSize:12
                                                      color:[NSColor secondaryLabelColor]
                                                       size:NSMakeSize(16, 16)] retain];
        TAB_CLOSE_INACTIVE = [[NSImage sf_imageWithSymbolName:@"xmark.circle.fill"
                                                    pointSize:12
                                                        color:[NSColor tertiaryLabelColor]
                                                         size:NSMakeSize(16, 16)] retain];
    }

    contents_ = [[NSMutableArray alloc] init];
    indicators_ = [[NSMutableArray alloc] init];
    buttons_ = [[NSMutableArray alloc] init];

    selected_ = 0;
    delegate_ = nil;
    tabWidth_ = 100;

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [contents_ release];
    [indicators_ release];
    [buttons_ release];

    [super dealloc];
}

// The tab bar handles no keys: the selected content takes the focus (it is
// made first responder when selected). Accepting it left an invisible stop
// in the key view loop (#46).
- (BOOL)acceptsFirstResponder
{
    return NO;
}

- (void)drawRect:(NSRect)allRect
{
    NSArray* ary = [self contents];

    tabWidth_ = TAB_WIDTH_MAX;
    while (tabWidth_ * [ary count] > [self frame].size.width) {
        tabWidth_--;
    }
    if (tabWidth_ < TAB_WIDTH_MIN) {
        tabWidth_ = TAB_WIDTH_MIN;
    }

    int i;
    for (i = 0; i < [ary count]; i++) {
        [self drawWithContentAtIndex:i];
    }
    [TAB_BACKGROUND tileInRect:NSMakeRect(tabWidth_ * i, [self frame].size.height - TAB_HEIGHT,
                                   [self frame].size.width - tabWidth_ * i, 24)
                      fromRect:NSMakeRect(12, 0, 4, TAB_HEIGHT)
                      fraction:1.0];
}

- (void)mouseDown:(NSEvent*)event
{
    NSPoint mouse = [self convertPoint:[event locationInWindow]
                              fromView:nil];
    int n = mouse.x / tabWidth_;
    if (n < [self numberOfContents]) {
        [self selectContentAtIndex:n];
    }
}

@end


@implementation NSImage (TileInRect)
- (BOOL)tileInRect:(NSRect)dstRect
          fromRect:(NSRect)srcRect
          fraction:(float)fraction
{
    int x;
    for (x = 0; x < dstRect.size.width; x++) {
        NSRect rect = dstRect;
        rect.origin.x += x;

        if (rect.origin.x + srcRect.size.width > dstRect.origin.x + dstRect.size.width) {
            srcRect.size.width = (rect.origin.x + srcRect.size.width) - (dstRect.origin.x + dstRect.size.width);
        }

        [self drawAtPoint:rect.origin
                 fromRect:srcRect
                operation:NSCompositingOperationSourceOver
                 fraction:fraction];
    }
    return YES;
}
@end
