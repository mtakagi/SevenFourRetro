/* This file is not copyrighted and may be used freely. */

#import "SFAppController.h"

#import "SFDocument.h"
#import "SFMainWindowController.h"
#import "SFPostWindowController.h"
#import "SFAppTranslocation.h"
#import "SFThreadHTMLFormatter.h"
#import "FontButton.h"
#import "Ch2Board.h"
#import <OgreKit/OgreKit.h>
#import <Sparkle/Sparkle.h>

NSString* SF_SUPPORT_DIRECTORY = NULL;

@implementation SFAppController

- (IBAction) reloadSkin: (id) sender
{
    [SFThreadHTMLFormatter reloadTemplates];
}


+ (void) copyDatFromOldDirectory
{
	NSFileManager* manager = [NSFileManager defaultManager];
	
	if ([manager fileExistsAtPath: [NSString stringWithFormat: @"%@/Thread/2ch.net/", SF_SUPPORT_DIRECTORY]])
		return;
	
    int i;
    NSArray* ary;
	
    ary = [manager subpathsAtPath: [NSString stringWithFormat: @"%@/Thread", SF_SUPPORT_DIRECTORY]];
    for (i = 0; i < [ary count]; i++) {
        NSString* path1 = [NSString stringWithFormat: @"%@/Thread/%@", 
			SF_SUPPORT_DIRECTORY, [ary objectAtIndex: i]];
		
		NSMutableString* s = [NSMutableString stringWithString: [ary objectAtIndex: i]];
		[s replaceOccurrencesOfRegularExpressionString: @"^.+?\\."
											withString: @"" 
											   options: 0
												 range: NSMakeRange(0, [s length])];	
		
        NSString* path2 = [NSString stringWithFormat: @"%@/Thread/%@", 
			SF_SUPPORT_DIRECTORY, s];
		
		BOOL isDir;
		if ([manager fileExistsAtPath: path1 isDirectory: &isDir] && isDir) {
			[manager createDirectoryAtPath: path2
			   withIntermediateDirectories: NO
								attributes: nil
									 error: NULL];
		} else {
			[manager copyItemAtPath: path1 toPath: path2 error: NULL];
		}
    }
}

+ (void) setupUserDefaults
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	
	// UI
	// The board list is the left pane of the main window (3-pane). The
	// drawer it could also be shown in (UseDrawer, DrawerEdge) is gone (#29).
	[dict setObject: [NSNumber numberWithBool: NO]
			 forKey: @"TwoPane"];
	[dict setObject: [NSNumber numberWithBool: YES]
			 forKey: @"ShowSeachFieldInSidePane"];
	
	[dict setObject: [NSNumber numberWithBool: NO]
			 forKey: @"SplitVertical"];

    [dict setObject: [NSNumber numberWithBool: YES]
			 forKey: @"OpenThreadBySingleClick"];
    [dict setObject: [NSNumber numberWithBool: YES]
			 forKey: @"OpenThreadOnSubjectColumn"];
    
    [dict setObject: [NSNumber numberWithBool: NO]
			 forKey: @"ThreadShowAll"];
	[dict setObject: [NSNumber numberWithInt: 10]
			 forKey: @"ThreadShowMin"];
	
    
	[dict setObject: [NSNumber numberWithFloat: 640.0]
			 forKey: @"ImageWindowMaxWidth"];
	[dict setObject: [NSNumber numberWithFloat: 480.0]
			 forKey: @"ImageWindowMaxHeight"];

	// Font
	NSFont* systemFont = [NSFont systemFontOfSize: [NSFont systemFontSize]];
	[dict setObject: [systemFont familyName]
			 forKey: @"MessageFontFamily"];
	[dict setObject: [NSNumber numberWithFloat: [systemFont pointSize]]
			 forKey: @"MessageFontSize"];
	[dict setObject: [systemFont familyName]
			 forKey: @"BoardTreeFontFamily"];
	[dict setObject: [NSNumber numberWithFloat: [systemFont pointSize]]
			 forKey: @"BoardTreeFontSize"];
	[dict setObject: [systemFont familyName]
			 forKey: @"ThreadListFontFamily"];
	[dict setObject: [NSNumber numberWithFloat: [systemFont pointSize]]
			 forKey: @"ThreadListFontSize"];
	
	[dict setObject: [NSNumber numberWithFloat: 480.0]
			 forKey: @"ImageWindowMaxHeight"];
	
	// Network
	[dict setObject: @"https://menu.5ch.io/bbsmenu.html"
			 forKey: @"URLOfBoardTree"];
	
	[defaults registerDefaults: dict];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues: dict];
}

