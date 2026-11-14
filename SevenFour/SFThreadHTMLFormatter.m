/* This file is not copyrighted and may be used freely. */

#import "SFThreadHTMLFormatter.h"

#import <OgreKit/OgreKit.h>
#import "SFAppController.h"
#import "SFThread.h"
#import "Ch2Helper.h"
#import "Ch2Anchor.h"
#import "Ch2DatParser.h"
#import "SFThreadFactory.h"

static NSString* HEADER_TMPL = nil;
static NSString* TITLE_TMPL = nil;
static NSString* RES_TMPL = nil;
static NSString* NEW_RES_TMPL = nil;
static NSString* FOOTER_TMPL = nil;

static OGRegularExpression* HTML_ANCHOR_PATTERN = nil;
static OGRegularExpression* HTTP_PATTERN = nil;

@implementation SFThreadHTMLFormatter
+ (BOOL)isTextArt:(NSString*)s
{
    return [s rangeOfRegularExpressionString:@"\\x{3000} [^!-~]|[^!-~] \\x{3000}"].length != 0;
}

+ (NSString*)pathOfSkinFile:(NSString*)name
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString* path;

    // Only files in the skin folder.
    if ([[name pathComponents] containsObject:@".."]) {
        return nil;
    }

    // Home
    path = [[SF_SUPPORT_DIRECTORY stringByAppendingPathComponent:@"Skin"]
        stringByAppendingPathComponent:name];
    if (![manager isReadableFileAtPath:path]) {
        // Bundle
        path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Skin"]
            stringByAppendingPathComponent:name];
        if (![manager isReadableFileAtPath:path]) {
            NSLog(@"Skin file %@ is not found.", name);
            return nil;
        }
    }
    return path;
}

// A template of the skin (retained), or nil.
+ (NSString*)loadTemplate:(NSString*)name
{
    NSString* path = [self pathOfSkinFile:name];
    if (!path) {
        return nil;
    }
    return [[NSString alloc] initWithContentsOfFile:path usedEncoding:NULL error:NULL];
}

+ (void)reloadTemplates
{
    [HEADER_TMPL release];
    [TITLE_TMPL release];
    [RES_TMPL release];
    [NEW_RES_TMPL release];
    [FOOTER_TMPL release];

    // The encoding is guessed, so user skins in other encodings still load.
    HEADER_TMPL = [self loadTemplate:@"Header.html"];
    TITLE_TMPL = [self loadTemplate:@"Title.html"];
    NEW_RES_TMPL = [self loadTemplate:@"NewRes.html"];
    RES_TMPL = [self loadTemplate:@"Res.html"];

    FOOTER_TMPL = @"</body></html>";
}

- (NSString*)extractTemplateValue:(OGRegularExpressionMatch*)match
                      contextInfo:(id)info
{
    NSString* key = [match substringAtIndex:1];
    NSObject* value = [info valueForKey:key];
    if (value)
        return [value description];
    else
        return @"";
}

- (NSString*)extractTemplate:(NSString*)tmpl
                      object:(id)obj
{
    OGRegularExpression* pattern;
    pattern = [OGRegularExpression regularExpressionWithString:@"<([A-Z_]+) */>"];

    return [pattern replaceAllMatchesInString:tmpl
                                     delegate:self
                              replaceSelector:@selector(extractTemplateValue:contextInfo:)
                                  contextInfo:obj];
}

+ (NSString*)markupHTTPPattern:(OGRegularExpressionMatch*)match
                   contextInfo:(id)info
{
    NSString* href = [match substringAtIndex:1];
    NSString* label = [match substringAtIndex:0];

    return [NSString stringWithFormat:@"<a href='ht%@'>%@</a>", href, label];
}

+ (NSString*)formatBody:(NSString*)source
{
    NSString* tmp = source;

    if (!HTML_ANCHOR_PATTERN) {
        HTML_ANCHOR_PATTERN = [[OGRegularExpression regularExpressionWithString:@"</?[aA][^>]*>"] retain];
        HTTP_PATTERN = [[OGRegularExpression regularExpressionWithString:@"h?t?(tps?://[#-'+-;=?-z~*]+)"] retain];
    }

    // Delete <a ...> and </a>
    tmp = [HTML_ANCHOR_PATTERN replaceAllMatchesInString:tmp
                                              withString:@""];

    // Markup "http://..."
    tmp = [HTTP_PATTERN replaceAllMatchesInString:tmp
                                       withString:@"<a href='ht\\1'>\\0</a>"];

    // Markup ">>NUMBER", also "＞＞NUMBER" and full-width digits (#70)
    return Ch2MarkupAnchors(tmp);
}

