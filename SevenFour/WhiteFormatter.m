/* This file is not copyrighted and may be used freely. */

#import "WhiteFormatter.h"

@implementation WhiteFormatter

- (void) setMinValue: (int) min
{
    min_ = min;
}

#pragma mark Override
- (NSString*) stringForObjectValue: (id) obj
{
    if ([obj intValue] <= min_) {
        return @"";
    }
    
    return [NSString stringWithFormat: @"%d", [obj intValue]];
}

@end
