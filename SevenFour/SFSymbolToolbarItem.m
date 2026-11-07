/* This file is not copyrighted and may be used freely. */

#import "SFSymbolToolbarItem.h"

@implementation SFSymbolToolbarItem

- (id) initWithItemIdentifier: (NSString*) identifier
                   symbolName: (NSString*) symbol
                        label: (NSString*) label
{
    self = [super initWithItemIdentifier: identifier];
    if (! self) {
        return nil;
    }

    NSImage* image = [NSImage imageWithSystemSymbolName: symbol
                               accessibilityDescription: label];

    button_ = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 40, 28)];
    [button_ setBezelStyle: NSBezelStyleToolbar];
    [button_ setTitle: @""];
    [button_ setImagePosition: NSNoImage];
    // Like the image items, don't keep keyboard focus after a click.
    [button_ setRefusesFirstResponder: YES];
    [[button_ cell] setAccessibilityLabel: label];

    imageView_ = [[NSImageView alloc] initWithFrame: [button_ bounds]];
    [imageView_ setImage: image];
    [imageView_ setImageScaling: NSImageScaleNone];
    [imageView_ setSymbolConfiguration:
        [NSImageSymbolConfiguration configurationWithScale: NSImageSymbolScaleLarge]];
    [imageView_ setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [imageView_ setContentTintColor: [NSColor labelColor]];
    [button_ addSubview: imageView_];

    [self setView: button_];
    [self setLabel: label];
    [self setPaletteLabel: label];

    // Shown when the toolbar is text only or the item overflows.
    NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle: label action: NULL keyEquivalent: @""];
    [menuItem setImage: image];
    [self setMenuFormRepresentation: menuItem];
    [menuItem release];

    animating_ = NO;
    return self;
}

- (void) dealloc
{
    [imageView_ release];
    [button_ release];
    [super dealloc];
}

- (void) setTarget: (id) target
{
    [super setTarget: target];
    [button_ setTarget: target];
    [[self menuFormRepresentation] setTarget: target];
}

- (void) setAction: (SEL) action
{
    [super setAction: action];
    [button_ setAction: action];
    [[self menuFormRepresentation] setAction: action];
}

- (BOOL) isAnimating
{
    return animating_;
}

- (void) setAnimating: (BOOL) flag
{
    if (flag == animating_) {
        return;
    }
    animating_ = flag;

    if (flag) {
        NSSymbolEffectOptions* options = [NSSymbolEffectOptions optionsWithRepeatBehavior:
            [NSSymbolEffectOptionsRepeatBehavior behaviorContinuous]];
        [imageView_ addSymbolEffect: [NSSymbolRotateEffect rotateClockwiseEffect]
                            options: options
                           animated: YES];
    } else {
        [imageView_ removeSymbolEffectOfType: [NSSymbolRotateEffect effect]
                                     options: [NSSymbolEffectOptions options]
                                    animated: YES];
    }
}

- (void) validate
{
    id target = [self target];

    BOOL enabled = YES;
    if ([target respondsToSelector: @selector(validateToolbarItem:)]) {
        enabled = [target validateToolbarItem: self];
    }
    [self setEnabled: enabled];
    [button_ setEnabled: enabled];
    // Match the image items: label color, dimmed when disabled.
    [imageView_ setContentTintColor: enabled ? [NSColor labelColor] : [NSColor tertiaryLabelColor]];

    if ([target respondsToSelector: @selector(isToolbarItemBusy:)]) {
        [self setAnimating: [target isToolbarItemBusy: self]];
    }
}

@end