- (NSString*)formatThread:(SFThread*)th
                  numbers:(NSArray*)numbers
{
    thread_ = th;

    NSMutableString* result = [NSMutableString string];
    NSString* html;

    html = [self extractTemplate:HEADER_TMPL object:th];
    [result appendString:html];

    int i;
    for (i = 0; i < [numbers count]; i++) {
        int n = [[numbers objectAtIndex:i] intValue];
        html = [self formatMessage:[thread_ messageAtIndex:n]
                            number:n + 1];
        [result appendString:html];
    }
    html = [self extractTemplate:FOOTER_TMPL object:th];
    [result appendString:html];

    return result;
}

- (NSString*)formatMessage:(NSDictionary*)message
                    number:(int)number
                  template:(NSString*)template
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    NSString* tmp;

    // Number
    [dict setObject:[NSNumber numberWithInt:number]
             forKey:@"PLAINNUMBER"];

    [dict setObject:[NSString stringWithFormat:@"<a class='number' href='sevenfour://internal/number#%d'>%d</a>", number, number]
             forKey:@"NUMBER"];

    // Mail, Name
    [dict setObject:[message objectForKey:Ch2MessageName] forKey:@"NAME"];
    NSString* mail = [message objectForKey:Ch2MessageMail];
    [dict setObject:mail forKey:@"MAIL"];
    if ([mail isEqualTo:@""]) {
        tmp = [NSString stringWithFormat:@"<a class='name' href='mailto:'><b>%@</b></a>", [message objectForKey:Ch2MessageName]];
    } else {
        tmp = [NSString stringWithFormat:@"<a class='name' href='mailto:%@' title='%@'><b>%@</b></a>", mail, mail, [message objectForKey:Ch2MessageName]];
    }
    [dict setObject:tmp forKey:@"MAILNAME"];

    // Time + ID -> Time
    NSString* messageId = [message objectForKey:Ch2MessageID];
    if (messageId) {
        [dict setObject:messageId forKey:@"PLAINID"];
        [dict setObject:[NSNumber numberWithInt:[thread_ countOfID:messageId]]
                 forKey:@"COUNTOFID"];

        if ([messageId isEqualTo:@"???"]) {
            tmp = [NSString stringWithFormat:@" <span class='id'>ID:%@</span>", messageId];
        } else {
            tmp = [NSString stringWithFormat:@" <span class='id'>ID:<a href='sevenfour://internal/popup#%@'>%@</a></span>", messageId, messageId];
        }
    } else {
        tmp = @"";
    }
    [dict setObject:[NSString stringWithFormat:@"<span class='date'>%@</span>%@", [message objectForKey:Ch2MessageTime], tmp]
             forKey:@"DATE"];

    // Body -> Body
    [dict setObject:[[self class] formatBody:[message objectForKey:@"body"]]
             forKey:@"MESSAGE"];


    // Extract Template
    NSMutableString* result = [NSMutableString string];
    if ([SFThreadHTMLFormatter isTextArt:[message objectForKey:@"body"]]) {
        [result appendFormat:@"<div id='%d' class='text-art'>", number];
    } else {
        [result appendFormat:@"<div id='%d'>", number];
    }
    [result appendString:[self extractTemplate:template
                                        object:dict]];
    [result appendString:@"</div>"];

    return result;
}

- (NSString*)formatMessage:(NSDictionary*)message
                    number:(int)number
{
    return [self formatMessage:message
                        number:number
                      template:RES_TMPL];
}

- (NSArray*)defaultRange
{
    NSMutableArray* result = [NSMutableArray array];
    int count;

    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"ThreadShowAll"]) {
        count = [thread_ count];
    } else {
        int min = (int) [defaults integerForKey:@"ThreadShowMin"];

        if ([thread_ count] > min) {
            if ([thread_ newCount] > min) {
                count = [thread_ newCount];
            } else {
                count = min;
            }
        } else {
            count = [thread_ count];
        }
    }

    int i;
    for (i = [thread_ count] - count; i < [thread_ count]; i++) {
        [result addObject:[NSNumber numberWithInt:i]];
    }

    // A thread with no messages (e.g. the download failed and there is no
    // cache) has nothing to show.
    if ([result count] > 0 && [[result objectAtIndex:0] intValue] != 0) {
        [result insertObject:[NSNumber numberWithInt:0]
                     atIndex:0];
    }

    return result;
}

