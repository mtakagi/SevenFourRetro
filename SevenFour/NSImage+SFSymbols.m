/* This file is not copyrighted and may be used freely. */

#import "NSImage+SFSymbols.h"

@implementation NSImage (SFSymbols)
+ (NSImage*) sf_imageWithSymbolName: (NSString*) name
                          pointSize: (CGFloat) pointSize
                              color: (NSColor*) color
                               size: (NSSize) size
{
    NSImage* symbol = [NSImage imageWithSystemSymbolName: name
                                accessibilityDescription: nil];
    if (! symbol) {
        return nil;
    }

    NSImageSymbolConfiguration* config;
    config = [NSImageSymbolConfiguration configurationWithPointSize: pointSize
                                                             weight: NSFontWeightRegular];
    if (color) {
        config = [config configurationByApplyingConfiguration:
            [NSImageSymbolConfiguration configurationWithPaletteColors:
                [NSArray arrayWithObject: color]]];
    }
    symbol = [symbol imageWithSymbolConfiguration: config];

    // The block is copied by NSImage, which retains symbol.
    return [NSImage imageWithSize: size
                          flipped: NO
                   drawingHandler: ^BOOL (NSRect dstRect) {
        NSSize s = [symbol size];
        NSRect rect = NSMakeRect(NSMidX(dstRect) - s.width / 2,
                                 NSMidY(dstRect) - s.height / 2,
                                 s.width, s.height);
        [symbol drawInRect: rect
                  fromRect: NSZeroRect
                 operation: NSCompositingOperationSourceOver
                  fraction: 1.0];
        return YES;
    }];
}
@end
