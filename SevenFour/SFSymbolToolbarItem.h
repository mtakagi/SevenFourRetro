/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

// A toolbar button showing an SF Symbol that can spin while its work is in
// progress. Symbol effects only run in an NSImageView, so unlike an image
// toolbar item this one is a button view with the symbol in an image view.
//
// -validate asks the target, like an image item would:
//   -validateToolbarItem: for the enabled state, and
//   -isToolbarItemBusy: (optional) for whether to animate.
@interface SFSymbolToolbarItem : NSToolbarItem {
    NSButton* button_;
    NSImageView* imageView_;
    BOOL animating_;
}

- (id)initWithItemIdentifier:(NSString*)identifier
                  symbolName:(NSString*)symbol
                       label:(NSString*)label;

- (BOOL)isAnimating;
- (void)setAnimating:(BOOL)flag;
@end

@interface NSObject (SFSymbolToolbarItemTarget)
- (BOOL)isToolbarItemBusy:(NSToolbarItem*)item;
@end
