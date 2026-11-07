/* This file is not copyrighted and may be used freely. */

#import <Cocoa/Cocoa.h>
#import "SFThread.h"

@class SFThreadHTMLFormatter;

@interface SFURLProtocol : NSURLProtocol {
    SFThread* thread_;
    SFThreadHTMLFormatter* formatter_;
}

@end
