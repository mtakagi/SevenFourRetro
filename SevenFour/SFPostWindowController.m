#import "SFPostWindowController.h"

#import "SFAppController.h"
#import "SFThreadView.h"
#import "SFThread.h"

#import "SFDocument.h"

static NSMutableSet* names_ = NULL;
static NSMutableSet* mails_ = NULL;

@implementation SFPostWindowController

- (void)setThread:(SFThread*)th
{
    thread_ = [th retain];

    [[self window] setTitle:
            [NSString stringWithFormat:@"Re: %@", [thread_ subject]]];
}

- (SFThread*)thread
{
    return thread_;
}

- (NSMutableString*)body
{
    return [[bodyView textStorage] mutableString];
}

- (void)showWindow:(id)sender
{
    // Text put in with -body (e.g. ">>1") has no font of its own.
    [bodyView setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    if (!shownBody_) {
        shownBody_ = [[bodyView string] copy];
    }
    [super showWindow:sender];
}

- (BOOL)hasUnsentText
{
    NSString* body = [bodyView string];
    if ([[body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        return NO;
    }
    if (shownBody_ && [body isEqualToString:shownBody_]) {
        return NO; // only what the window was opened with
    }
    // Being sent as it is: closing doesn't stop the post (see -finishPost:).
    if (sending_ && [[self currentPost] isEqualToString:sentPost_]) {
        return NO;
    }
    return YES;
}

#pragma mark Action

// The server's message in a dialog: in a scrolling text view under the
// title, not as the informative text, which grows the alert past the screen
// when it is long, as 5ch's confirmation page with its terms is (#66). The
// text isn't selectable: a selectable text view becomes the sheet's first
// responder and scrolls itself a line or two down when the sheet opens.
static NSView* messageView(NSString* message)
{
    const CGFloat width = 400;
    const CGFloat maxHeight = 320;

    NSTextView* text = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, width, 10)] autorelease];
    [text setEditable:NO];
    [text setSelectable:NO];
    [text setDrawsBackground:NO];
    [text setTextContainerInset:NSZeroSize];
    [[text textContainer] setLineFragmentPadding:0];
    [text setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [text setTextColor:[NSColor labelColor]];
    [text setString:message];

    // The text's whole height; the view shows up to maxHeight of it and
    // scrolls for the rest.
    NSLayoutManager* layout = [text layoutManager];
    [layout ensureLayoutForTextContainer:[text textContainer]];
    CGFloat textHeight = ceil(NSHeight([layout usedRectForTextContainer:[text textContainer]]));
    textHeight = MAX(textHeight, 16);

    NSScrollView* scroll = [[[NSScrollView alloc]
        initWithFrame:NSMakeRect(0, 0, width, MIN(textHeight, maxHeight))] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutohidesScrollers:YES];
    [scroll setDrawsBackground:NO];
    [scroll setBorderType:NSNoBorder];
    [text setFrame:NSMakeRect(0, 0, [scroll contentSize].width, textHeight)];
    [text setMinSize:NSMakeSize(0, textHeight)];
    [text setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [text setVerticallyResizable:YES];
    [text setHorizontallyResizable:NO];
    [text setAutoresizingMask:NSViewWidthSizable];
    [[text textContainer] setWidthTracksTextView:YES];
    [scroll setDocumentView:text];
    return scroll;
}

// Puts the server's message (nil or empty: none) in alert.
static void setMessage(NSAlert* alert, NSString* message)
{
    if ([message length] > 0) {
        [alert setAccessoryView:messageView(message)];
    }
}

// Sends the post in the background; the window stays usable meanwhile, but
// the post button is disabled so the post can't be sent twice. When bbs.cgi
// answers with anything but success (a confirmation page, a warning or an
// error), its message is shown; OK sends the post again, Cancel leaves the
// window open so the text can be edited.
- (NSString*)currentPost
{
    return [NSString stringWithFormat:@"%@\n%@\n%@",
        [nameBox stringValue], [mailBox stringValue], [bodyView string]];
}

- (void)sendPost
{
    if (sending_) {
        return;
    }
    BOOL started = [thread_ postWithName:[nameBox stringValue]
                                    mail:[mailBox stringValue]
                                    body:[bodyView string]
                       completionHandler:^(Ch2ThreadPostResult result) {
                           [self finishPost:result];
                       }];
    if (!started) {
        // Another window of this thread is sending a post.
        NSBeep();
        return;
    }
    sending_ = YES;
    [sentPost_ release];
    sentPost_ = [[self currentPost] retain];
    [postButton_ setEnabled:NO];
    [indicator startAnimation:nil];
}

- (void)finishPost:(Ch2ThreadPostResult)result
{
    sending_ = NO;
    [postButton_ setEnabled:YES];
    [indicator stopAnimation:nil];

    if (result == Ch2ThreadPostSuccess) {
        [thread_ update];
        if (closed_ || [[self currentPost] isEqualToString:sentPost_]) {
            [self close];
            return;
        }
        // Edited while sending: the edits were not posted. Keep them.
        NSAlert* alert = [[[NSAlert alloc] init] autorelease];
        [alert setAlertStyle:NSAlertStyleInformational];
        [alert setMessageText:NSLocalizedString(@"Posted.", @"")];
        [alert setInformativeText:NSLocalizedString(@"What was changed while posting has not been posted.", @"")];
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:[self window] completionHandler:nil];
        return;
    }
    if (result == Ch2ThreadPostUnknown) {
        // The new message, if it was written, shows up in the thread.
        [thread_ update];
    }
    // Closed while sending: no window to show the result in. Ch2Thread
    // still keeps a confirmation page, so posting the same text again later
    // sends that page's form, as OK in the dialog would.
    if (closed_) {
        return;
    }

    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSAlertStyleInformational];

    // alertMessage is nil when the response was empty.
    NSString* message = [thread_ alertMessage];

    if (result == Ch2ThreadPostUnknown) {
        // It may have been written: no button sends it again.
        [alert setMessageText:NSLocalizedString(@"Not sure whether the post was written.", @"")];
        [alert setInformativeText:NSLocalizedString(@"Check the updated thread before posting again.", @"")];
        setMessage(alert, message);
        [alert addButtonWithTitle:@"OK"];
        [alert beginSheetModalForWindow:[self window] completionHandler:nil];
        return;
    }

    BOOL needsConfirmation = (result == Ch2ThreadPostCheck || result == Ch2ThreadPostCheckCookie || result == Ch2ThreadPostWarning);
    [alert setMessageText:needsConfirmation
            ? NSLocalizedString(@"Confirm posting.", @"")
            : NSLocalizedString(@"Failed to post.", @"")];
    setMessage(alert, message);

    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];

    [alert beginSheetModalForWindow:[self window]
                  completionHandler:^(NSModalResponse returnCode) {
                      if (returnCode == NSAlertFirstButtonReturn) {
                          // Post again once this sheet is gone, so another alert can be shown.
                          [self performSelector:@selector(sendPost) withObject:nil afterDelay:0];
                      }
                  }];
}

