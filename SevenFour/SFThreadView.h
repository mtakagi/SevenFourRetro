/* This file is not copyrighted and may be used freely. */

#import <WebKit/WebKit.h>
#import "SFTabContent.h"

@class SFThread;

// A thread shown in a tab. Today a WebKit 1 WebView; what the rest of the
// app needs from it is kept in methods here (and SFTabContent for the tab
// bar), so it can become a WKWebView-based view (#27, #28; see
// docs/wkwebview-migration.md).
@interface SFThreadView : WebView <SFTabContent> {
    int visibleCount_;
	SFThread* thread_;
    float isFragmentLoading_;
}

- (SFThread*) thread;
- (void) loadThreadWithURL: (NSURL*) url;
- (void) updateThread;
// YES from -updateThread until the thread finishes updating.
- (BOOL) isUpdatingThread;

- (float) estimatedProgress;

// The URL of the page shown (an internal sevenfour:// URL), or nil.
- (NSURL*) pageURL;

// Finds string in the page and selects it, searching forward or backward
// from the selection, without wrapping around (case-insensitive). Returns
// NO when it is not found.
- (BOOL) findString: (NSString*) string forward: (BOOL) forward;

@end
