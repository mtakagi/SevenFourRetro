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
- (IBAction) post: (id) sender
{    
    [indicator startAnimation: sender];
	
	[names_ addObject: [nameBox stringValue]];
	[mails_ addObject: [mailBox stringValue]];
    
    Ch2ThreadPostResult result;
    result = [thread_ postWithName: [nameBox stringValue]
							  mail: [mailBox stringValue]
							  body: [bodyView string]];	

	if (result != Ch2ThreadPostSuccess) {
		NSAlert* alert = [[NSAlert alloc] init];
		[alert autorelease];
		
		[alert setAlertStyle: NSInformationalAlertStyle];

		// alertMessage is nil when the request failed or the response had no
		// recognizable message; NSAlert raises on a nil informative text.
		NSString* message = [thread_ alertMessage];
		if ([message length] == 0) {
			message = NSLocalizedString(@"Failed to post.", @"");
		}
		[alert setInformativeText: message];
		
		[alert addButtonWithTitle: @"OK"];
		[alert addButtonWithTitle: @"Cancel"];
		
		[alert beginSheetModalForWindow: [self window]
						  modalDelegate: self
						 didEndSelector: @selector(alertSheetDidEnd: returnCode: contextInfo:)
							contextInfo: nil];
	} else {
		[thread_ update];
        [self close];
    }
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
    
    [super dealloc];
}

// NSApplication
- (void) alertSheetDidEnd: (NSAlert*) alert
			   returnCode: (int) returnCode
			  contextInfo: (void*) contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn) {
		Ch2ThreadPostResult result;
		result = [thread_ postWithName: [nameBox stringValue]
								  mail: [mailBox stringValue]
								  body: [bodyView string]];
		[thread_ update];
		[self close];
	}
	[indicator stopAnimation: nil];
}

- (void) windowWillClose: (NSNotification*) notification
{
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