+ (void) setupSupportDirectory
{
	[self copyDatFromOldDirectory];
}

- (IBAction) showFontPanel: (id) sender
{
	FontButton* button = sender;
	
	NSString* font = nil;
	switch ([button tag]) {
	case 0:
		font = @"BoardTree";
		break;
	case 1:
		font = @"ThreadList";
		break;
	case 2:
		font = @"Message";
		break;
	default:
		break;
	}
	
	[button setFamilyKey: [NSString stringWithFormat: @"%@FontFamily", font]];
	[button setPointSizeKey: [NSString stringWithFormat: @"%@FontSize", font]];
	
	[[button window] makeFirstResponder: button];
	[[NSFontPanel sharedFontPanel] orderFront: self];
}


+ (NSURL*) matchedURLFromBoardTree: (OGRegularExpression*) pattern
							 array: (NSArray*) items
{
	OGRegularExpressionMatch* match;
	NSURL* result = nil;
	
	int i;
	for (i = 0; i < [items count]; i++) {
		NSDictionary* dict = [items objectAtIndex: i];
		if ([dict objectForKey: @"url"]) {
			match = [pattern matchInString: [dict objectForKey: @"url"]];
			if (match) {
				result = [NSURL URLWithString: [dict objectForKey: @"url"]];
			}
		} else {
			result = [self matchedURLFromBoardTree: pattern
											 array: [dict objectForKey: @"children"]];
		}
		
		if (result)
			return result;
	}
	return nil;
}

+ (NSURL*) URLFromCachePath: (NSString*) path
{
	OGRegularExpression* pattern;
	OGRegularExpressionMatch* match;
	NSString* s;
	
	s = [NSString stringWithFormat: @"%@/Thread/(.+?)/(.+?)/(\\d+\\.dat)$", SF_SUPPORT_DIRECTORY];
	pattern = [OGRegularExpression regularExpressionWithString: s];	
	match = [pattern matchInString: path];
	if (! match) {
		return nil;
	}
	
	s = [NSString stringWithFormat: @"/%@/", [match substringAtIndex: 2]];
	pattern = [OGRegularExpression regularExpressionWithString: s];
	
	NSURL* board = [self matchedURLFromBoardTree: pattern
										   array: [[SFDocument sharedBoardTree] objectForKey: @"children"]];
	
	return [NSURL URLWithString: [NSString stringWithFormat: @"dat/%@", [match substringAtIndex: 3]]
				  relativeToURL: board];
}

- (void) board: (Ch2Board*) board didFailWithError: (NSError*) err
{
	NSAlert* alert = [[[NSAlert alloc] init] autorelease];
	
	[alert setMessageText: [err localizedDescription]];
	
	[alert addButtonWithTitle: @"OK"];
	
	NSWindow* window = [NSApp mainWindow];
	if (window) {
		[alert beginSheetModalForWindow: window completionHandler: nil];
	} else {
		[alert runModal];
	}
}


#pragma mark Override
+ (void) initialize
{
    if (! SF_SUPPORT_DIRECTORY) {
		[self setupUserDefaults];
		
        // Create Application Support Folder
        SF_SUPPORT_DIRECTORY = [NSString stringWithFormat:
            @"%@/Library/Application Support/SevenFour",
            NSHomeDirectory()];
        [SF_SUPPORT_DIRECTORY retain];
		
        NSFileManager* manager = [NSFileManager defaultManager];
        BOOL isDir;
        
        if ([manager fileExistsAtPath: SF_SUPPORT_DIRECTORY
                          isDirectory: &isDir] && isDir) {
            ;
        } else {
            // With "Library/Application Support" too, which a new home lacks.
            [manager createDirectoryAtPath: SF_SUPPORT_DIRECTORY
               withIntermediateDirectories: YES
                                attributes: nil
                                     error: NULL];
        }
		
		
        [self setupSupportDirectory];
		
        [SFThreadHTMLFormatter reloadTemplates];
    }
}

