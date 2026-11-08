/* This file is not copyrighted and may be used freely. */

#import "Ch2DatParser.h"
#import "TEC.h"

NSString* Ch2MessageNumber = @"no";
NSString* Ch2MessageName   = @"name";
NSString* Ch2MessageMail   = @"mail";
NSString* Ch2MessageBody   = @"body";
NSString* Ch2MessageTime   = @"time";
NSString* Ch2MessageID     = @"id";
NSString* Ch2MessageBe     = @"be";
NSString* Ch2MessageThreadSubject = @"subject";

@implementation Ch2DatParser

+ (void) parseTimeAndExtra: (NSString*) source
					result: (NSMutableDictionary*) result
{
	NSArray* ary1 = [source componentsSeparatedByString: @" ID:"];
	if ([ary1 count] == 2) {
		[result setObject: [ary1 objectAtIndex: 0]
				   forKey: Ch2MessageTime];		
	} else {
		[result setObject: source 
				   forKey: Ch2MessageTime];
		return;
	}
	
	NSArray* ary2 = [[ary1 objectAtIndex: 1] componentsSeparatedByString: @" BE:"];
	if ([ary2 count] == 2) {
		[result setObject: [ary2 objectAtIndex: 0]
				   forKey: Ch2MessageID];		
		[result setObject: [ary2 objectAtIndex: 1]
				   forKey: Ch2MessageBe];		
	} else {
		[result setObject: [ary1 objectAtIndex: 1]
				   forKey: Ch2MessageID];		
	}
}

+ (NSMutableDictionary*) parseLine: (NSString*) line
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    NSArray* ary = [line componentsSeparatedByString: @"<>"];
    
    if ([ary count] < 4) {
        return nil;
    }
    
    [result setObject: [ary objectAtIndex: 0] forKey: Ch2MessageName];
    [result setObject: [ary objectAtIndex: 1] forKey: Ch2MessageMail];
    
	[self parseTimeAndExtra: [ary objectAtIndex: 2]
					 result: result];
    
    [result setObject: [ary objectAtIndex: 3] forKey: Ch2MessageBody];

    
	// The fifth field holds the thread title on the first line. A line
	// without it is still a message.
	if ([ary count] > 4 && ! [[ary objectAtIndex: 4] isEqual: @""]) {
		[result setObject: [ary objectAtIndex: 4] forKey: Ch2MessageThreadSubject];
	}
    
    return result;
}

+ (NSArray*) parse: (NSString*) source
{
	NSMutableArray* result = [NSMutableArray array];
	
    NSRange range;
    unsigned length;
    int i, base = 0;
    
    range.location = 0;
    length = [source length];
	
    for (i = 0; length > 0; i++) {		
        range.length = 0;
        range = [source lineRangeForRange: range];
		
		// Delete "\n"
		range.length -= 1;
		
        NSString* line = [source substringWithRange: range];
		
        NSMutableDictionary* item;		
        item = [[self class] parseLine: line];
		
        if (item == nil) {
            return nil;
        }
        
        NSNumber* no = [NSNumber numberWithInt: i + base + 1];
        [item setObject: no forKey: @"no"];
        
        [result addObject: item];
        
		// "\n"
		range.length += 1;
		
        range.location += range.length;
        length -= range.length;        
    }
	
	return result;
}

+ (NSArray*) parseData: (NSData*) data
{
    TECConverter* converter;
    converter = [[TECConverter alloc] initWithEncoding: NSShiftJISStringEncoding];
    
    NSString* content;
    content = [converter convertToString: data];
    
    NSArray* result = [[self class] parse: content];
    [converter release];
	
	return result;
}

@end
