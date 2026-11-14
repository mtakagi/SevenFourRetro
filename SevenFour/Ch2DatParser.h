/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>

extern NSString* Ch2MessageNumber;
extern NSString* Ch2MessageName;
extern NSString* Ch2MessageMail;
extern NSString* Ch2MessageTime;
extern NSString* Ch2MessageBody;
extern NSString* Ch2MessageID;
extern NSString* Ch2MessageBe;
extern NSString* Ch2MessageThreadSubject;

@interface Ch2DatParser : NSObject {
}

+ (NSArray*)parseData:(NSData*)data;
@end
