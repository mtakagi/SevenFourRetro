/* This file is not copyrighted and may be used freely. */

#import "SFPageView.h"
#import "SFTabContent.h"

@class SFThread;
@class SFThreadView;

// What SFThreadView asks of its owner (the page delegate,
// SFMainWindowController), besides SFPageViewDelegate.
@interface NSObject (SFThreadViewDelegate)
// A page started or finished loading.
- (void)threadViewDidStartLoading:(SFThreadView*)view;
- (void)threadViewDidFinishLoading:(SFThreadView*)view;
@end

// A thread shown in a tab (#28). Pages come from SFThreadSchemeHandler
// (sevenfour://); links and hovering are handled by SFPageView. See
// docs/wkwebview-migration.md.
@interface SFThreadView : SFPageView <SFTabContent> {
    int visibleCount_; // messages shown in the page
    int pageCount_;    // messages in the page being loaded, or -1
    BOOL isPageLoaded_;
    SFThread* thread_;
    BOOL isFragmentLoading_;
}

- (SFThread*)thread;
- (void)loadThreadWithURL:(NSURL*)url;
- (void)updateThread;
// YES from -updateThread until the thread finishes updating.
- (BOOL)isUpdatingThread;

// Told by SFThreadSchemeHandler: the page being loaded shows the first
// count messages of the thread.
- (void)setPageCount:(int)count;

// The URL of the page shown (an internal sevenfour:// URL), or nil.
- (NSURL*)pageURL;

@end