// Updates from GitHub Releases with Sparkle (#61): the feed (SUFeedURL) is
// the appcast.xml of the latest release, checked with SUPublicEDKey. Sparkle
// asks on the second launch whether to check automatically; the app menu
// gets "アップデートを確認…".
- (void) applicationWillFinishLaunching: (NSNotification*) n
{
    SPUStandardUpdaterController* controller =
        [[SPUStandardUpdaterController alloc] initWithStartingUpdater: YES
                                                      updaterDelegate: nil
                                                   userDriverDelegate: nil];
    updaterController_ = controller;

    NSMenu* appMenu = [[[NSApp mainMenu] itemAtIndex: 0] submenu];
    NSMenuItem* item = [[[NSMenuItem alloc] initWithTitle: @"アップデートを確認…"
                                                   action: @selector(checkForUpdates:)
                                            keyEquivalent: @""] autorelease];
    [item setTarget: controller];
    // After "SevenFour について".
    [appMenu insertItem: item atIndex: MIN(1, [appMenu numberOfItems])];
}

// Opened where it was downloaded, the app runs translocated, from a place
// macOS removes when the app is moved or replaced, which crashes it; Sparkle
// can't update it there either (#68). Asks to quit and move the app to the
// Applications folder first. The SFAssumeAppTranslocation default (for
// trying it out) shows the dialog anyway.
- (void) applicationDidFinishLaunching: (NSNotification*) n
{
    NSString* path = [[NSBundle mainBundle] bundlePath];
    BOOL translocated = SFIsTranslocatedPath(path)
        || [[NSUserDefaults standardUserDefaults] boolForKey: @"SFAssumeAppTranslocation"];
    if (! translocated) {
        return;
    }
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle: NSAlertStyleWarning];
    [alert setMessageText: NSLocalizedString(@"Move SevenFour to the Applications folder.", @"")];
    [alert setInformativeText: NSLocalizedString(@"SevenFour was opened where it was downloaded, so macOS runs it from a temporary place. Moving or replacing the app while it runs makes it quit unexpectedly, and it can't be updated. Quit SevenFour, move it to the Applications folder in the Finder, and open it again.", @"")];
    [alert addButtonWithTitle: NSLocalizedString(@"Quit", @"")];
    [alert addButtonWithTitle: NSLocalizedString(@"Keep Using", @"")];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [NSApp terminate: nil];
    }
}

// Quitting asks first when a post window has text not yet posted, which
// quitting would lose (#69).
- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication*) app
{
    NSWindow* unsent = nil;
    for (NSWindow* window in [app windows]) {
        id controller = [window windowController];
        // Open windows: on screen or minimized to the Dock. A closed one is
        // neither.
        BOOL open = [window isVisible] || [window isMiniaturized];
        if (open && [controller isKindOfClass: [SFPostWindowController class]]
            && [controller hasUnsentText]) {
            unsent = window;
            break;
        }
    }
    if (! unsent) {
        return NSTerminateNow;
    }
    // Shows the window the text is in, out of the Dock if it was there.
    if ([unsent isMiniaturized]) {
        [unsent deminiaturize: nil];
    }
    [unsent makeKeyAndOrderFront: nil];
    NSAlert* alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle: NSAlertStyleWarning];
    [alert setMessageText: NSLocalizedString(@"Quit without posting?", @"")];
    [alert setInformativeText: NSLocalizedString(@"A post window has text you haven't posted. It will be lost.", @"")];
    // Cancel first (Escape), as when closing the window: Return quits nothing.
    [alert addButtonWithTitle: NSLocalizedString(@"Cancel", @"")];
    NSButton* quit = [alert addButtonWithTitle: NSLocalizedString(@"Quit", @"")];
    [quit setHasDestructiveAction: YES];
    return ([alert runModal] == NSAlertSecondButtonReturn) ? NSTerminateNow : NSTerminateCancel;
}

- (BOOL) application: (NSApplication*) app openFile: (NSString*) path
{
	DEBUG_LOG(@"SFAC %p - application:openFile:", self);
	
	SFMainWindowController* controller = (SFMainWindowController*) [[app mainWindow] delegate];
	[controller newTab: nil];
	[controller openURL: [SFAppController URLFromCachePath: path]];
	
	return YES;
}

@end