- (IBAction)post:(id)sender
{
    if (sending_) {
        return;
    }

    [names_ addObject:[nameBox stringValue]];
    [mails_ addObject:[mailBox stringValue]];

    [self sendPost];
}

#pragma mark Window

// A label right-aligned to the field it names.
static NSTextField* label(NSString* text, NSRect frame)
{
    NSTextField* field = [NSTextField labelWithString:text];
    [field setFrame:frame];
    [field setAlignment:NSTextAlignmentRight];
    [field setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    return field;
}

// A combo box that lists the names or mails used before (this controller
// is its data source) and completes what is typed.
static NSComboBox* comboBox(NSRect frame, id dataSource)
{
    NSComboBox* box = [[[NSComboBox alloc] initWithFrame:frame] autorelease];
    [box setUsesDataSource:YES];
    [box setDataSource:dataSource];
    [box setCompletes:YES];
    [box setNumberOfVisibleItems:5];
    [box setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    return box;
}

// The window PostWindow.nib held (#30), made in code with the same layout:
// name and mail at the top left, the body filling the window, the post
// button at the bottom right and the progress indicator at the top right.
- (NSWindow*)makeWindow
{
    NSWindow* window = [[[NSWindow alloc]
        initWithContentRect:NSMakeRect(116, 449, 489, 261)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:YES] autorelease];
    [window setReleasedWhenClosed:NO];
    [window setContentMinSize:NSMakeSize(449, 247)];
    NSView* content = [window contentView];

    [content addSubview:label(@"名前", NSMakeRect(17, 221, 38, 17))];
    [content addSubview:label(@"Email", NSMakeRect(17, 192, 38, 17))];

    nameBox = comboBox(NSMakeRect(60, 217, 203, 26), self);
    [content addSubview:nameBox];
    mailBox = comboBox(NSMakeRect(60, 188, 203, 26), self);
    [content addSubview:mailBox];

    // The body: plain text, as it is sent. Smart quotes, dashes and the
    // like are off so the text is posted exactly as typed.
    NSScrollView* scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(60, 60, 409, 123)] autorelease];
    [scroll setBorderType:NSBezelBorder];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    NSSize size = [scroll contentSize];
    bodyView = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)] autorelease];
    [bodyView setMinSize:NSMakeSize(0, size.height)];
    [bodyView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [bodyView setVerticallyResizable:YES];
    [bodyView setHorizontallyResizable:NO];
    [bodyView setAutoresizingMask:NSViewWidthSizable];
    [[bodyView textContainer] setWidthTracksTextView:YES];
    [bodyView setRichText:NO];
    [bodyView setImportsGraphics:NO];
    [bodyView setAllowsUndo:YES];
    [bodyView setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    [bodyView setAutomaticQuoteSubstitutionEnabled:NO];
    [bodyView setAutomaticDashSubstitutionEnabled:NO];
    [bodyView setAutomaticTextReplacementEnabled:NO];
    [bodyView setAutomaticDataDetectionEnabled:NO];
    [bodyView setAutomaticLinkDetectionEnabled:NO];
    [scroll setDocumentView:bodyView];
    [content addSubview:scroll];

    NSButton* button = [NSButton buttonWithTitle:@"書き込む" target:self action:@selector(post:)];
    [button setFrame:NSMakeRect(383, 12, 92, 32)];
    [button setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [content addSubview:button];
    postButton_ = button;

    indicator = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(453, 222, 16, 16)] autorelease];
    [indicator setStyle:NSProgressIndicatorStyleSpinning];
    [indicator setControlSize:NSControlSizeSmall];
    [indicator setDisplayedWhenStopped:NO];
    [indicator setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [content addSubview:indicator];

    // Tab goes name, mail, body, button; typing starts in the body.
    [nameBox setNextKeyView:mailBox];
    [mailBox setNextKeyView:bodyView];
    [bodyView setNextKeyView:button];
    [button setNextKeyView:nameBox];
    [window setInitialFirstResponder:bodyView];

    return window;
}

#pragma mark Override
- (id)init
{
    self = [super initWithWindow:nil];
    if (!self) {
        return nil;
    }

    NSWindow* window = [self makeWindow];
    [self setWindow:window];
    [window setDelegate:self];
    // The frame the user left the window at, as with the nib.
    [self setWindowFrameAutosaveName:@"PostWindow"];

    if (!names_) {
        names_ = [[NSMutableSet alloc] init];
        mails_ = [[NSMutableSet alloc] init];

        // Load From File
        NSString* path;
        path = [NSString stringWithFormat:@"%@/Post.plist", SF_SUPPORT_DIRECTORY];

        NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:path];
        [names_ addObjectsFromArray:[dict objectForKey:@"Name"]];
        [mails_ addObjectsFromArray:[dict objectForKey:@"Mail"]];

        // "age" and "sage"
        [mails_ addObject:@"age"];
        [mails_ addObject:@"sage"];
    }

    [mailBox setStringValue:@"sage"];

    return self;
}

