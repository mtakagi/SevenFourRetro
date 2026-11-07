/* This file is not copyrighted and may be used freely. */

#import "FontButton.h"

@implementation FontButton
- (void) setFamilyKey: (NSString*) key
{
	[familyKey_ release];
	familyKey_ = [key retain];
}

- (void) setPointSizeKey: (NSString*) key
{
	[pointSizeKey_ release];
	pointSizeKey_ = [key retain];
}

- (void) changeFont: (id) sender
{
	NSFont* font = [sender convertFont: font_];
	
	[font_ release];
	font_ = [font retain];

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject: [font_ familyName]
				 forKey: familyKey_];
	[defaults setFloat: [font_ pointSize]
				forKey: pointSizeKey_];
}

- (void) awakeFromNib
{
	font_ = [[NSFont systemFontOfSize: [NSFont systemFontSize]] retain];
}

@end
