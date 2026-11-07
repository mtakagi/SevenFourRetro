/* This file is not copyrighted and may be used freely. */

#import "SFAppController.h"

#import "SFDocument.h"
#import "SFMainWindowController.h"
#import "SFURLProtocol.h"
#import "SFThreadHTMLFormatter.h"
#import "FontButton.h"
#import "Ch2Board.h"
#import <OgreKit/OgreKit.h>

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
			[manager createDirectoryAtPath: path2 attributes: nil];
		} else {
			[manager copyPath: path1 toPath: path2 handler: nil];        
		}
    }
}

+ (void) setupUserDefaults
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	
	// UI
	[dict setObject: [NSNumber numberWithBool: YES]
			 forKey: @"UseDrawer"];
	[dict setObject: [NSNumber numberWithInt: 0]
			 forKey: @"DrawerEdge"];
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

- (void) alertSheetDidEnd: (NSAlert*) alert
			   returnCode: (int) returnCode
			  contextInfo: (void*) contextInfo
{
	;
}

- (void) board: (Ch2Board*) board didFailWithError: (NSError*) err
{
	NSAlert* alert = [[NSAlert alloc] init];
	
	[alert setMessageText: [err localizedDescription]];
	
	[alert addButtonWithTitle: @"OK"];
	
	[alert beginSheetModalForWindow: [NSApp mainWindow]
					  modalDelegate: self
					 didEndSelector: @selector(alertSheetDidEnd: returnCode: contextInfo:)
						contextInfo: nil];
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
            [manager createDirectoryAtPath: SF_SUPPORT_DIRECTORY
                                attributes: nil];
        }
		
		
        [self setupSupportDirectory];
		
		[NSURLProtocol registerClass: [SFURLProtocol class]];
        [SFThreadHTMLFormatter reloadTemplates];
    }
}

- (BOOL) application: (NSApplication*) app openFile: (NSString*) path
{
	DEBUG_LOG(@"SFAC %p - application:openFile:", self);
	
	SFMainWindowController* controller = [[app mainWindow] delegate];
	[controller newTab: nil];
	[controller openURL: [SFAppController URLFromCachePath: path]];
	
	return YES;
}

@end

