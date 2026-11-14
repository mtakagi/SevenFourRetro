/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@interface NSImage (SFSymbols)
// An SF Symbol tinted with color, drawn centered in an image of the given
// size. The result is not a template image, so buttons and cells draw it as is.
// The color is resolved when drawn, so dynamic colors follow dark mode.
+ (NSImage*)sf_imageWithSymbolName:(NSString*)name
                         pointSize:(CGFloat)pointSize
                             color:(NSColor*)color
                              size:(NSSize)size;
@end
