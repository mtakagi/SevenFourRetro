/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

@interface WhiteFormatter : NSFormatter {
    int min_;
}

- (void)setMinValue:(int)min;
@end
