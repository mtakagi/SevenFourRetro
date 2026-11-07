/* This file is not copyrighted and may be used freely. */

#import "Ch2Helper.h"
#import <OgreKit/OgreKit.h>

@implementation Ch2Helper

+ (NSArray*) parseRangeString: (NSString*) str
				   lastNumber: (int) last
{
	NSMutableArray* result = [NSMutableArray array];
	
	OGRegularExpression* pattern;
	OGRegularExpressionMatch* match;
	
	// l10
	pattern = [OGRegularExpression regularExpressionWithString: @"^l(\\d+)$"];		
	match = [pattern matchInString: str];
	if (match) {
		int i;
		
        [result addObject: [NSNumber numberWithInt: 0]];
		for (i = [[match substringAtIndex: 1] intValue] - 1; i > 0; i--) {
			int n = last - i;
			if (n >= 0) {
				[result addObject: [NSNumber numberWithInt: n]];
			}
		}
		
		return result;
	}
	
	// 1-10
	pattern = [OGRegularExpression regularExpressionWithString:@"^(\\d+)-(\\d+)$"];	
	match = [pattern matchInString: str];
	if (match) {
		int i;
		int start = [[match substringAtIndex: 1] intValue];
		int end = [[match substringAtIndex: 2] intValue];
		
		for (i = start; i <= end; i++) {
			[result addObject: [NSNumber numberWithInt: i - 1]];
		}
		return result;
	}
	
	// 1,2,3,4
	NSArray* ary = [str componentsSeparatedByString: @","];
	if ([ary count] > 0) {
		int i;
		
		for (i = 0; i < [ary count]; i++) {
			NSString* s = [ary objectAtIndex: i];
			[result addObject: [NSNumber numberWithInt: [s intValue] - 1]];
		}
		
		return result;
	}
	
	if ([str intValue] != 0) {
		[result addObject: [NSNumber numberWithInt: [str intValue] - 1]];
		return result;
	}
	
	return nil;
}


@end
