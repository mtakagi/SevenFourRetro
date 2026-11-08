#import "SFPostWindowController.h"

#import "SFAppController.h"
#import "SFThreadView.h"
#import "SFThread.h"

#import "SFDocument.h"

static NSMutableSet* names_ = NULL;
static NSMutableSet* mails_ = NULL;

@implementation SFPostWindowController

- (void) setThread: (SFThread*) th
{
    thread_ = [th retain];
    
    [[self window] setTitle: 
        [NSString stringWithFormat: @"Re: %@", [thread_ subject]]];
}

- (SFThread*) thread
{
    return thread_;
}

- (NSMutableString*) body
{
	return [[bodyView textStorage] mutableString];
}

#pragma mark Action
// Sends the post in the background; the window stays usable meanwhile, but
// the post button is disabled so the post can't be sent twice. When bbs.cgi
// answers with anything but success (a confirmation page, a warning or an
// error), its message is shown; OK sends the post again, Cancel leaves the
// window open so the text can be edited.
- (NSString*) currentPost
{
    return [NSString stringWithFormat: @"%@\n%@\n%@",
        [nameBox stringValue], [mailBox stringValue], [bodyView string]];
}

- (void) sendPost
{
    if (sending_) {
        return;
    }
    BOOL started = [thread_ postWithName: [nameBox stringValue]
                                    mail: [mailBox stringValue]
                                    body: [bodyView string]
                       completionHandler: ^(Ch2ThreadPostResult result) {
        [self finishPost: result];
    }];
    if (! started) {
        // Another window of this thread is sending a post.
        NSBeep();
        return;
    }
    sending_ = YES;
    [sentPost_ release];
    sentPost_ = [[self currentPost] retain];
    [postButton_ setEnabled: NO];
    [indicator startAnimation: nil];
}

- (void) finishPost: (Ch2ThreadPostResult) result
{
    sending_ = NO;
    [postButton_ setEnabled: YES];
    [indicator stopAnimation: nil];

    if (result == Ch2ThreadPostSuccess) {
        [thread_ update];
        if (closed_ || [[self currentPost] isEqualToString: sentPost_]) {
            [self close];
            return;
        }
        // Edited while sending: the edits were not posted. Keep them.
        NSAlert* alert = [[[NSAlert alloc] init] autorelease];
        [alert setAlertStyle: NSAlertStyleInformational];
        [alert setMessageText: NSLocalizedString(@"Posted.", @"")];
        [alert setInformativeText: NSLocalizedString(@"What was changed while posting has not been posted.", @"")];
        [alert addButtonWithTitle: @"OK"];
        [alert beginSheetModalForWindow: [self window] completionHandler: nil];
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
    [alert setAlertStyle: NSAlertStyleInformational];

    // alertMessage is nil when the response was empty; NSAlert raises on a
    // nil informative text.
    NSString* message = [thread_ alertMessage];
    if (! message) {
        message = @"";
    }

    if (result == Ch2ThreadPostUnknown) {
        // It may have been written: no button sends it again.
        [alert setMessageText: NSLocalizedString(@"Not sure whether the post was written.", @"")];
        [alert setInformativeText: [NSString stringWithFormat: @"%@\n\n%@",
            NSLocalizedString(@"Check the updated thread before posting again.", @""), message]];
        [alert addButtonWithTitle: @"OK"];
        [alert beginSheetModalForWindow: [self window] completionHandler: nil];
        return;
    }

    BOOL needsConfirmation = (result == Ch2ThreadPostCheck ||
                              result == Ch2ThreadPostCheckCookie ||
                              result == Ch2ThreadPostWarning);
    [alert setMessageText: needsConfirmation
        ? NSLocalizedString(@"Confirm posting.", @"")
        : NSLocalizedString(@"Failed to post.", @"")];
    [alert setInformativeText: message];

    [alert addButtonWithTitle: @"OK"];
    [alert addButtonWithTitle: @"Cancel"];

    [alert beginSheetModalForWindow: [self window]
                  completionHandler: ^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            // Post again once this sheet is gone, so another alert can be shown.
            [self performSelector: @selector(sendPost) withObject: nil afterDelay: 0];
        }
    }];
}

- (IBAction) post: (id) sender
{    
    if (sending_) {
        return;
    }
    if ([sender isKindOfClass: [NSButton class]]) {
        postButton_ = sender;
    }
	
	[names_ addObject: [nameBox stringValue]];
	[mails_ addObject: [mailBox stringValue]];
    
    [self sendPost];
}

#pragma mark Override
- (id) init
{
	self = [self initWithWindowNibName: @"PostWindow"];
	return self;
}

- (id) initWithWindowNibName: (NSString*) name
{
    self = [super initWithWindowNibName: name];
    [self setWindowFrameAutosaveName: @"PostWindow"];
    
	if (! names_) {
		names_ = [[NSMutableSet alloc] init];
		mails_ = [[NSMutableSet alloc] init];

		// Load From File
		NSString* path;
		path = [NSString stringWithFormat: @"%@/Post.plist", SF_SUPPORT_DIRECTORY];
		
		NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile: path]; 		
		[names_ addObjectsFromArray: [dict objectForKey: @"Name"]];
		[mails_ addObjectsFromArray: [dict objectForKey: @"Mail"]];
		
		// "age" and "sage"
		[mails_ addObject: @"age"];
		[mails_ addObject: @"sage"];
	}
		
    return self;
}

- (void) awakeFromNib
{
	[mailBox setStringValue: @"sage"];
}

- (void) dealloc
{
    [thread_ release];
    [sentPost_ release];
    
    [super dealloc];
}

- (void) windowWillClose: (NSNotification*) notification
{
	// A post being sent is still sent; its result is not shown (see -finishPost:).
	closed_ = YES;
	
	NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[names_ allObjects], @"Name", [mails_ allObjects], @"Mail", nil];
	
    NSString* path;
    path = [NSString stringWithFormat: @"%@/Post.plist", SF_SUPPORT_DIRECTORY];
	if (! [dict writeToFile: path atomically: true]) {
		NSLog(@"SFPostWC: Failed to write: %@", path);
	}
}

- (int) numberOfItemsInComboBox: (NSComboBox*) box
{
    if (box == nameBox) {
        return [names_ count];
    } else if (box == mailBox){
        return [mails_ count];
    } else {
		return 0;
	}
}

- (id) comboBox: (NSComboBox*) box objectValueForItemAtIndex: (int) index
{
    if (box == nameBox) { 
        return [[names_ allObjects] objectAtIndex: index];
    } else if (box == mailBox) {
        return [[mails_ allObjects] objectAtIndex: index];
	} else {
		return nil;
	}
}

@end
