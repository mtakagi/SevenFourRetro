/*
 * OgreKit compatibility shim.
 *
 * SevenFour originally linked against OgreKit.framework (an Oniguruma based
 * regular expression framework) which is not available for modern macOS.
 * This header re-implements the small subset of the OgreKit API used by
 * SevenFour on top of NSRegularExpression (ICU).
 *
 * Behavioural notes (matching OgreKit's default Ruby syntax):
 *   - "^" and "$" match at line boundaries.
 *   - "." does not match newlines.
 *   - Replacement strings use "\0" .. "\9" for capture groups.
 */

#import <Foundation/Foundation.h>

enum {
    OgreNoneOption = 0,
    OgreIgnoreCaseOption = 1 << 0,
};
typedef unsigned int OgreOption;

@class OGRegularExpressionMatch;

@interface OGRegularExpression : NSObject {
    NSRegularExpression* regex_;
}

+ (id)regularExpressionWithString:(NSString*)expressionString;
+ (id)regularExpressionWithString:(NSString*)expressionString
                          options:(unsigned)options;
- (id)initWithString:(NSString*)expressionString
             options:(unsigned)options;

- (OGRegularExpressionMatch*)matchInString:(NSString*)string;
- (NSEnumerator*)matchEnumeratorInString:(NSString*)string;

- (NSString*)replaceAllMatchesInString:(NSString*)string
                            withString:(NSString*)replaceString;
- (NSString*)replaceAllMatchesInString:(NSString*)string
                              delegate:(id)aDelegate
                       replaceSelector:(SEL)aSelector
                           contextInfo:(id)contextInfo;
@end

@interface OGRegularExpressionMatch : NSObject {
    NSTextCheckingResult* result_;
    NSString* target_;
}

- (id)initWithResult:(NSTextCheckingResult*)result
            inString:(NSString*)target;

- (unsigned)count;
- (NSRange)rangeOfMatchedString;
- (NSRange)rangeOfSubstringAtIndex:(unsigned)index;
- (NSString*)matchedString;
- (NSString*)substringAtIndex:(unsigned)index;
@end

@interface NSString (OgreKitAdditions)
- (NSRange)rangeOfRegularExpressionString:(NSString*)expressionString;
- (NSRange)rangeOfRegularExpressionString:(NSString*)expressionString
                                  options:(unsigned)options;
@end

@interface NSMutableString (OgreKitAdditions)
- (unsigned)replaceOccurrencesOfRegularExpressionString:(NSString*)expressionString
                                             withString:(NSString*)replaceString
                                                options:(unsigned)options
                                                  range:(NSRange)searchRange;
@end