- (void)dealloc
{
    [thread_ release];
    [sentPost_ release];
    [shownBody_ release];

    [super dealloc];
}

// Closing the window (the close button, ⌘W) asks first when the body would
// be lost (#69). A window closed in code (after a post went through) isn't
// asked about.
- (BOOL)windowShouldClose:(NSWindow*)window
{
    if (closeConfirmed_ || ![self hasUnsentText]) {
        return YES;
    }
    if ([window attachedSheet]) {
        NSBeep();
        return NO;
    }
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:NSLocalizedString(@"Close without posting?", @"")];
    [alert setInformativeText:NSLocalizedString(@"The text you wrote will be lost.", @"")];
    // Cancel first: NSAlert gives it Escape and makes no button the
    // default, so Return doesn't lose the text; Close must be clicked.
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    NSButton* close = [alert addButtonWithTitle:NSLocalizedString(@"Close", @"")];
    [close setHasDestructiveAction:YES];
    [alert beginSheetModalForWindow:window
                  completionHandler:^(NSModalResponse returnCode) {
                      if (returnCode == NSAlertSecondButtonReturn) {
                          closeConfirmed_ = YES;
                          [self close];
                      }
                  }];
    return NO;
}

- (void)windowWillClose:(NSNotification*)notification
{
    // A post being sent is still sent; its result is not shown (see -finishPost:).
    closed_ = YES;

    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
            [names_ allObjects], @"Name", [mails_ allObjects], @"Mail", nil];

    NSString* path;
    path = [NSString stringWithFormat:@"%@/Post.plist", SF_SUPPORT_DIRECTORY];
    if (![dict writeToFile:path atomically:true]) {
        NSLog(@"SFPostWC: Failed to write: %@", path);
    }
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox*)box
{
    if (box == nameBox) {
        return [names_ count];
    } else if (box == mailBox) {
        return [mails_ count];
    } else {
        return 0;
    }
}

// The names or mails a combo box offers.
- (NSArray*)itemsOfComboBox:(NSComboBox*)box
{
    if (box == nameBox) {
        return [names_ allObjects];
    } else if (box == mailBox) {
        return [mails_ allObjects];
    }
    return [NSArray array];
}

// Completes what is typed with a name or mail used before (the combo boxes
// have always been set to complete, but without this they never did).
- (NSString*)comboBox:(NSComboBox*)box completedString:(NSString*)string
{
    NSEnumerator* e = [[self itemsOfComboBox:box] objectEnumerator];
    NSString* item;
    while ((item = [e nextObject]) != nil) {
        if ([string length] > 0 && [item hasPrefix:string]) {
            return item;
        }
    }
    return nil;
}

- (NSUInteger)comboBox:(NSComboBox*)box indexOfItemWithStringValue:(NSString*)string
{
    return [[self itemsOfComboBox:box] indexOfObject:string];
}

- (id)comboBox:(NSComboBox*)box objectValueForItemAtIndex:(NSInteger)index
{
    if (box == nameBox) {
        return [[names_ allObjects] objectAtIndex:index];
    } else if (box == mailBox) {
        return [[mails_ allObjects] objectAtIndex:index];
    } else {
        return nil;
    }
}

@end