- (NSString*)formatThreadBody
{
    DEBUG_LOG(@"SFThreadHTMLFormatter %p - formatThread", self);
    DEBUG_LOG(@"  range_ = %@", range_);
    DEBUG_LOG(@"  thread_ = %@", thread_);
    DEBUG_LOG(@"  [thread_ count] = %d", [thread_ count]);

    NSMutableString* html = [NSMutableString string];

    [html appendString:@"<dl>"];

    NSArray* numbers;
    if (range_) {
        if ([range_ isEqualTo:@"NEW"]) {
            numbers = [self defaultRange];
        } else {
            numbers = [Ch2Helper parseRangeString:range_
                                       lastNumber:[thread_ count]];
        }
    } else {
        NSMutableArray* ary = [NSMutableArray array];
        int i;
        for (i = 0; i < [thread_ count]; i++) {
            [ary addObject:[NSNumber numberWithInt:i]];
        }

        numbers = ary;
    }
    // DEBUG_LOG(@"  numbers = %@", numbers);

    int i;
    BOOL newInserted = NO;
    NSString* tmpl = RES_TMPL;
    for (i = 0; i < [numbers count]; i++) {
        int n = [[numbers objectAtIndex:i] intValue];

        if (n == [thread_ count] - [thread_ newCount]) {
            [html appendString:@"</dl><dl id='new'>"];
            newInserted = YES;
            tmpl = NEW_RES_TMPL;
        }

        if (0 <= n && n < [thread_ count]) {
            NSDictionary* message = [thread_ messageAtIndex:n];
            if (message) {
                NSString* s = [self formatMessage:message
                                           number:n + 1
                                         template:tmpl];
                [html appendString:s];
            }
        }
    }
    if (!newInserted) {
        [html appendString:@"</dl><dl id='new'>"];
    }
    [html appendString:@"</dl>"];
    [html appendString:[self extractTemplate:FOOTER_TMPL object:thread_]];

    return html;
}

- (NSString*)formatThread:(SFThread*)th
{
    thread_ = th;

    NSMutableString* result = [NSMutableString string];
    [result appendString:[self extractTemplate:HEADER_TMPL object:thread_]];
    [result appendString:[self extractTemplate:TITLE_TMPL object:thread_]];

    [result appendString:[self formatThreadBody]];

    return result;
}

- (void)setRange:(NSString*)range
{
    [range_ release];
    range_ = [range retain];
}

#pragma mark Override
- (id)init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    thread_ = nil;
    range_ = nil;

    return self;
}

- (void)dealloc
{
    [range_ release];

    [super dealloc];
}

@end


@implementation SFThread (SFThreadSkinKeys)
- (NSString*)SEVENFOUR_SUPPORT
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    NSMutableString* s = [NSMutableString string];
    [s appendString:@"<style type='text/css'>\n"];
    [s appendFormat:@"body { font-family:'%@'; font-size:%.1fpx; }\n",
        [defaults stringForKey:@"MessageFontFamily"],
        [defaults floatForKey:@"MessageFontSize"]];
    [s appendString:@"</style>\n"];
#if 1
    [s appendString:@"<script type='text/javascript'>\n"];
    [s appendString:@"sevenfour.countOfIDs = {};\n"];
    int i;
    NSArray* keys = [idCounts_ allKeys];
    for (i = 0; i < [keys count]; i++) {
        NSString* key = [keys objectAtIndex:i];
        [s appendFormat:@"sevenfour.countOfIDs['%@'] = %d;\n",
            key, [[idCounts_ objectForKey:key] intValue]];
    }
    [s appendString:@"</script>\n"];
#endif
    return s;
}
- (NSString*)THREADNAME
{
    return [self subject];
}
- (NSURL*)THREADURL
{
    return [self URLOfHTML];
}
- (int)GETRESCOUNT
{
    return [self count] - [self newCount];
}
- (int)NEWRESCOUNT
{
    return [self newCount];
}
- (int)ALLRESCOUNT
{
    return [self count];
}
@end
