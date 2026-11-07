/* This file is not copyrighted and may be used freely. */

#import <WebKit/WebKit.h>

@class SFThread;

@interface SFThreadView : WebView {
    int visibleCount_;
	SFThread* thread_;
    float isFragmentLoading_;
}

- (SFThread*) thread;
- (void) loadThreadWithURL: (NSURL*) url;
- (void) updateThread;

- (float) estimatedProgress;

@end
