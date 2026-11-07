/* OgreKit compatibility shim. See OgreKit.h. */

#import "OgreKit.h"
#import <objc/message.h>

static NSRegularExpressionOptions OGTranslateOptions(unsigned options)
{
    NSRegularExpressionOptions result = NSRegularExpressionAnchorsMatchLines;
    if (options & OgreIgnoreCaseOption) {
        result |= NSRegularExpressionCaseInsensitive;
    }
    return result;
}

/* Expand an OgreKit style replacement template ("\0" .. "\9", "\\"). */
static NSString* OGExpandTemplate(NSString* tmpl, OGRegularExpressionMatch* match)
{
    NSMutableString* result = [NSMutableString string];
    NSUInteger i, length = [tmpl length];

    for (i = 0; i < length; i++) {
        unichar c = [tmpl characterAtIndex: i];
        if (c == '\\' && i + 1 < length) {
            unichar next = [tmpl characterAtIndex: i + 1];
            if (next >= '0' && next <= '9') {
                NSString* s = [match substringAtIndex: next - '0'];
                if (s) {
                    [result appendString: s];
                }
                i++;
                continue;
            } else if (next == '\\') {
                [result appendString: @"\\"];
                i++;
                continue;
            }
        }
        [result appendFormat: @"%C", c];
    }
    return result;
}

@implementation OGRegularExpression

+ (id) regularExpressionWithString: (NSString*) expressionString
{
    return [self regularExpressionWithString: expressionString options: OgreNoneOption];
}

+ (id) regularExpressionWithString: (NSString*) expressionString
                           options: (unsigned) options
{
    return [[[self alloc] initWithString: expressionString options: options] autorelease];
}

- (id) initWithString: (NSString*) expressionString
              options: (unsigned) options
{
    self = [super init];
    if (self) {
        NSError* error = nil;
        regex_ = [[NSRegularExpression alloc] initWithPattern: expressionString
                                                      options: OGTranslateOptions(options)
                                                        error: &error];
        if (! regex_) {
            NSLog(@"OGRegularExpression: invalid pattern %@: %@", expressionString, error);
            [self release];
            return nil;
        }
    }
    return self;
}

- (void) dealloc
{
    [regex_ release];
    [super dealloc];
}

- (OGRegularExpressionMatch*) matchInString: (NSString*) string
{
    if (! string) {
        return nil;
    }
    NSTextCheckingResult* r = [regex_ firstMatchInString: string
                                                 options: 0
                                                   range: NSMakeRange(0, [string length])];
    if (! r) {
        return nil;
    }
    return [[[OGRegularExpressionMatch alloc] initWithResult: r inString: string] autorelease];
}

- (NSArray*) matchesInString: (NSString*) string
{
    NSMutableArray* result = [NSMutableArray array];
    if (! string) {
        return result;
    }
    NSArray* matches = [regex_ matchesInString: string
                                       options: 0
                                         range: NSMakeRange(0, [string length])];
    for (NSTextCheckingResult* r in matches) {
        OGRegularExpressionMatch* m = [[OGRegularExpressionMatch alloc] initWithResult: r inString: string];
        [result addObject: m];
        [m release];
    }
    return result;
}

- (NSEnumerator*) matchEnumeratorInString: (NSString*) string
{
    return [[self matchesInString: string] objectEnumerator];
}

- (NSString*) replaceAllMatchesInString: (NSString*) string
                         replacementFor: (NSString* (^)(OGRegularExpressionMatch*)) block
{
    if (! string) {
        return nil;
    }
    NSMutableString* result = [NSMutableString string];
    NSUInteger last = 0;
    for (OGRegularExpressionMatch* m in [self matchesInString: string]) {
        NSRange r = [m rangeOfMatchedString];
        [result appendString: [string substringWithRange: NSMakeRange(last, r.location - last)]];
        NSString* replacement = block(m);
        if (replacement) {
            [result appendString: replacement];
        }
        last = NSMaxRange(r);
    }
    [result appendString: [string substringFromIndex: last]];
    return result;
}

- (NSString*) replaceAllMatchesInString: (NSString*) string
                             withString: (NSString*) replaceString
{
    return [self replaceAllMatchesInString: string
                            replacementFor: ^NSString* (OGRegularExpressionMatch* m) {
        return OGExpandTemplate(replaceString, m);
    }];
}

- (NSString*) replaceAllMatchesInString: (NSString*) string
                               delegate: (id) aDelegate
                        replaceSelector: (SEL) aSelector
                            contextInfo: (id) contextInfo
{
    return [self replaceAllMatchesInString: string
                            replacementFor: ^NSString* (OGRegularExpressionMatch* m) {
        return ((id (*)(id, SEL, id, id)) objc_msgSend)(aDelegate, aSelector, m, contextInfo);
    }];
}

@end

@implementation OGRegularExpressionMatch

- (id) initWithResult: (NSTextCheckingResult*) result
             inString: (NSString*) target
{
    self = [super init];
    if (self) {
        result_ = [result retain];
        target_ = [target copy];
    }
    return self;
}

- (void) dealloc
{
    [result_ release];
    [target_ release];
    [super dealloc];
}

- (unsigned) count
{
    return (unsigned) [result_ numberOfRanges];
}

- (NSRange) rangeOfMatchedString
{
    return [result_ range];
}

- (NSRange) rangeOfSubstringAtIndex: (unsigned) index
{
    if (index >= [result_ numberOfRanges]) {
        return NSMakeRange(NSNotFound, 0);
    }
    return [result_ rangeAtIndex: index];
}

- (NSString*) matchedString
{
    return [self substringAtIndex: 0];
}

- (NSString*) substringAtIndex: (unsigned) index
{
    NSRange r = [self rangeOfSubstringAtIndex: index];
    if (r.location == NSNotFound) {
        return nil;
    }
    return [target_ substringWithRange: r];
}

@end

@implementation NSString (OgreKitAdditions)

- (NSRange) rangeOfRegularExpressionString: (NSString*) expressionString
{
    return [self rangeOfRegularExpressionString: expressionString options: OgreNoneOption];
}

- (NSRange) rangeOfRegularExpressionString: (NSString*) expressionString
                                   options: (unsigned) options
{
    OGRegularExpressionMatch* m = [[OGRegularExpression regularExpressionWithString: expressionString
                                                                            options: options]
                                   matchInString: self];
    if (! m) {
        return NSMakeRange(NSNotFound, 0);
    }
    return [m rangeOfMatchedString];
}

@end

@implementation NSMutableString (OgreKitAdditions)

- (unsigned) replaceOccurrencesOfRegularExpressionString: (NSString*) expressionString
                                              withString: (NSString*) replaceString
                                                 options: (unsigned) options
                                                   range: (NSRange) searchRange
{
    OGRegularExpression* regex = [OGRegularExpression regularExpressionWithString: expressionString
                                                                          options: options];
    NSString* target = [self substringWithRange: searchRange];
    NSArray* matches = [regex matchesInString: target];
    if ([matches count] == 0) {
        return 0;
    }
    NSString* replaced = [regex replaceAllMatchesInString: target withString: replaceString];
    [self replaceCharactersInRange: searchRange withString: replaced];
    return (unsigned) [matches count];
}

@end
